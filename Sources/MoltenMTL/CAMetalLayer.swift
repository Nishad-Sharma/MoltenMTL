/// The Vulkan-backed renderable surface. Owns the `VkSwapchainKHR` and its sync primitives.
/// The `VkSurfaceKHR` is **not** owned here - the caller creates and destroys it.
import CVulkan

public final class CAMetalLayer {

    public var device: MTLDevice
    /// `true` when the swapchain format is BGRA - caller must swap R/B in the staging buffer.
    public let isBGRA: Bool

    private let vkDev: VkDevice
    private let swapchain: VkSwapchainKHR
    private let images: [VkImage]
    /// Signalled by `vkAcquireNextImageKHR`; consumed by the submit before the next acquire.
    private let imageSem: VkSemaphore
    /// One per swapchain image - prevents reuse while a previous frame's
    /// presentation engine is still holding the semaphore for that image index.
    private let renderSems: [VkSemaphore]
    public private(set) var drawableSize: (width: Int, height: Int)

    public var pixelFormat: MTLPixelFormat = .rgba8Unorm
    
    ///   - surface: An already-created `VkSurfaceKHR` passed as `OpaquePointer`. **Not** owned by this object.
    ///   - width / height: Desired swapchain image extent.
    public init?(device: MTLDevice, surface: OpaquePointer, width: Int, height: Int) {
        self.device  = device
        drawableSize = (width: width, height: height)   // may be updated below from caps
        guard let dev = device.device,
            let physDev = device.physicalDevice
        else { return nil }

        var presentSupported: UInt32 = 0
        vkGetPhysicalDeviceSurfaceSupportKHR(physDev, device.computeQueueFamily,
                                              surface, &presentSupported)
        if presentSupported == 0 {
            print("[CAMetalLayer] queue family \(device.computeQueueFamily) does not support presentation â€” swapchain will likely fail")
        }

        var caps = VkSurfaceCapabilitiesKHR()
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physDev, surface, &caps)

        var fmtCount: UInt32 = 0
        vkGetPhysicalDeviceSurfaceFormatsKHR(physDev, surface, &fmtCount, nil)
        var surfFmts = [VkSurfaceFormatKHR](repeating: VkSurfaceFormatKHR(), count: Int(fmtCount))
        vkGetPhysicalDeviceSurfaceFormatsKHR(physDev, surface, &fmtCount, &surfFmts)

        let chosen =
            surfFmts.first { $0.format == VK_FORMAT_R8G8B8A8_UNORM }
            ?? surfFmts.first { $0.format == VK_FORMAT_B8G8R8A8_UNORM }
            ?? surfFmts[0]
        self.isBGRA = chosen.format == VK_FORMAT_B8G8R8A8_UNORM

        let scW = caps.currentExtent.width != 0xFFFF_FFFF ? caps.currentExtent.width : UInt32(width)
        let scH =
            caps.currentExtent.height != 0xFFFF_FFFF ? caps.currentExtent.height : UInt32(height)
        drawableSize = (width: Int(scW), height: Int(scH))
        let imageCount: UInt32 = {
            let n = caps.minImageCount + 1
            return caps.maxImageCount > 0 ? min(n, caps.maxImageCount) : n
        }()

        var qfIdx = device.computeQueueFamily
        var sc: VkSwapchainKHR? = nil
        withUnsafePointer(to: &qfIdx) { qfPtr in
            var sci = VkSwapchainCreateInfoKHR()
            sci.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
            sci.surface = surface
            sci.minImageCount = imageCount
            sci.imageFormat = chosen.format
            sci.imageColorSpace = chosen.colorSpace
            sci.imageExtent.width = scW
            sci.imageExtent.height = scH
            sci.imageArrayLayers = 1
            sci.imageUsage = VkImageUsageFlags(VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue
                                             | VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue)
            sci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
            sci.queueFamilyIndexCount = 1
            sci.pQueueFamilyIndices = qfPtr
            sci.preTransform = caps.currentTransform
            sci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
            sci.presentMode = VK_PRESENT_MODE_FIFO_KHR
            sci.clipped = VK_TRUE
            let scResult = vkCreateSwapchainKHR(dev, &sci, nil, &sc)
            if scResult != VK_SUCCESS {
                print("[CAMetalLayer] vkCreateSwapchainKHR failed (VkResult \(scResult.rawValue))")
            }
        }
        guard let swapchain = sc else {
            print("[CAMetalLayer] vkCreateSwapchainKHR returned null handle")
            return nil
        }

        var count: UInt32 = 0
        vkGetSwapchainImagesKHR(dev, swapchain, &count, nil)
        var raw = [VkImage?](repeating: nil, count: Int(count))
        vkGetSwapchainImagesKHR(dev, swapchain, &count, &raw)
        let images = raw.compactMap { $0 }

        var semCI = VkSemaphoreCreateInfo()
        semCI.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO

        var imgSem: VkSemaphore? = nil
        vkCreateSemaphore(dev, &semCI, nil, &imgSem)
        guard let imageSem = imgSem else {
            vkDestroySwapchainKHR(dev, swapchain, nil)
            print("[CAMetalLayer] vkCreateSemaphore (acquire) failed")
            return nil
        }

        // One render-done semaphore per image - each image cycles independently
        // through the presentation engine, so they must not share a semaphore.
        var renderSems: [VkSemaphore] = []
        for _ in 0..<count {
            var s: VkSemaphore? = nil
            vkCreateSemaphore(dev, &semCI, nil, &s)
            guard let sem = s else {
                renderSems.forEach { vkDestroySemaphore(dev, $0, nil) }
                vkDestroySemaphore(dev, imageSem, nil)
                vkDestroySwapchainKHR(dev, swapchain, nil)
                print("[CAMetalLayer] vkCreateSemaphore (render) failed")
                return nil
            }
            renderSems.append(sem)
        }

        print("[CAMetalLayer] \(count) images, \(isBGRA ? "BGRA" : "RGBA"), \(scW)Ã—\(scH)")

        self.vkDev = dev
        self.swapchain = swapchain
        self.images = images
        self.imageSem = imageSem
        self.renderSems = renderSems
    }

    /// Acquires the next available swapchain image and returns a `CAMetalDrawable`.
    public func nextDrawable() -> CAMetalDrawable? {
        var idx: UInt32 = 0
        let result = vkAcquireNextImageKHR(vkDev, swapchain, UInt64.max, imageSem, nil, &idx)
        guard result == VK_SUCCESS || result.rawValue == 1_000_001_003 /* VK_SUBOPTIMAL_KHR */
        else {
            print("[CAMetalLayer] vkAcquireNextImageKHR failed (\(result.rawValue))")
            return nil
        }
        return CAMetalDrawable(
            image:                   images[Int(idx)],
            isBGRA:                  isBGRA,
            imageIndex:              idx,
            width:                   drawableSize.width,
            height:                  drawableSize.height,
            device:                  device,
            imageAvailableSemaphore: imageSem,
            renderFinishedSemaphore: renderSems[Int(idx)],
            swapchainHandle:         swapchain)
    }

    deinit {
        vkDeviceWaitIdle(vkDev)
        // Destroy the swapchain before its semaphores - this forces the presentation
        // engine to complete any pending presents and release semaphore waits first.
        vkDestroySwapchainKHR(vkDev, swapchain, nil)
        renderSems.forEach { vkDestroySemaphore(vkDev, $0, nil) }
        vkDestroySemaphore(vkDev, imageSem, nil)
    }
}
