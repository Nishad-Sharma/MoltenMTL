internal import CVulkan

/// Source/destination multiplier for blending.
public enum MTLBlendFactor {
    case zero
    case one
    case sourceColor
    case oneMinusSourceColor
    case sourceAlpha
    case oneMinusSourceAlpha
    case destinationColor
    case oneMinusDestinationColor
    case destinationAlpha
    case oneMinusDestinationAlpha

    var vkBlendFactor: VkBlendFactor {
        switch self {
        case .zero:                     return VK_BLEND_FACTOR_ZERO
        case .one:                      return VK_BLEND_FACTOR_ONE
        case .sourceColor:              return VK_BLEND_FACTOR_SRC_COLOR
        case .oneMinusSourceColor:      return VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR
        case .sourceAlpha:              return VK_BLEND_FACTOR_SRC_ALPHA
        case .oneMinusSourceAlpha:      return VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
        case .destinationColor:         return VK_BLEND_FACTOR_DST_COLOR
        case .oneMinusDestinationColor: return VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR
        case .destinationAlpha:         return VK_BLEND_FACTOR_DST_ALPHA
        case .oneMinusDestinationAlpha: return VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA
        }
    }
}

/// How source and destination blend terms are combined.
public enum MTLBlendOperation {
    case add
    case subtract
    case reverseSubtract
    case min
    case max

    var vkBlendOp: VkBlendOp {
        switch self {
        case .add:             return VK_BLEND_OP_ADD
        case .subtract:        return VK_BLEND_OP_SUBTRACT
        case .reverseSubtract: return VK_BLEND_OP_REVERSE_SUBTRACT
        case .min:             return VK_BLEND_OP_MIN
        case .max:             return VK_BLEND_OP_MAX
        }
    }
}

/// Which color channels a render pipeline writes.
public struct MTLColorWriteMask: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    // Raw values match VK_COLOR_COMPONENT_*_BIT so the mask passes through directly.
    public static let red   = MTLColorWriteMask(rawValue: 1 << 0)
    public static let green = MTLColorWriteMask(rawValue: 1 << 1)
    public static let blue  = MTLColorWriteMask(rawValue: 1 << 2)
    public static let alpha = MTLColorWriteMask(rawValue: 1 << 3)
    public static let all: MTLColorWriteMask = [.red, .green, .blue, .alpha]
}

/// Blend and format configuration for one color attachment of a render pipeline.
public final class MTLRenderPipelineColorAttachmentDescriptor {

    public var pixelFormat: MTLPixelFormat = .rgba8Unorm
    public var isBlendingEnabled = false
    public var sourceRGBBlendFactor:        MTLBlendFactor = .one
    public var destinationRGBBlendFactor:   MTLBlendFactor = .zero
    public var rgbBlendOperation:           MTLBlendOperation = .add
    public var sourceAlphaBlendFactor:      MTLBlendFactor = .one
    public var destinationAlphaBlendFactor: MTLBlendFactor = .zero
    public var alphaBlendOperation:         MTLBlendOperation = .add
    public var writeMask: MTLColorWriteMask = .all

    public init() {}

    var vkBlendState: VkPipelineColorBlendAttachmentState {
        var state = VkPipelineColorBlendAttachmentState()
        state.blendEnable         = isBlendingEnabled ? VK_TRUE : VK_FALSE
        state.srcColorBlendFactor = sourceRGBBlendFactor.vkBlendFactor
        state.dstColorBlendFactor = destinationRGBBlendFactor.vkBlendFactor
        state.colorBlendOp        = rgbBlendOperation.vkBlendOp
        state.srcAlphaBlendFactor = sourceAlphaBlendFactor.vkBlendFactor
        state.dstAlphaBlendFactor = destinationAlphaBlendFactor.vkBlendFactor
        state.alphaBlendOp        = alphaBlendOperation.vkBlendOp
        state.colorWriteMask      = writeMask.rawValue
        return state
    }
}

/// Describes a render pipeline before creating it via
/// `device.makeRenderPipelineState(descriptor:)`.
/// Only `colorAttachments[0]` is supported (single color attachment). Set
/// `depthAttachmentPixelFormat` to render with a depth attachment (no stencil).
public final class MTLRenderPipelineDescriptor {

    public var label: String?
    public var vertexFunction:   MTLFunction?
    public var fragmentFunction: MTLFunction?
    public var vertexDescriptor: MTLVertexDescriptor?

    public let colorAttachments =
        MTLDescriptorArray { MTLRenderPipelineColorAttachmentDescriptor() }

    /// Pixel format of the depth attachment, or `nil` for depth-less rendering.
    /// Must match the depth texture's format (`.depth32Float` or
    /// `.depth32Float_stencil8`). Depth test/write behaviour itself comes from the
    /// `MTLDepthStencilState` bound on the encoder.
    public var depthAttachmentPixelFormat: MTLPixelFormat?

    /// Pixel format of the stencil attachment, or `nil` for stencil-less rendering.
    /// For a combined format, set the same value as `depthAttachmentPixelFormat`.
    public var stencilAttachmentPixelFormat: MTLPixelFormat?

    public init() {}
}
