internal import CVulkan

public struct MTLSizeAndAlign {
    public var size:  Int
    public var align: Int
}

public extension MTLDevice {

    /// Vulkan requires creating a real (unbound) `VkImage` and calling `vkGetImageMemoryRequirements`
    /// to determine this - the driver's tiling layout is not predictable ahead of time.
    func heapTextureSizeAndAlign(descriptor: MTLTextureDescriptor) -> MTLSizeAndAlign {
        guard let vkDev = device, let vmaAlloc = allocator else {
            return MTLSizeAndAlign(size: 0, align: 1)
        }

        var img: VkImage?
        var alloc: VmaAllocation?
        let result = CVMA_createImage(vmaAlloc,
                                      UInt32(descriptor.width),
                                      UInt32(descriptor.height),
                                      descriptor.pixelFormat.vkFormat,
                                      descriptor.vkUsage,
                                      UInt32(descriptor.mipmapLevelCount),
                                      &img,
                                      &alloc)
        guard result == VK_SUCCESS, let image = img, let allocation = alloc else {
            // Fallback: conservative estimate (width * height * bpp * mip overhead)
            let bpp   = descriptor.pixelFormat.bytesPerPixel
            let mips  = descriptor.mipmapLevelCount
            let size  = descriptor.width * descriptor.height * bpp * 2 * mips
            return MTLSizeAndAlign(size: size, align: 4096)
        }

        var reqs = VkMemoryRequirements()
        vkGetImageMemoryRequirements(vkDev, image, &reqs)
        CVMA_destroyImage(vmaAlloc, image, allocation)

        return MTLSizeAndAlign(size: Int(reqs.size), align: Int(reqs.alignment))
    }
}

public extension MTLDevice {

    /// Creates a fixed-size GPU memory heap from which buffers and textures can be sub-allocated.
    /// - Returns: A new `MTLHeap`, or `nil` if the VMA pool could not be created.
    func makeHeap(descriptor: MTLHeapDescriptor) -> MTLHeap? {
        guard let vmaAlloc = allocator else {
            print("[MoltenMTL] makeHeap: VMA allocator is nil")
            return nil
        }
        guard descriptor.size > 0 else {
            print("[MoltenMTL] makeHeap: size must be > 0")
            return nil
        }

        let mode = Int32(descriptor.storageMode == .private ? 1 : 0)

        var pool: VmaPool?
        let result = CVMA_createPool(vmaAlloc,
                                     VkDeviceSize(descriptor.size),
                                     mode,
                                     &pool)
        guard result == VK_SUCCESS else {
            print("[MoltenMTL] CVMA_createPool failed (VkResult \(result.rawValue))")
            return nil
        }

        return MTLHeap(pool:        pool,
                       size:        descriptor.size,
                       storageMode: descriptor.storageMode,
                       device:      self)
    }
}
