internal import CVulkan
import Foundation

@discardableResult
private func vkCheck(_ result: VkResult, _ label: String) -> Bool {
    guard result == VK_SUCCESS else {
        print("[MoltenMTL] \(label) failed (VkResult \(result.rawValue))")
        return false
    }
    return true
}

private func instanceLayerAvailable(_ name: String) -> Bool {
    var count: UInt32 = 0
    vkEnumerateInstanceLayerProperties(&count, nil)
    guard count > 0 else { return false }
    var props = [VkLayerProperties](repeating: VkLayerProperties(), count: Int(count))
    vkEnumerateInstanceLayerProperties(&count, &props)
    return props.contains { prop in
        withUnsafeBytes(of: prop.layerName) { bytes in
            String(cString: bytes.bindMemory(to: CChar.self).baseAddress!) == name
        }
    }
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

    /// Device-wide shared resources, created on first use.
    internal var _defaultSampler: MTLSamplerState?
    internal var _dummyTextures:  [MTLTextureUsage: MTLTexture] = [:]

    init() {}

    deinit {
        // Shared resources first destroyed first, so they don't
        // try to use the device after it's gone.
        _defaultSampler = nil
        _dummyTextures.removeAll()
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

    // Validation is opt-in: the layer ships with the Vulkan SDK, not the runtime,
    // so enabling it unconditionally would fail instance creation on end-user machines.
    let validationLayer = "VK_LAYER_KHRONOS_validation"
    let validationRequested = ["1", "true"].contains(
        ProcessInfo.processInfo.environment["MOLTENMTL_VALIDATION"]?.lowercased() ?? "")
    let enableValidation = validationRequested && instanceLayerAvailable(validationLayer)
    if validationRequested && !enableValidation {
        print("[MoltenMTL] MOLTENMTL_VALIDATION set but \(validationLayer) is not installed — continuing without validation")
    }

    var instanceResult: VkResult = VK_SUCCESS

    validationLayer.withCString { layerCStr in
        let layers: [UnsafePointer<CChar>?] = enableValidation ? [layerCStr] : []
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
                    instanceCI.enabledLayerCount        = UInt32(layers.count)
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
        print("[MoltenMTL] No Vulkan-capable GPU found")
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
    print("[MoltenMTL] GPU: \(gpuName)")

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
        print("[MoltenMTL] No compute queue family found")
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
              // Dynamic rendering (Vulkan 1.3 core) — required by the render-pipeline
              // path, which uses vkCmdBeginRendering instead of VkRenderPass objects.
              var drFeatures = VkPhysicalDeviceDynamicRenderingFeatures()
              drFeatures.sType           = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES
              drFeatures.pNext           = UnsafeMutableRawPointer(rqPtr)
              drFeatures.dynamicRendering = 1
              withUnsafeMutablePointer(to: &drFeatures) { drPtr in
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

                        // Descriptor indexing
                        var diProbe = VkPhysicalDeviceDescriptorIndexingFeatures()
                        diProbe.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES
                        withUnsafeMutablePointer(to: &diProbe) { diProbePtr in
                            var probed = VkPhysicalDeviceFeatures2()
                            probed.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2
                            probed.pNext = UnsafeMutableRawPointer(diProbePtr)
                            vkGetPhysicalDeviceFeatures2(dev.physicalDevice, &probed)
                        }
                        let hasNonUniformIndexing =
                            diProbe.shaderSampledImageArrayNonUniformIndexing != 0
                        if !hasNonUniformIndexing {
                            print("[MoltenMTL] GPU does not support shaderSampledImageArrayNonUniformIndexing — shaders using nonuniformEXT on a texture array will not work")
                        }

                        // Built fresh rather than reusing the probe: that one comes
                        // back with every feature the device supports.
                        var diFeatures = VkPhysicalDeviceDescriptorIndexingFeatures()
                        diFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES
                        diFeatures.pNext = UnsafeMutableRawPointer(drPtr)
                        diFeatures.shaderSampledImageArrayNonUniformIndexing = 1

                        // shaderInt64 enabled
                        var coreProbe = VkPhysicalDeviceFeatures()
                        vkGetPhysicalDeviceFeatures(dev.physicalDevice, &coreProbe)
                        let hasShaderInt64 = coreProbe.shaderInt64 != 0
                        if !hasShaderInt64 {
                            print("[MoltenMTL] GPU does not support shaderInt64 — shaders using 64-bit buffer references will not work")
                        }

                        var coreFeatures = VkPhysicalDeviceFeatures()
                        coreFeatures.shaderInt64 = hasShaderInt64 ? 1 : 0

                        withUnsafeMutablePointer(to: &diFeatures) { diPtr in
                        withUnsafePointer(to: &coreFeatures) { corePtr in
                        exts.withUnsafeMutableBufferPointer { extsBuf in
                            var deviceCI = VkDeviceCreateInfo()
                            deviceCI.sType                   = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
                            deviceCI.pNext                   = hasNonUniformIndexing
                                                             ? UnsafeRawPointer(diPtr)
                                                             : UnsafeRawPointer(drPtr)
                            deviceCI.queueCreateInfoCount    = 1
                            deviceCI.pQueueCreateInfos       = queueCIPtr
                            deviceCI.enabledExtensionCount   = devExtCount
                            deviceCI.ppEnabledExtensionNames = UnsafePointer(extsBuf.baseAddress)
                            deviceCI.pEnabledFeatures        = corePtr
                            deviceResult = vkCreateDevice(
                                dev.physicalDevice, &deviceCI, nil, &dev.device)
                        }
                        }
                        }
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
    print("[MoltenMTL] Device ready (compute queue family: \(dev.computeQueueFamily))")
    return dev
}
