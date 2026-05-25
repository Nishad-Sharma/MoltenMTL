import CVulkan

// MARK: - MTLSizeAndAlign

/// Mirrors MTLSizeAndAlign — returned by `device.heapTextureSizeAndAlign(descriptor:)`.
public struct MTLSizeAndAlign {
    public var size:  Int
    public var align: Int
}

public extension MTLDevice {

    // MARK: - heapTextureSizeAndAlign

    /// Mirrors `MTLDevice.heapTextureSizeAndAlign(descriptor:)`.
    ///
    /// Returns the size and alignment that a texture matching `descriptor` would require
    /// when sub-allocated from a heap. Used by `HeapTextureManager.ensureHeapSpace` to
    /// verify that the heap has enough free space before attempting an allocation.
    ///
    /// Metal exposes this as a first-class device query. In Vulkan the only way to know
    /// a texture's memory footprint is to create a real (but unbound) `VkImage`, call
    /// `vkGetImageMemoryRequirements`, then destroy the image. This is a deliberate part
    /// of Vulkan's explicit model: the driver's tiling decisions are visible to the app.
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

        // Free the temporary image and its VMA allocation.
        CVMA_destroyImage(vmaAlloc, image, allocation)

        return MTLSizeAndAlign(size: Int(reqs.size), align: Int(reqs.alignment))
    }
}

public extension MTLDevice {

    // MARK: - makeHeap

    /// Mirrors `MTLDevice.makeHeap(descriptor:)`.
    ///
    /// Creates a VMA memory pool of the requested size and storage mode.
    /// The pool is backed by a single pre-allocated `VkDeviceMemory` block so
    /// subsequent `MTLHeap.makeBuffer` / `MTLHeap.makeTexture` calls sub-allocate
    /// from it without additional driver round-trips.
    func makeHeap(descriptor: MTLHeapDescriptor) -> MTLHeap? {
        guard let vmaAlloc = allocator else {
            print("[VulkanSwift] makeHeap: VMA allocator is nil")
            return nil
        }
        guard descriptor.size > 0 else {
            print("[VulkanSwift] makeHeap: size must be > 0")
            return nil
        }

        let mode = Int32(descriptor.storageMode == .private ? 1 : 0)

        var pool: VmaPool?
        let result = CVMA_createPool(vmaAlloc,
                                     VkDeviceSize(descriptor.size),
                                     mode,
                                     &pool)
        guard result == VK_SUCCESS else {
            print("[VulkanSwift] CVMA_createPool failed (VkResult \(result.rawValue))")
            return nil
        }

        return MTLHeap(pool:        pool,
                       size:        descriptor.size,
                       storageMode: descriptor.storageMode,
                       device:      self)
    }
}
