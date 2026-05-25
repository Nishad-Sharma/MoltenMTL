import CVulkan

// MARK: - StorageMode

/// Mirrors MTLStorageMode.
public enum MTLStorageMode: Equatable {
    case shared    // CPU + GPU — persistently mapped  (mirrors MTLStorageModeShared)
    case `private` // GPU-only  — no CPU pointer       (mirrors MTLStorageModePrivate)
}

// MARK: - ResourceOptions

/// Mirrors `MTLResourceOptions` — an OptionSet that encodes storage mode (and
/// optionally CPU cache mode / hazard tracking) in a single UInt.
///
/// Raw-value layout matches Metal exactly so existing Swift code that uses the
/// Apple SDK can be compiled unchanged against this Vulkan back-end:
///   - bits [3:0]  CPU cache mode  (shift 0)
///   - bits [7:4]  storage mode    (shift 4)
///   - bits [9:8]  hazard tracking (shift 8)
public struct MTLResourceOptions: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) { self.rawValue = rawValue }

    // ── Storage mode (shift 4, matching Metal) ───────────────────────────────
    public static let storageModeShared      = MTLResourceOptions(rawValue: 0 << 4)  // 0x00
    public static let storageModeManaged     = MTLResourceOptions(rawValue: 1 << 4)  // 0x10
    public static let storageModePrivate     = MTLResourceOptions(rawValue: 2 << 4)  // 0x20
    public static let storageModeMemoryless  = MTLResourceOptions(rawValue: 3 << 4)  // 0x30

    // ── CPU cache mode (shift 0) ─────────────────────────────────────────────
    public static let cpuCacheModeDefaultCache:  MTLResourceOptions = []          // rawValue 0 — empty set
    public static let cpuCacheModeWriteCombined  = MTLResourceOptions(rawValue: 1)

    // ── Hazard tracking (shift 8) ────────────────────────────────────────────
    public static let hazardTrackingModeDefault:  MTLResourceOptions = []         // rawValue 0 — empty set
    public static let hazardTrackingModeUntracked = MTLResourceOptions(rawValue: 1 << 8)
    public static let hazardTrackingModeTracked   = MTLResourceOptions(rawValue: 2 << 8)

    // ── Convenience ─────────────────────────────────────────────────────────
    /// Extract the storage-mode bits and return the equivalent `MTLStorageMode`.
    public var storageMode: MTLStorageMode {
        switch (rawValue >> 4) & 0xF {
        case 2:  return .private
        default: return .shared   // 0 (shared), 1 (managed→shared), 3 (memoryless→shared)
        }
    }
}

// MARK: - Buffer

/// Mirrors MTLBuffer.
/// Create via `device.makeBuffer(length:options:)` — never instantiate directly.
public final class MTLBuffer {

    // MARK: MTLBuffer-mirrored API

    /// Persistently-mapped CPU pointer. `nil` for `.private` buffers.
    /// Mirrors `MTLBuffer.contents()`.
    private var _contents: UnsafeMutableRawPointer?

    public func contents() -> UnsafeMutableRawPointer { _contents! }

    /// Byte length of the allocation. Mirrors `MTLBuffer.length`.
    public let length: Int

    // MARK: Internal Vulkan handles

    /// Raw `VkBuffer` — used by command encoders and device-address queries.
    let handle: VkBuffer?

    private let allocation:    VmaAllocation?
    private let vmaAllocator:  VmaAllocator?   // retained so deinit can call destroyBuffer
    private let vkDevice:      VkDevice?

    /// The heap this buffer was sub-allocated from, or `nil` for device-level allocations.
    /// Mirrors `MTLBuffer.heap`. Holding this reference keeps the heap alive.
    public let heap: MTLHeap?

    /// GPU-side address for use with buffer device address / buffer references.
    /// Mirrors `MTLBuffer.gpuAddress`.
    public var gpuAddress: UInt64 {
        guard let d = vkDevice, let b = handle else { return 0 }
        return CVKAS_getBufferDeviceAddress(d, b)
    }

    // MARK: Init (internal)

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

    // MARK: Deinit

    deinit {
        // VMA unmaps, unbinds, and frees everything in one call.
        if let a = vmaAllocator, let b = handle, let alloc = allocation {
            CVMA_destroyBuffer(a, b, alloc)
        }
    }
}
