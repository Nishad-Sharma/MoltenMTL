internal import CVulkan

/// Operation applied to a stencil value when the stencil (and depth) test
/// resolves a given way.
public enum MTLStencilOperation {
    case keep
    case zero
    case replace
    case incrementClamp
    case decrementClamp
    case invert
    case incrementWrap
    case decrementWrap

    var vkStencilOp: VkStencilOp {
        switch self {
        case .keep:           return VK_STENCIL_OP_KEEP
        case .zero:           return VK_STENCIL_OP_ZERO
        case .replace:        return VK_STENCIL_OP_REPLACE
        case .incrementClamp: return VK_STENCIL_OP_INCREMENT_AND_CLAMP
        case .decrementClamp: return VK_STENCIL_OP_DECREMENT_AND_CLAMP
        case .invert:         return VK_STENCIL_OP_INVERT
        case .incrementWrap:  return VK_STENCIL_OP_INCREMENT_AND_WRAP
        case .decrementWrap:  return VK_STENCIL_OP_DECREMENT_AND_WRAP
        }
    }
}

/// Per-face stencil configuration. Held by `MTLDepthStencilDescriptor` for the
/// front and back faces. The reference value is *not* part of this descriptor —
/// it is set on the encoder via `setStencilReferenceValue(_:)`, matching Metal.
public final class MTLStencilDescriptor {

    public var stencilCompareFunction:    MTLCompareFunction  = .always
    public var stencilFailureOperation:   MTLStencilOperation = .keep
    public var depthFailureOperation:     MTLStencilOperation = .keep
    public var depthStencilPassOperation: MTLStencilOperation = .keep
    public var readMask:  UInt32 = 0xFFFF_FFFF
    public var writeMask: UInt32 = 0xFFFF_FFFF

    public init() {}

    /// `true` when this face would change stencil contents or reject fragments —
    /// i.e. it is not the default pass-through (compare `.always`, ops `.keep`).
    var isActive: Bool {
        stencilCompareFunction != .always
            || stencilFailureOperation   != .keep
            || depthFailureOperation     != .keep
            || depthStencilPassOperation != .keep
    }

    /// Resolves to a `VkStencilOpState`. `reference` is left 0 — the encoder
    /// supplies it as dynamic state from `setStencilReferenceValue(_:)`.
    var vkStencilOpState: VkStencilOpState {
        var s = VkStencilOpState()
        s.failOp      = stencilFailureOperation.vkStencilOp
        s.passOp      = depthStencilPassOperation.vkStencilOp
        s.depthFailOp = depthFailureOperation.vkStencilOp
        s.compareOp   = stencilCompareFunction.vkCompareOp
        s.compareMask = readMask
        s.writeMask   = writeMask
        s.reference   = 0
        return s
    }
}
