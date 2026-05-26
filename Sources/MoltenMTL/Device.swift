import CVulkan

@discardableResult
private func vkCheck(_ result: VkResult, _ label: String) -> Bool {
    guard result == VK_SUCCESS else {
        print("[VulkanSwift] \(label) failed (VkResult \(result.rawValue))")
        return false
    }
    return true
}

/// Wraps the Vulkan instance, physical device, and logical device.
/// Create via `MTLCreateSystemDefaultDevice()`.
public final class MTLDevice {

    fileprivate nonisolated(unsafe) static var shared: MTLDevice?

    fileprivate(set) var _instance:                 VkInstance?
    public var instance: OpaquePointer?             { _instance }
    fileprivate(set) var physicalDevice:             VkPhysicalDevice?
    fileprivate(set) var device:                     VkDevice?
    fileprivate(set) var queue:                      VkQueue?
    fileprivate(set) var allocator:                  VmaAllocator?
    public fileprivate(set) var computeQueueFamily:  UInt32 = .max

    init() {}

    deinit {
        // Destroy in reverse-creation order: allocator → device → instance
        if let a = allocator  { CVMA_destroyAllocator(a) }
        if let d = device     { vkDestroyDevice(d, nil) }
        if let i = _instance  { vkDestroyInstance(i, nil) }
    }
}

/// Selects the first available Vulkan-capable GPU and initialises a device with
/// ray-tracing extensions (deferred host ops, acceleration structure, ray query).
/// Returns `nil` if any step fails.
public func MTLCreateSystemDefaultDevice() -> MTLDevice? {
    if let sharedDevice = MTLDevice.shared {
        return sharedDevice
    }

    let dev = MTLDevice()

    // Disable overlay layers that mis-use the swapchain API
    CVKS_disableOverlayLayers()

    // Instance
    var appInfo = VkApplicationInfo()
    appInfo.sType      = VK_STRUCTURE_TYPE_APPLICATION_INFO
    appInfo.apiVersion = SWIFT_VK_API_VERSION_1_4

    let validationLayer = "VK_LAYER_KHRONOS_validation"
    var instanceResult: VkResult = VK_SUCCESS

    validationLayer.withCString { layerCStr in
        let layers: [UnsafePointer<CChar>?] = [layerCStr]
        // Surface extensions required for SDL3 windowing.
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
                    instanceResult = vkCreateInstance(&instanceCI, nil, &dev._instance)
                }
            }
        }
    }
    guard vkCheck(instanceResult, "vkCreateInstance") else { return nil }

    // Physical device
    var devCount: UInt32 = 0
    vkEnumeratePhysicalDevices(dev._instance, &devCount, nil)
    guard devCount > 0 else {
        print("[VulkanSwift] No Vulkan-capable GPU found")
        return nil
    }
    var physDevs = [VkPhysicalDevice?](repeating: nil, count: Int(devCount))
    vkEnumeratePhysicalDevices(dev._instance, &devCount, &physDevs)
    dev.physicalDevice = physDevs[0]

    var devProps = VkPhysicalDeviceProperties()
    vkGetPhysicalDeviceProperties(dev.physicalDevice, &devProps)
    let gpuName = withUnsafeBytes(of: devProps.deviceName) { bytes in
        String(cString: bytes.bindMemory(to: CChar.self).baseAddress!)
    }
    print("[VulkanSwift] GPU: \(gpuName)")

    // Compute queue family
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

    // Logical device + RT feature chain
    // Each struct must stay alive until vkCreateDevice returns, so we use
    // withUnsafeMutablePointer nesting to pin their addresses on the stack.

    var bdaFeatures = VkPhysicalDeviceBufferDeviceAddressFeatures()
    bdaFeatures.sType               = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES
    bdaFeatures.bufferDeviceAddress = 1

    var deviceResult: VkResult = VK_SUCCESS

    withUnsafeMutablePointer(to: &bdaFeatures) { bdaPtr in
        var asFeatures = VkPhysicalDeviceAccelerationStructureFeaturesKHR()
        asFeatures.sType                 = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR
        asFeatures.pNext                 = UnsafeMutableRawPointer(bdaPtr)
        asFeatures.accelerationStructure = 1

        withUnsafeMutablePointer(to: &asFeatures) { asPtr in
            var rqFeatures = VkPhysicalDeviceRayQueryFeaturesKHR()
            rqFeatures.sType    = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR
            rqFeatures.pNext    = UnsafeMutableRawPointer(asPtr)
            rqFeatures.rayQuery = 1

            withUnsafeMutablePointer(to: &rqFeatures) { rqPtr in
                var prio: Float = 1.0
                withUnsafePointer(to: &prio) { prioPtr in
                    var queueCI = VkDeviceQueueCreateInfo()
                    queueCI.sType            = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
                    queueCI.queueFamilyIndex = dev.computeQueueFamily
                    queueCI.queueCount       = 1
                    queueCI.pQueuePriorities = prioPtr

                    withUnsafePointer(to: queueCI) { queueCIPtr in
                        var exts: [UnsafePointer<CChar>?] = [
                            SWIFT_EXT_DEFERRED_HOST_OPS,
                            SWIFT_EXT_ACCEL_STRUCTURE,
                            SWIFT_EXT_RAY_QUERY,
                            SWIFT_EXT_KHR_SWAPCHAIN
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

    CVKAS_init(dev.device)

    vkGetDeviceQueue(dev.device, dev.computeQueueFamily, 0, &dev.queue)

    // VMA allocator
    let allocResult = CVMA_createAllocator(dev._instance, dev.physicalDevice,
                                            dev.device, SWIFT_VK_API_VERSION_1_4,
                                            &dev.allocator)
    guard vkCheck(allocResult, "CVMA_createAllocator") else { return nil }

    MTLDevice.shared = dev
    print("[VulkanSwift] Device ready (compute queue family: \(dev.computeQueueFamily))")
    return dev
}
