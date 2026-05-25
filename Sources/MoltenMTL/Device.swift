import CVulkan

// MARK: - VkResult check

@discardableResult
private func vkCheck(_ result: VkResult, _ label: String) -> Bool {
    guard result == VK_SUCCESS else {
        print("[VulkanSwift] \(label) failed (VkResult \(result.rawValue))")
        return false
    }
    return true
}

// MARK: - Device

/// Mirrors MTLDevice — owns the Vulkan instance, physical device, and logical device.
/// Create via `Device.createSystemDefaultDevice()`.
public final class MTLDevice {

    // MARK: Public handles
    fileprivate nonisolated(unsafe) static var shared: MTLDevice?

    public fileprivate(set) var instance:           VkInstance?
    public fileprivate(set) var physicalDevice:     VkPhysicalDevice?
    public fileprivate(set) var device:             VkDevice?
    public fileprivate(set) var queue:              VkQueue?
    public fileprivate(set) var allocator:          VmaAllocator?
    public fileprivate(set) var computeQueueFamily: UInt32 = .max 

    // MARK: Init / deinit

    init() {}

    deinit {
        // Destroy in reverse-creation order: allocator → device → instance
        if let a = allocator { CVMA_destroyAllocator(a) }
        if let d = device    { vkDestroyDevice(d, nil) }
        if let i = instance  { vkDestroyInstance(i, nil) }
    }
}

// MARK: - createSystemDefaultDevice

