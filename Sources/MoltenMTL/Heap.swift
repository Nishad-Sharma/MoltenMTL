import CVulkan

// MARK: - MTLHazardTrackingMode / MTLHeapType

/// Mirrors MTLHazardTrackingMode.
/// Metal uses this to opt out of automatic resource-barrier insertion.
/// On Vulkan all barriers are always manual, so this is a no-op API-parity type.
public enum MTLHazardTrackingMode {
    case `default`  // Metal default: driver tracks hazards automatically
    case tracked    // Explicit opt-in to hazard tracking (same as default on most drivers)
    case untracked  // Caller is responsible for barriers — matches Vulkan's always-manual model
}

/// Mirrors MTLHeapType.
/// `.automatic` = driver places resources; `.placement` = caller specifies byte offsets.
/// VMA handles placement automatically, so this is always a no-op.
public enum MTLHeapType {
    case automatic
    case placement
}

// MARK: - HeapDescriptor

/// Mirrors MTLHeapDescriptor — describes a heap before creation.
/// Pass to `device.makeHeap(descriptor:)`.
public final class MTLHeapDescriptor {
    /// Total byte size of the heap's backing memory block.
    public var size: Int = 0
    /// CPU/GPU access mode for resources sub-allocated from this heap.
    public var storageMode: MTLStorageMode = .private
    /// Hazard tracking mode — no-op on Vulkan (barriers are always manual).
    public var hazardTrackingMode: MTLHazardTrackingMode = .default
    /// Heap placement type — no-op on Vulkan (VMA manages placement).
    public var type: MTLHeapType = .automatic

    public init() {}
}

// MARK: - Heap

/// Mirrors MTLHeap — a fixed-size pre-allocated block of GPU memory from which
/// buffers and textures can be sub-allocated without individual device round-trips.
///
/// Create via `device.makeHeap(descriptor:)` — never instantiate directly.
///
/// Backed by a single-block `VmaPool`. Sub-allocations from the heap use the
/// same `CVMA_destroyBuffer` / `CVMA_destroyImage` paths as device-level
/// resources; memory is returned to the pool block, not to the OS, until the
/// heap itself is destroyed.
public final class MTLHeap {

    // MARK: Public Metal-mirrored API

    /// Total byte size of the heap's backing memory block.
    public let size: Int

    /// CPU/GPU access mode shared by all resources in this heap.
    public let storageMode: MTLStorageMode

    /// Bytes currently occupied by live sub-allocations.
    /// Mirrors `MTLHeap.usedSize`.
    public var usedSize: Int {
        var used: VkDeviceSize = 0
        if let a = device.allocator, let p = pool {
            CVMA_getPoolStats(a, p, nil, &used)
        }
        return Int(used)
    }

    /// Approximate bytes still available for new sub-allocations.
    /// Mirrors `MTLHeap.maxAvailableSize(alignment:)`.
    /// The `alignment` parameter is accepted for API parity — VMA handles
    /// alignment internally during sub-allocation.
    public func maxAvailableSize(alignment: Int = 0) -> Int {
        return max(0, size - usedSize)
    }

    // MARK: Internal Vulkan handle

    let pool: VmaPool?

    // MARK: Private

    private let device: MTLDevice   // strong ref — keeps VMA allocator alive

    // MARK: Init (internal)

    init(pool: VmaPool?, size: Int, storageMode: MTLStorageMode, device: MTLDevice) {
        self.pool        = pool
        self.size        = size
        self.storageMode = storageMode
        self.device      = device
    }

    // MARK: Deinit

    deinit {
        // VMA requires all sub-allocations from the pool to be freed before this
        // call. Resources that hold a strong ref to this heap ensure that ordering:
        // their deinit runs first (freeing the sub-allocation), then this deinit runs.
        if let a = device.allocator, let p = pool {
            CVMA_destroyPool(a, p)
        }
    }

    // MARK: - makeBuffer

    /// Mirrors `MTLHeap.makeBuffer(length:options:)`.
    ///
    /// Sub-allocates a `VkBuffer` from this heap's VMA pool.
    /// The returned buffer holds a strong reference to this heap.
    ///
    /// - Parameters:
    ///   - length: Byte size of the buffer.
    ///   - options: Storage mode override; defaults to the heap's own `storageMode`.
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
            print("[VulkanSwift] CVMA_createBufferInPool failed (VkResult \(result.rawValue))")
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

    // MARK: - makeTexture

    /// Mirrors `MTLHeap.makeTexture(descriptor:)`.
    ///
    /// Sub-allocates a `VkImage` (and creates its `VkImageView`) from this
    /// heap's VMA pool. The returned texture holds a strong reference to this heap.
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
            print("[VulkanSwift] CVMA_createImageInPool failed")
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
            print("[VulkanSwift] vkCreateImageView failed (heap texture)")
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
