import CVulkan

// MARK: - PixelFormat

/// Mirrors MTLPixelFormat — the format of texels stored in a texture.
public enum MTLPixelFormat {
    case rgba8Unorm       /// 4 bytes/pixel — 8-bit unsigned normalised, RGBA
    case bgra8Unorm       /// 4 bytes/pixel — 8-bit unsigned normalised, BGRA (typical swapchain format)
    case rgba8Unorm_srgb  /// 4 bytes/pixel — 8-bit sRGB, RGBA
    case rgba16Float      /// 8 bytes/pixel — 16-bit float per channel
    case rgba32Float      /// 16 bytes/pixel — 32-bit float per channel
    case r8Unorm          /// 1 byte/pixel  — single 8-bit unsigned normalised channel
    case r8Unorm_srgb     /// 1 byte/pixel  — single 8-bit sRGB channel
    case rg8Unorm         /// 2 bytes/pixel — 8-bit unsigned normalised, RG
    case r16Float         /// 2 bytes/pixel — single 16-bit float channel
    case rg16Float        /// 4 bytes/pixel — 16-bit float, RG
    case r32Float         /// 4 bytes/pixel — single 32-bit float channel
    case rg32Float        /// 8 bytes/pixel — 32-bit float, RG
    case depth32Float     /// 4 bytes/pixel — 32-bit float depth

    // MARK: Internal Vulkan properties

    /// Corresponding `VkFormat`.
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
        case .depth32Float:     return VK_FORMAT_D32_SFLOAT
        }
    }

    /// Vulkan image aspect mask (colour vs. depth).
    var aspectMask: UInt32 {
        switch self {
        case .depth32Float:
            return UInt32(bitPattern: VK_IMAGE_ASPECT_DEPTH_BIT.rawValue)
        default:
            return UInt32(bitPattern: VK_IMAGE_ASPECT_COLOR_BIT.rawValue)
        }
    }

    // MARK: Public Metal-mirrored properties

    /// Size of a single texel in bytes.
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
        case .depth32Float:     return 4
        }
    }
}

// MARK: - TextureUsage

/// Mirrors MTLTextureUsage — how the texture will be accessed by the GPU.
public struct MTLTextureUsage: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Texture can be sampled or read in a shader.
    public static let shaderRead   = MTLTextureUsage(rawValue: 1 << 0)
    /// Texture can be written in a shader (storage image / `image2D`).
    public static let shaderWrite  = MTLTextureUsage(rawValue: 1 << 1)
    /// Texture can serve as a colour or depth/stencil render-target attachment.
    public static let renderTarget = MTLTextureUsage(rawValue: 1 << 2)
}

// MARK: - TextureDescriptor

/// Mirrors MTLTextureDescriptor.
///
/// Describes the properties of a texture before creating it via
/// `device.makeTexture(descriptor:)`.
public final class MTLTextureDescriptor {

    public var pixelFormat:      MTLPixelFormat  = .rgba8Unorm
    public var width:            Int          = 1
    public var height:           Int          = 1
    public var mipmapLevelCount: Int          = 1
    public var usage:            MTLTextureUsage = .shaderRead
    /// Mirrors `MTLTextureDescriptor.storageMode`.
    /// Vulkan images always reside in device-local memory (optimal tiling), so this
    /// property has no effect on the underlying allocation — it exists for API parity.
    public var storageMode:      MTLStorageMode  = .private

    public init() {}

    // MARK: - texture2DDescriptor

    /// Mirrors `MTLTextureDescriptor.texture2DDescriptor(pixelFormat:width:height:mipmapped:)`.
    ///
    /// Builds a descriptor for a 2-D texture.
    /// When `mipmapped` is `true`, `mipmapLevelCount` is set to
    /// `floor(log2(max(width, height))) + 1`.
    public static func texture2DDescriptor(pixelFormat: MTLPixelFormat,
                                           width:       Int,
                                           height:      Int,
                                           mipmapped:   Bool) -> MTLTextureDescriptor {
        let d        = MTLTextureDescriptor()
        d.pixelFormat = pixelFormat
        d.width       = width
        d.height      = height

        if mipmapped {
            // Compute floor(log2(max(w, h))) + 1 via bit-shifting — avoids
            // importing Foundation just for log2().
            var n      = max(width, height)
            var levels = 1
            while n > 1 { n >>= 1; levels += 1 }
            d.mipmapLevelCount = levels
        }

        return d
    }

    // MARK: Internal Vulkan usage flags

    /// `VkImageUsageFlags` derived from the Metal `TextureUsage` and pixel format.
    ///
    /// Always includes `TRANSFER_SRC` and `TRANSFER_DST` so callers can
    /// upload data via `replace(region:mipmapLevel:withBytes:bytesPerRow:)`.
    var vkUsage: UInt32 {
        var flags: UInt32 = 0

        // Transfer flags let the staging-buffer upload path always work.
        flags |= UInt32(bitPattern: VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue)
        flags |= UInt32(bitPattern: VK_IMAGE_USAGE_TRANSFER_SRC_BIT.rawValue)

        if usage.contains(.shaderRead) {
            flags |= UInt32(bitPattern: VK_IMAGE_USAGE_SAMPLED_BIT.rawValue)
        }
        if usage.contains(.shaderWrite) {
            flags |= UInt32(bitPattern: VK_IMAGE_USAGE_STORAGE_BIT.rawValue)
        }
        if usage.contains(.renderTarget) {
            if case .depth32Float = pixelFormat {
                flags |= UInt32(bitPattern: VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT.rawValue)
            } else {
                flags |= UInt32(bitPattern: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue)
            }
        }

        return flags
    }
}
