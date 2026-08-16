internal import CVulkan

/// Pixel format for textures and render targets.
/// Each case maps to a specific `VkFormat`.
public enum MTLPixelFormat {
    case rgba8Unorm
    case bgra8Unorm
    case rgba8Unorm_srgb
    case rgba16Float
    case rgba32Float
    case r8Unorm
    case r8Unorm_srgb
    case rg8Unorm
    case r16Float
    case rg16Float
    case r32Float
    case rg32Float
    case depth32Float
    case depth32Float_stencil8

    var vkFormat: VkFormat {
        switch self {
        case .rgba8Unorm:       return VK_FORMAT_R8G8B8A8_UNORM
        case .bgra8Unorm:       return VK_FORMAT_B8G8R8A8_UNORM
        case .rgba8Unorm_srgb:  return VK_FORMAT_R8G8B8A8_SRGB
        case .rgba16Float:      return VK_FORMAT_R16G16B16A16_SFLOAT
        case .rgba32Float:      return VK_FORMAT_R32G32B32A32_SFLOAT
        case .r8Unorm:          return VK_FORMAT_R8_UNORM
        case .r8Unorm_srgb:     return VK_FORMAT_R8_SRGB
        case .rg8Unorm:         return VK_FORMAT_R8G8_UNORM
        case .r16Float:         return VK_FORMAT_R16_SFLOAT
        case .rg16Float:        return VK_FORMAT_R16G16_SFLOAT
        case .r32Float:         return VK_FORMAT_R32_SFLOAT
        case .rg32Float:        return VK_FORMAT_R32G32_SFLOAT
        case .depth32Float:          return VK_FORMAT_D32_SFLOAT
        case .depth32Float_stencil8: return VK_FORMAT_D32_SFLOAT_S8_UINT
        }
    }

    var aspectMask: UInt32 {
        switch self {
        case .depth32Float:
            return UInt32(bitPattern: VK_IMAGE_ASPECT_DEPTH_BIT.rawValue)
        case .depth32Float_stencil8:
            return UInt32(bitPattern: (VK_IMAGE_ASPECT_DEPTH_BIT.rawValue
                                     | VK_IMAGE_ASPECT_STENCIL_BIT.rawValue))
        default:
            return UInt32(bitPattern: VK_IMAGE_ASPECT_COLOR_BIT.rawValue)
        }
    }

    /// True for any depth and/or stencil format — selects the depth/stencil
    /// attachment usage, layout, and barrier stages instead of the colour ones.
    var isDepthStencil: Bool {
        switch self {
        case .depth32Float, .depth32Float_stencil8: return true
        default:                                    return false
        }
    }

    /// True when the format carries a stencil aspect.
    var hasStencil: Bool {
        switch self {
        case .depth32Float_stencil8: return true
        default:                     return false
        }
    }

    public var bytesPerPixel: Int {
        switch self {
        case .rgba8Unorm:       return 4
        case .bgra8Unorm:       return 4
        case .rgba8Unorm_srgb:  return 4
        case .rgba16Float:      return 8
        case .rgba32Float:      return 16
        case .r8Unorm:          return 1
        case .r8Unorm_srgb:     return 1
        case .rg8Unorm:         return 2
        case .r16Float:         return 2
        case .rg16Float:        return 4
        case .r32Float:         return 4
        case .rg32Float:        return 8
        case .depth32Float:          return 4
        case .depth32Float_stencil8: return 8
        }
    }
}

/// Describes how the texture will be accessed by the GPU.
public struct MTLTextureUsage: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Texture can be sampled or read in a shader.
    public static let shaderRead   = MTLTextureUsage(rawValue: 1 << 0)
    /// Texture can be written in a shader (storage image / `image2D`).
    public static let shaderWrite  = MTLTextureUsage(rawValue: 1 << 1)
    /// Texture can serve as a colour or depth/stencil render-target attachment.
    public static let renderTarget = MTLTextureUsage(rawValue: 1 << 2)
}

/// Describes the properties of a texture before creating it via `device.makeTexture(descriptor:)`.
public final class MTLTextureDescriptor {

    public var pixelFormat:      MTLPixelFormat  = .rgba8Unorm
    public var width:            Int          = 1
    public var height:           Int          = 1
    public var mipmapLevelCount: Int          = 1
    public var usage:            MTLTextureUsage = .shaderRead
    /// - Note: Has no effect on the Vulkan allocation. Vulkan images always reside in
    ///   device-local memory (optimal tiling). This property exists for Metal API parity only.
    public var storageMode:      MTLStorageMode  = .private

    public init() {}

    /// Builds a descriptor for a 2-D texture.
    /// When `mipmapped` is `true`, `mipmapLevelCount` is `floor(log2(max(width, height))) + 1`.
    public static func texture2DDescriptor(pixelFormat: MTLPixelFormat,
                                           width:       Int,
                                           height:      Int,
                                           mipmapped:   Bool) -> MTLTextureDescriptor {
        let d        = MTLTextureDescriptor()
        d.pixelFormat = pixelFormat
        d.width       = width
        d.height      = height

        if mipmapped {
            // Avoids importing Foundation just for log2().
            var n      = max(width, height)
            var levels = 1
            while n > 1 { n >>= 1; levels += 1 }
            d.mipmapLevelCount = levels
        }

        return d
    }

    /// Always includes `TRANSFER_SRC`/`TRANSFER_DST` so the staging-buffer upload path always works.
    var vkUsage: UInt32 {
        var flags: UInt32 = 0

        flags |= UInt32(bitPattern: VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue)
        flags |= UInt32(bitPattern: VK_IMAGE_USAGE_TRANSFER_SRC_BIT.rawValue)

        if usage.contains(.shaderRead) {
            flags |= UInt32(bitPattern: VK_IMAGE_USAGE_SAMPLED_BIT.rawValue)
        }
        if usage.contains(.shaderWrite) {
            flags |= UInt32(bitPattern: VK_IMAGE_USAGE_STORAGE_BIT.rawValue)
        }
        if usage.contains(.renderTarget) {
            if pixelFormat.isDepthStencil {
                flags |= UInt32(bitPattern: VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT.rawValue)
            } else {
                flags |= UInt32(bitPattern: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue)
            }
        }

        return flags
    }
}
