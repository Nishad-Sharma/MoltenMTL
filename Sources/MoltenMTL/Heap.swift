internal import CVulkan

/// On Vulkan all barriers are always manual - this exists for API parity only.
public enum MTLHazardTrackingMode {
    case `default`
    case tracked
    case untracked
}

/// VMA handles placement automatically - this exists for API parity only.
public enum MTLHeapType {
    case automatic
    case placement
}


/// Mirrors MTLHeapDescriptor - describes a heap before creation.
/// Pass to `device.makeHeap(descriptor:)`.
public final class MTLHeapDescriptor {
    public var size: Int = 0
    public var storageMode: MTLStorageMode = .private
    /// No-op on Vulkan - all barriers are manual.
    public var hazardTrackingMode: MTLHazardTrackingMode = .default
    /// No-op on Vulkan - VMA manages placement.
    public var type: MTLHeapType = .automatic

    public init() {}
}

/// Mirrors MTLHeap - a fixed-size pre-allocated block of GPU memory from which
/// buffers and textures can be sub-allocated without individual device round-trips.
///
/// Create via `device.makeHeap(descriptor:)` - never instantiate directly.
///
/// Backed by a single-block `VmaPool`. Sub-allocations from the heap use the
/// same `CVMA_destroyBuffer` / `CVMA_destroyImage` paths as device-level
/// resources; memory is returned to the pool block, not to the OS, until the
/// heap itself is destroyed.
public final class MTLHeap {

    public var label: String?

    public let size: Int
    public let storageMode: MTLStorageMode

    /// Bytes currently occupied by live sub-allocations.
    public var usedSize: Int {
        var used: VkDeviceSize = 0
        if let a = device.allocator, let p = pool {
            CVMA_getPoolStats(a, p, nil, &used)
        }
        return Int(used)
    }

    /// Approximate bytes still available for new sub-allocations.
    /// The `alignment` parameter is accepted for API parity; VMA handles alignment internally.
    public func maxAvailableSize(alignment: Int = 0) -> Int {
        return max(0, size - usedSize)
    }

    let pool: VmaPool?

    private let device: MTLDevice   // strong ref — keeps VMA allocator alive

    init(pool: VmaPool?, size: Int, storageMode: MTLStorageMode, device: MTLDevice) {
        self.pool        = pool
        self.size        = size
        self.storageMode = storageMode
        self.device      = device
    }

    deinit {
        // VMA requires all sub-allocations from the pool to be freed before this
        // call. Resources that hold a strong ref to this heap ensure that ordering:
        // their deinit runs first (freeing the sub-allocation), then this deinit runs.
        if let a = device.allocator, let p = pool {
            CVMA_destroyPool(a, p)
        }
    }

    /// Sub-allocates a `VkBuffer` from this heap's VMA pool.
    /// The returned buffer holds a strong reference to this heap.
    public func makeBuffer(length: Int, options: MTLStorageMode? = nil) -> MTLBuffer? {
        guard let vmaAlloc = device.allocator, let p = pool else { return nil }

        let mode = Int32((options ?? storageMode) == .private ? 1 : 0)

        let usage = UInt32(bitPattern: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue)
                  | UInt32(bitPattern: VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT.rawValue)
                  | UInt32(bitPattern: VK_BUFFER_USAGE_TRANSFER_SRC_BIT.rawValue)
                  | UInt32(bitPattern: VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue)
                  | UInt32(bitPattern: VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR.rawValue)

        var buf:    VkBuffer?
        var vmaBuf: VmaAllocation?
        var mapped: UnsafeMutableRawPointer?

        let result = CVMA_createBufferInPool(vmaAlloc, p,
                                             VkDeviceSize(length),
                                             usage, mode,
                                             &buf, &vmaBuf, &mapped)
        guard result == VK_SUCCESS else {
            print("[MoltenMTL] CVMA_createBufferInPool failed (VkResult \(result.rawValue))")
            return nil
        }

        return MTLBuffer(handle:       buf,
                         allocation:   vmaBuf,
                         vmaAllocator: vmaAlloc,
                         vkDevice:     device.device,
                         contents:     mapped,
                         length:       length,
                         heap:         self)
    }

    /// Sub-allocates a `VkImage` from this heap's VMA pool.
    /// The returned texture holds a strong reference to this heap.
    public func makeTexture(descriptor: MTLTextureDescriptor) -> MTLTexture? {
        guard let vmaAlloc = device.allocator,
              let vkDev    = device.device,
              let p        = pool else { return nil }

        var img:   VkImage?
        var alloc: VmaAllocation?

        guard CVMA_createImageInPool(vmaAlloc, p,
                                     UInt32(descriptor.width),
                                     UInt32(descriptor.height),
                                     descriptor.pixelFormat.vkFormat,
                                     descriptor.vkUsage,
                                     UInt32(descriptor.mipmapLevelCount),
                                     &img, &alloc) == VK_SUCCESS else {
            print("[MoltenMTL] CVMA_createImageInPool failed")
            return nil
        }

        var viewCI = VkImageViewCreateInfo()
        viewCI.sType                           = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
        viewCI.image                           = img
        viewCI.viewType                        = VK_IMAGE_VIEW_TYPE_2D
        viewCI.format                          = descriptor.pixelFormat.vkFormat
        viewCI.components.r                    = VK_COMPONENT_SWIZZLE_IDENTITY
        viewCI.components.g                    = VK_COMPONENT_SWIZZLE_IDENTITY
        viewCI.components.b                    = VK_COMPONENT_SWIZZLE_IDENTITY
        viewCI.components.a                    = VK_COMPONENT_SWIZZLE_IDENTITY
        viewCI.subresourceRange.aspectMask     = descriptor.pixelFormat.aspectMask
        viewCI.subresourceRange.baseMipLevel   = 0
        viewCI.subresourceRange.levelCount     = UInt32(descriptor.mipmapLevelCount)
        viewCI.subresourceRange.baseArrayLayer = 0
        viewCI.subresourceRange.layerCount     = 1

        var view: VkImageView?
        guard vkCreateImageView(vkDev, &viewCI, nil, &view) == VK_SUCCESS else {
            print("[MoltenMTL] vkCreateImageView failed (heap texture)")
            if let a = device.allocator, let i = img, let al = alloc {
                CVMA_destroyImage(a, i, al)
            }
            return nil
        }

        return MTLTexture(image:            img,
                          imageView:        view,
                          allocation:       alloc,
                          device:           device,
                          width:            descriptor.width,
                          height:           descriptor.height,
                          pixelFormat:      descriptor.pixelFormat,
                          mipmapLevelCount: descriptor.mipmapLevelCount,
                          usage:            descriptor.usage,
                          heap:             self)
    }
}
