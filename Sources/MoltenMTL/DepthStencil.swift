internal import CVulkan

/// Comparison used for depth (and, in Metal, stencil) testing. A fragment passes
/// when `incoming COMPARE stored` is true.
public enum MTLCompareFunction {
    case never
    case less
    case equal
    case lessEqual
    case greater
    case notEqual
    case greaterEqual
    case always

    var vkCompareOp: VkCompareOp {
        switch self {
        case .never:        return VK_COMPARE_OP_NEVER
        case .less:         return VK_COMPARE_OP_LESS
        case .equal:        return VK_COMPARE_OP_EQUAL
        case .lessEqual:    return VK_COMPARE_OP_LESS_OR_EQUAL
        case .greater:      return VK_COMPARE_OP_GREATER
        case .notEqual:     return VK_COMPARE_OP_NOT_EQUAL
        case .greaterEqual: return VK_COMPARE_OP_GREATER_OR_EQUAL
        case .always:       return VK_COMPARE_OP_ALWAYS
        }
    }
}

/// Describes a depth/stencil state before creating it via
/// `device.makeDepthStencilState(descriptor:)`.
public final class MTLDepthStencilDescriptor {

    public var label: String?
    public var depthCompareFunction: MTLCompareFunction = .always
    public var isDepthWriteEnabled: Bool = false

    /// Per-face stencil state. Defaults are pass-through (no stencil effect).
    public var frontFaceStencil = MTLStencilDescriptor()
    public var backFaceStencil  = MTLStencilDescriptor()

    public init() {}
}

/// Immutable depth/stencil configuration bound to a render encoder via
/// `setDepthStencilState(_:)`. Create via `device.makeDepthStencilState(descriptor:)`.
///
/// Depth state is applied as Vulkan dynamic state, so a single pipeline can be
/// drawn with different compare functions / write masks across draws — matching
/// Metal's separation of pipeline state from depth-stencil state. There is no
/// backing Vulkan object; this just carries the resolved values.
public final class MTLDepthStencilState {

    /// Read-only in Metal - set through `MTLDepthStencilDescriptor.label`.
    public let label: String?

    let depthCompareOp:   VkCompareOp
    let depthWriteEnable: Bool

    /// Resolved per-face stencil op state (reference value applied dynamically).
    let frontStencil:   VkStencilOpState
    let backStencil:    VkStencilOpState
    /// `true` when either face does more than pass through unchanged.
    let stencilEnabled: Bool

    init(depthCompareOp: VkCompareOp,
         depthWriteEnable: Bool,
         frontStencil: VkStencilOpState,
         backStencil: VkStencilOpState,
         stencilEnabled: Bool,
         label: String? = nil) {
        self.label            = label
        self.depthCompareOp   = depthCompareOp
        self.depthWriteEnable = depthWriteEnable
        self.frontStencil     = frontStencil
        self.backStencil      = backStencil
        self.stencilEnabled   = stencilEnabled
    }
}
