internal import CVulkan

/// Action performed on an attachment at the start of a render pass.
public enum MTLLoadAction {
    case dontCare
    case load
    case clear

    var vkLoadOp: VkAttachmentLoadOp {
        switch self {
        case .dontCare: return VK_ATTACHMENT_LOAD_OP_DONT_CARE
        case .load:     return VK_ATTACHMENT_LOAD_OP_LOAD
        case .clear:    return VK_ATTACHMENT_LOAD_OP_CLEAR
        }
    }
}

/// Action performed on an attachment at the end of a render pass.
public enum MTLStoreAction {
    case dontCare
    case store

    var vkStoreOp: VkAttachmentStoreOp {
        switch self {
        case .dontCare: return VK_ATTACHMENT_STORE_OP_DONT_CARE
        case .store:    return VK_ATTACHMENT_STORE_OP_STORE
        }
    }
}

/// Clear value for a color attachment.
public struct MTLClearColor {
    public var red:   Double
    public var green: Double
    public var blue:  Double
    public var alpha: Double

    public init(red: Double = 0, green: Double = 0, blue: Double = 0, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
}

public func MTLClearColorMake(_ red: Double, _ green: Double,
                              _ blue: Double, _ alpha: Double) -> MTLClearColor {
    MTLClearColor(red: red, green: green, blue: blue, alpha: alpha)
}

/// One color attachment of a render pass: its target texture and load/store behaviour.
public final class MTLRenderPassColorAttachmentDescriptor {
    public var texture:     MTLTexture?
    public var loadAction:  MTLLoadAction  = .dontCare
    public var storeAction: MTLStoreAction = .store
    public var clearColor:  MTLClearColor  = MTLClearColor()

    public init() {}
}

/// The depth attachment of a render pass. `texture == nil` means depth-less
/// rendering. A depth texture must use `pixelFormat = .depth32Float` and
/// `usage = .renderTarget`. `clearDepth` is used when `loadAction == .clear`.
public final class MTLRenderPassDepthAttachmentDescriptor {
    public var texture:     MTLTexture?
    public var loadAction:  MTLLoadAction  = .clear
    public var storeAction: MTLStoreAction = .dontCare
    public var clearDepth:  Double         = 1.0

    public init() {}
}

/// The stencil attachment of a render pass. `texture == nil` means no stencil.
/// For a combined depth/stencil format, point this at the same texture as
/// `depthAttachment`. `clearStencil` is used when `loadAction == .clear`.
public final class MTLRenderPassStencilAttachmentDescriptor {
    public var texture:      MTLTexture?
    public var loadAction:   MTLLoadAction  = .clear
    public var storeAction:  MTLStoreAction = .dontCare
    public var clearStencil: UInt32         = 0

    public init() {}
}

/// Describes the attachments for `commandBuffer.makeRenderCommandEncoder(descriptor:)`.
/// Only `colorAttachments[0]` is supported (single color attachment); optional
/// depth and stencil attachments are supported via `depthAttachment` /
/// `stencilAttachment`.
public final class MTLRenderPassDescriptor {

    public let colorAttachments =
        MTLDescriptorArray { MTLRenderPassColorAttachmentDescriptor() }

    /// Optional depth attachment. Always present; leave its `texture` nil for
    /// depth-less rendering (the previous behaviour).
    public let depthAttachment = MTLRenderPassDepthAttachmentDescriptor()

    /// Optional stencil attachment. Always present; leave its `texture` nil for
    /// stencil-less rendering. With a combined format, set the same texture as
    /// `depthAttachment`.
    public let stencilAttachment = MTLRenderPassStencilAttachmentDescriptor()

    public init() {}
}

/// A 3-D viewport transform. `originY`/`height` follow Metal's top-left-origin,
/// +Y-down framebuffer convention (the encoder converts to a negative-height
/// Vulkan viewport so NDC matches Metal).
public struct MTLViewport {
    public var originX: Double
    public var originY: Double
    public var width:   Double
    public var height:  Double
    public var znear:   Double
    public var zfar:    Double

    public init(originX: Double = 0, originY: Double = 0,
                width: Double, height: Double,
                znear: Double = 0, zfar: Double = 1) {
        self.originX = originX; self.originY = originY
        self.width = width; self.height = height
        self.znear = znear; self.zfar = zfar
    }
}

/// A scissor rectangle in framebuffer pixels (top-left origin).
public struct MTLScissorRect {
    public var x:      Int
    public var y:      Int
    public var width:  Int
    public var height: Int

    public init(x: Int = 0, y: Int = 0, width: Int, height: Int) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// Geometric primitive for draw calls. Pipelines are created with triangle-list
/// topology, so only `.triangle` is currently drawable; `.triangleStrip` requires
/// a strip pipeline and is rejected at draw time.
public enum MTLPrimitiveType {
    case triangle
    case triangleStrip
}

/// Which triangle faces are culled. Set on the render encoder (dynamic state).
public enum MTLCullMode {
    case none
    case front
    case back

    var vkCullMode: VkCullModeFlags {
        switch self {
        case .none:  return UInt32(bitPattern: VK_CULL_MODE_NONE.rawValue)
        case .front: return UInt32(bitPattern: VK_CULL_MODE_FRONT_BIT.rawValue)
        case .back:  return UInt32(bitPattern: VK_CULL_MODE_BACK_BIT.rawValue)
        }
    }
}

/// Winding order that defines a front-facing triangle. Set on the render encoder.
public enum MTLWinding {
    case clockwise
    case counterClockwise

    var vkFrontFace: VkFrontFace {
        switch self {
        case .clockwise:        return VK_FRONT_FACE_CLOCKWISE
        case .counterClockwise: return VK_FRONT_FACE_COUNTER_CLOCKWISE
        }
    }
}
