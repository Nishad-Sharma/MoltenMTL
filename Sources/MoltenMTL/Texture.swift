internal import CVulkan

/// A 3-D texel coordinate within a texture.
public struct MTLOrigin {
    public var x: Int
    public var y: Int
    public var z: Int

    public init(x: Int = 0, y: Int = 0, z: Int = 0) {
        self.x = x; self.y = y; self.z = z
    }
}

/// An axis-aligned rectangular region of a texture.
public struct MTLRegion {
    public var origin: MTLOrigin
    public var size:   MTLSize

    public init(origin: MTLOrigin = MTLOrigin(), size: MTLSize) {
        self.origin = origin
        self.size   = size
    }

    /// Convenience initialiser for a 2-D region with an optional (x, y) offset.
    public static func make2D(x: Int = 0, y: Int = 0,
                               width: Int, height: Int) -> MTLRegion {
        MTLRegion(origin: MTLOrigin(x: x, y: y, z: 0),
               size:   MTLSize(width: width, height: height, depth: 1))
    }
}

/// Create via `device.makeTexture(descriptor:)` — never instantiate directly.
public final class MTLTexture {

    public let width:            Int
    public let height:           Int
    public let pixelFormat:      MTLPixelFormat
    public let mipmapLevelCount: Int
    public let usage:            MTLTextureUsage

    /// Raw `VkImage` — available for binding to descriptor sets, render-pass
    /// attachments, or pipeline barriers.
    let image: VkImage?

    /// Default `VkImageView` spanning all mip levels and the single array layer.
    /// Used when binding the texture as a shader resource.
    let imageView: VkImageView?

    private let allocation:    VmaAllocation?
    private let device:        MTLDevice      // strong ref — keeps the allocator alive

    /// The heap this texture was sub-allocated from, or `nil` for device-level allocations.
    /// Holding this reference keeps the heap alive.
    public let heap: MTLHeap?

    /// Tracks the current `VkImageLayout` so encoders can emit correct barriers.
    var currentLayout: VkImageLayout = VK_IMAGE_LAYOUT_UNDEFINED

    init(image:            VkImage?,
         imageView:        VkImageView?,
         allocation:       VmaAllocation?,
         device:           MTLDevice,
         width:            Int,
         height:           Int,
         pixelFormat:      MTLPixelFormat,
         mipmapLevelCount: Int,
         usage:            MTLTextureUsage,
         heap:             MTLHeap? = nil) {
        self.image            = image
        self.imageView        = imageView
        self.allocation       = allocation
        self.device           = device
        self.width            = width
        self.height           = height
        self.pixelFormat      = pixelFormat
        self.mipmapLevelCount = mipmapLevelCount
        self.usage            = usage
        self.heap             = heap
    }

    deinit {
        if let dev = device.device {
            if let view = imageView { vkDestroyImageView(dev, view, nil) }
        }
        if let a = device.allocator, let img = image, let alloc = allocation {
            CVMA_destroyImage(a, img, alloc)
        }
    }