/// Mirrors `MTLCreateSystemDefaultDevice()`.
///
/// Selects the first available Vulkan-capable GPU and creates:
///   - a `VkInstance` (with Khronos validation layer)
///   - a `VkPhysicalDevice` (first enumerated GPU)
///   - a `VkDevice` with ray-tracing extensions enabled
///     (VK_KHR_deferred_host_operations, VK_KHR_acceleration_structure,
///      VK_KHR_ray_query) and the matching feature structs in the pNext chain
///   - a compute `VkQueue`
///
/// Returns `nil` if any step fails.
public func MTLCreateSystemDefaultDevice() -> MTLDevice? {
    if let sharedDevice = MTLDevice.shared {
        return sharedDevice
    }

    let dev = MTLDevice()

    // ── Disable overlay layers that mis-use the swapchain API ─────────────
    CVKS_disableOverlayLayers()

    // ── Instance ───────────────────────────────────────────────────────────
    var appInfo = VkApplicationInfo()
    appInfo.sType      = VK_STRUCTURE_TYPE_APPLICATION_INFO
    appInfo.apiVersion = SWIFT_VK_API_VERSION_1_4

    let validationLayer = "VK_LAYER_KHRONOS_validation"
    var instanceResult: VkResult = VK_SUCCESS

    validationLayer.withCString { layerCStr in
        let layers: [UnsafePointer<CChar>?] = [layerCStr]
        // Instance extensions: surface support required for SDL3 windowing.
        var instanceExts: [UnsafePointer<CChar>?] = [
            SWIFT_EXT_KHR_SURFACE,
            SWIFT_EXT_WIN32_SURFACE
        ]
        let instanceExtCount = UInt32(instanceExts.count)
        layers.withUnsafeBufferPointer { layersBuf in
            instanceExts.withUnsafeMutableBufferPointer { extsBuf in
                withUnsafePointer(to: appInfo) { appPtr in
                    var instanceCI = VkInstanceCreateInfo()
                    instanceCI.sType                    = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
                    instanceCI.pApplicationInfo         = appPtr
                    instanceCI.enabledLayerCount        = 1
                    instanceCI.ppEnabledLayerNames      = layersBuf.baseAddress
                    instanceCI.enabledExtensionCount    = instanceExtCount
                    instanceCI.ppEnabledExtensionNames  = UnsafePointer(extsBuf.baseAddress)
                    instanceResult = vkCreateInstance(&instanceCI, nil, &dev.instance)
                }
            }
        }
    }
    guard vkCheck(instanceResult, "vkCreateInstance") else { return nil }

    // ── Physical device ────────────────────────────────────────────────────
    var devCount: UInt32 = 0
    vkEnumeratePhysicalDevices(dev.instance, &devCount, nil)
    guard devCount > 0 else {
        print("[VulkanSwift] No Vulkan-capable GPU found")
        return nil
    }
    var physDevs = [VkPhysicalDevice?](repeating: nil, count: Int(devCount))
    vkEnumeratePhysicalDevices(dev.instance, &devCount, &physDevs)
    dev.physicalDevice = physDevs[0]

    // Print the GPU name — deviceName is a fixed C char array, convert via bytes.
    var devProps = VkPhysicalDeviceProperties()
    vkGetPhysicalDeviceProperties(dev.physicalDevice, &devProps)
    let gpuName = withUnsafeBytes(of: devProps.deviceName) { bytes in
        String(cString: bytes.bindMemory(to: CChar.self).baseAddress!)
    }
    print("[VulkanSwift] GPU: \(gpuName)")

    // ── Compute queue family ───────────────────────────────────────────────
    var qfCount: UInt32 = 0
    vkGetPhysicalDeviceQueueFamilyProperties(dev.physicalDevice, &qfCount, nil)
    var qfProps = [VkQueueFamilyProperties](
        repeating: VkQueueFamilyProperties(), count: Int(qfCount))
    vkGetPhysicalDeviceQueueFamilyProperties(dev.physicalDevice, &qfCount, &qfProps)

    // Prefer a queue family with both GRAPHICS + COMPUTE — that family is
    // guaranteed to support presentation on the primary display on all
    // consumer GPUs.  Fall back to any COMPUTE-only family if none found.
    let graphicsBit = UInt32(bitPattern: VK_QUEUE_GRAPHICS_BIT.rawValue)
    let computeBit  = UInt32(bitPattern: VK_QUEUE_COMPUTE_BIT.rawValue)
    let bothBits    = graphicsBit | computeBit
    for i in 0..<Int(qfCount) where (qfProps[i].queueFlags & bothBits) == bothBits {
        dev.computeQueueFamily = UInt32(i)
        break
    }
    if dev.computeQueueFamily == .max {
        for i in 0..<Int(qfCount) where (qfProps[i].queueFlags & computeBit) != 0 {
            dev.computeQueueFamily = UInt32(i)
            break
        }
    }
    guard dev.computeQueueFamily != .max else {
        print("[VulkanSwift] No compute queue family found")
        return nil
    }

    // ── Logical device + RT feature chain ─────────────────────────────────
    //
    // pNext chain (innermost → outermost):
    //   VkPhysicalDeviceBufferDeviceAddressFeatures
    //     ← VkPhysicalDeviceAccelerationStructureFeaturesKHR
    //         ← VkPhysicalDeviceRayQueryFeaturesKHR
    //               ← VkDeviceCreateInfo.pNext
    //
    // Each struct must stay alive until vkCreateDevice returns, so we use
    // withUnsafeMutablePointer nesting to pin their addresses on the stack.

    var bdaFeatures = VkPhysicalDeviceBufferDeviceAddressFeatures()
    bdaFeatures.sType               = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES
    bdaFeatures.bufferDeviceAddress = 1 // VK_TRUE (VkBool32 = UInt32)

    var deviceResult: VkResult = VK_SUCCESS

    withUnsafeMutablePointer(to: &bdaFeatures) { bdaPtr in
        var asFeatures = VkPhysicalDeviceAccelerationStructureFeaturesKHR()
        asFeatures.sType                 = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR
        asFeatures.pNext                 = UnsafeMutableRawPointer(bdaPtr)
        asFeatures.accelerationStructure = 1 // VK_TRUE

        withUnsafeMutablePointer(to: &asFeatures) { asPtr in
            var rqFeatures = VkPhysicalDeviceRayQueryFeaturesKHR()
            rqFeatures.sType    = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR
            rqFeatures.pNext    = UnsafeMutableRawPointer(asPtr)
            rqFeatures.rayQuery = 1 // VK_TRUE

            withUnsafeMutablePointer(to: &rqFeatures) { rqPtr in
                var prio: Float = 1.0
                withUnsafePointer(to: &prio) { prioPtr in
                    var queueCI = VkDeviceQueueCreateInfo()
                    queueCI.sType            = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
                    queueCI.queueFamilyIndex = dev.computeQueueFamily
                    queueCI.queueCount       = 1
                    queueCI.pQueuePriorities = prioPtr

                    withUnsafePointer(to: queueCI) { queueCIPtr in
                        // Extension names — SWIFT_EXT_* are const char* constants
                        // defined in CVulkan.h, so Swift sees them as UnsafePointer<CChar>?.
                        var exts: [UnsafePointer<CChar>?] = [
                            SWIFT_EXT_DEFERRED_HOST_OPS,
                            SWIFT_EXT_ACCEL_STRUCTURE,
                            SWIFT_EXT_RAY_QUERY,
                            SWIFT_EXT_KHR_SWAPCHAIN    // VK_KHR_swapchain
                        ]
                        let devExtCount = UInt32(exts.count)
                        exts.withUnsafeMutableBufferPointer { extsBuf in
                            var deviceCI = VkDeviceCreateInfo()
                            deviceCI.sType                   = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
                            deviceCI.pNext                   = UnsafeRawPointer(rqPtr)
                            deviceCI.queueCreateInfoCount    = 1
                            deviceCI.pQueueCreateInfos       = queueCIPtr
                            deviceCI.enabledExtensionCount   = devExtCount
                            deviceCI.ppEnabledExtensionNames = UnsafePointer(extsBuf.baseAddress)
                            deviceResult = vkCreateDevice(
                                dev.physicalDevice, &deviceCI, nil, &dev.device)
                        }
                    }
                }
            }
        }
    }

    guard vkCheck(deviceResult, "vkCreateDevice") else { return nil }

    // Load extension function pointers.
    CVKAS_init(dev.device)   // ray-tracing extensions

    vkGetDeviceQueue(dev.device, dev.computeQueueFamily, 0, &dev.queue)

    // ── VMA allocator ──────────────────────────────────────────────────────
    let allocResult = CVMA_createAllocator(dev.instance, dev.physicalDevice,
                                            dev.device, SWIFT_VK_API_VERSION_1_4,
                                            &dev.allocator)
    guard vkCheck(allocResult, "CVMA_createAllocator") else { return nil }

    MTLDevice.shared = dev
    print("[VulkanSwift] Device ready (compute queue family: \(dev.computeQueueFamily))")
    return dev
}
