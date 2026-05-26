import CVulkan

public enum MTLStorageMode: Equatable {
    case shared    // CPU + GPU, persistently mapped
    case `private` // GPU-only, no CPU pointer
}

/// Raw-value layout matches Metal so existing Metal call-sites compile unchanged:
///   - bits [3:0]  CPU cache mode  (shift 0)
///   - bits [7:4]  storage mode    (shift 4)
///   - bits [9:8]  hazard tracking (shift 8)
public struct MTLResourceOptions: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) { self.rawValue = rawValue }

    // Storage mode (shift 4, matching Metal)
    public static let storageModeShared      = MTLResourceOptions(rawValue: 0 << 4)
    public static let storageModeManaged     = MTLResourceOptions(rawValue: 1 << 4)
    public static let storageModePrivate     = MTLResourceOptions(rawValue: 2 << 4)
    public static let storageModeMemoryless  = MTLResourceOptions(rawValue: 3 << 4)

    // CPU cache mode (shift 0)
    public static let cpuCacheModeDefaultCache:  MTLResourceOptions = []
    public static let cpuCacheModeWriteCombined  = MTLResourceOptions(rawValue: 1)

    // Hazard tracking (shift 8)
    public static let hazardTrackingModeDefault:  MTLResourceOptions = []
    public static let hazardTrackingModeUntracked = MTLResourceOptions(rawValue: 1 << 8)
    public static let hazardTrackingModeTracked   = MTLResourceOptions(rawValue: 2 << 8)

    // Convenience
    public var storageMode: MTLStorageMode {
        switch (rawValue >> 4) & 0xF {
        case 2:  return .private
        default: return .shared   // 0 (shared), 1 (managed→shared), 3 (memoryless→shared)
        }
    }
}

/// Create via `device.makeBuffer(length:options:)` - never instantiate directly.
public final class MTLBuffer {

    /// Persistently-mapped CPU pointer. `nil` for `.private` buffers.
    private var _contents: UnsafeMutableRawPointer?

    public func contents() -> UnsafeMutableRawPointer { _contents! }

    public let length: Int

    /// Raw `VkBuffer` - used by command encoders and device-address queries.
    let handle: VkBuffer?

    private let allocation:    VmaAllocation?
    private let vmaAllocator:  VmaAllocator?   // retained so deinit can call destroyBuffer
    private let vkDevice:      VkDevice?

    /// The heap this buffer was sub-allocated from, or `nil` for device-level allocations.
    /// Holding this reference keeps the heap alive.
    public let heap: MTLHeap?

    /// GPU-side device address for use in BDA / ray tracing.
    public var gpuAddress: UInt64 {
        guard let d = vkDevice, let b = handle else { return 0 }
        return CVKAS_getBufferDeviceAddress(d, b)
    }

    init(handle:       VkBuffer?,
         allocation:   VmaAllocation?,
         vmaAllocator: VmaAllocator?,
         vkDevice:     VkDevice?,
         contents:     UnsafeMutableRawPointer?,
         length:       Int,
         heap:         MTLHeap? = nil) {
        self.handle       = handle
        self.allocation   = allocation
        self.vmaAllocator = vmaAllocator
        self.vkDevice     = vkDevice
        self._contents    = contents
        self.length       = length
        self.heap         = heap
    }

    deinit {
        if let a = vmaAllocator, let b = handle, let alloc = allocation {
            CVMA_destroyBuffer(a, b, alloc)
        }
    }
}