    /// Synchronously uploads CPU pixel data into the texture at `mipmapLevel`.
    /// Creates a one-shot command buffer, submits it, and waits for completion.
    public func replace(region:      MTLRegion,
                        mipmapLevel: Int = 0,
                        withBytes:   UnsafeRawPointer,
                        bytesPerRow: Int) {
        guard let vkDev    = device.device,
              let vmaAlloc = device.allocator,
              let vkQueue  = device.queue,
              let img      = image else { return }

        let byteCount = region.size.height * bytesPerRow

        // Staging buffer (host-visible, shared mode)
        let transferSrc = UInt32(bitPattern: VK_BUFFER_USAGE_TRANSFER_SRC_BIT.rawValue)
        var stagingBuf:   VkBuffer?
        var stagingAlloc: VmaAllocation?
        var mapped:       UnsafeMutableRawPointer?

        guard CVMA_createBuffer(vmaAlloc, VkDeviceSize(byteCount),
                                transferSrc, 0 /* shared */,
                                &stagingBuf, &stagingAlloc, &mapped) == VK_SUCCESS,
              let sb         = stagingBuf,
              let sa         = stagingAlloc,
              let mappedPtr  = mapped else { return }

        defer { CVMA_destroyBuffer(vmaAlloc, sb, sa) }
        mappedPtr.copyMemory(from: withBytes, byteCount: byteCount)

        // Transient command pool + one-shot command buffer
        var poolCI = VkCommandPoolCreateInfo()
        poolCI.sType            = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
        poolCI.flags            = UInt32(bitPattern: VK_COMMAND_POOL_CREATE_TRANSIENT_BIT.rawValue)
        poolCI.queueFamilyIndex = device.computeQueueFamily

        var pool: VkCommandPool?
        guard vkCreateCommandPool(vkDev, &poolCI, nil, &pool) == VK_SUCCESS,
              let pl = pool else { return }
        defer { vkDestroyCommandPool(vkDev, pl, nil) }   // also frees cmdBuf

        var cmdBufAI = VkCommandBufferAllocateInfo()
        cmdBufAI.sType              = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
        cmdBufAI.commandPool        = pl
        cmdBufAI.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY
        cmdBufAI.commandBufferCount = 1

        var cmdOpt: VkCommandBuffer?
        guard vkAllocateCommandBuffers(vkDev, &cmdBufAI, &cmdOpt) == VK_SUCCESS,
              let cmdBuf = cmdOpt else { return }

        var beginInfo = VkCommandBufferBeginInfo()
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
        beginInfo.flags = UInt32(bitPattern: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.rawValue)
        vkBeginCommandBuffer(cmdBuf, &beginInfo)

        // Barrier: currentLayout → TRANSFER_DST_OPTIMAL
        let transferDst = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
        imageBarrier(cmd:        cmdBuf,
                     image:      img,
                     oldLayout:  currentLayout,
                     newLayout:  transferDst,
                     srcAccess:  0,
                     dstAccess:  UInt32(bitPattern: VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                     srcStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT.rawValue),
                     dstStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                     aspectMask: pixelFormat.aspectMask)

        // Copy staging buffer → image
        var bic = VkBufferImageCopy()
        bic.bufferOffset                    = 0
        bic.bufferRowLength                 = 0        // tightly packed
        bic.bufferImageHeight               = 0
        bic.imageSubresource.aspectMask     = pixelFormat.aspectMask
        bic.imageSubresource.mipLevel       = UInt32(mipmapLevel)
        bic.imageSubresource.baseArrayLayer = 0
        bic.imageSubresource.layerCount     = 1
        bic.imageOffset.x                   = Int32(region.origin.x)
        bic.imageOffset.y                   = Int32(region.origin.y)
        bic.imageOffset.z                   = Int32(region.origin.z)
        bic.imageExtent.width               = UInt32(region.size.width)
        bic.imageExtent.height              = UInt32(region.size.height)
        bic.imageExtent.depth               = UInt32(region.size.depth)

        withUnsafePointer(to: bic) { bicPtr in
            vkCmdCopyBufferToImage(cmdBuf, sb, img, transferDst, 1, bicPtr)
        }

        // Barrier: TRANSFER_DST_OPTIMAL → final shader layout
        // Storage images (shaderWrite) stay in GENERAL; read-only textures
        // go to SHADER_READ_ONLY_OPTIMAL.
        let finalLayout: VkImageLayout = usage.contains(.shaderWrite)
                                        ? VK_IMAGE_LAYOUT_GENERAL
                                        : VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL

        imageBarrier(cmd:        cmdBuf,
                     image:      img,
                     oldLayout:  transferDst,
                     newLayout:  finalLayout,
                     srcAccess:  UInt32(bitPattern: VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                     dstAccess:  UInt32(bitPattern: VK_ACCESS_SHADER_READ_BIT.rawValue),
                     srcStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                     dstStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT.rawValue),
                     aspectMask: pixelFormat.aspectMask)

        currentLayout = finalLayout
        vkEndCommandBuffer(cmdBuf)

        // Submit + wait
        var h: VkCommandBuffer? = cmdBuf
        withUnsafePointer(to: &h) { cmdPtr in
            var submitInfo = VkSubmitInfo()
            submitInfo.sType              = VK_STRUCTURE_TYPE_SUBMIT_INFO
            submitInfo.commandBufferCount = 1
            submitInfo.pCommandBuffers    = cmdPtr
            vkQueueSubmit(vkQueue, 1, &submitInfo, nil)
        }
        vkQueueWaitIdle(vkQueue)
    }
}

/// Records a `VkImageMemoryBarrier` transitioning `image` between layouts.
func imageBarrier(cmd:        VkCommandBuffer,
                           image:      VkImage?,
                           oldLayout:  VkImageLayout,
                           newLayout:  VkImageLayout,
                           srcAccess:  UInt32,
                           dstAccess:  UInt32,
                           srcStage:   UInt32,
                           dstStage:   UInt32,
                           aspectMask: UInt32) {
    var barrier = VkImageMemoryBarrier()
    barrier.sType               = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
    barrier.oldLayout           = oldLayout
    barrier.newLayout           = newLayout
    // VK_QUEUE_FAMILY_IGNORED - no ownership transfer
    barrier.srcQueueFamilyIndex = UInt32.max
    barrier.dstQueueFamilyIndex = UInt32.max
    barrier.image               = image
    barrier.subresourceRange.aspectMask     = aspectMask
    barrier.subresourceRange.baseMipLevel   = 0
    barrier.subresourceRange.levelCount     = UInt32.max   // VK_REMAINING_MIP_LEVELS
    barrier.subresourceRange.baseArrayLayer = 0
    barrier.subresourceRange.layerCount     = UInt32.max   // VK_REMAINING_ARRAY_LAYERS
    barrier.srcAccessMask       = srcAccess
    barrier.dstAccessMask       = dstAccess

    withUnsafePointer(to: barrier) { barrierPtr in
        vkCmdPipelineBarrier(cmd, srcStage, dstStage, 0,
                             0, nil,
                             0, nil,
                             1, barrierPtr)
    }
}
