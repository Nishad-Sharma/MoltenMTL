internal import CVulkan

/// Filtering mode for minification/magnification.
public enum MTLSamplerMinMagFilter {
    case nearest
    case linear

    var vkFilter: VkFilter {
        switch self {
        case .nearest: return VK_FILTER_NEAREST
        case .linear:  return VK_FILTER_LINEAR
        }
    }
}

/// Filtering mode between mip levels.
public enum MTLSamplerMipFilter {
    case notMipmapped
    case nearest
    case linear

    var vkMipmapMode: VkSamplerMipmapMode {
        switch self {
        case .notMipmapped, .nearest: return VK_SAMPLER_MIPMAP_MODE_NEAREST
        case .linear:                 return VK_SAMPLER_MIPMAP_MODE_LINEAR
        }
    }
}

/// Behaviour for texture coordinates outside [0, 1].
public enum MTLSamplerAddressMode {
    case clampToEdge
    case `repeat`
    case mirrorRepeat
    case clampToZero

    var vkAddressMode: VkSamplerAddressMode {
        switch self {
        case .clampToEdge:  return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        case .repeat:       return VK_SAMPLER_ADDRESS_MODE_REPEAT
        case .mirrorRepeat: return VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT
        case .clampToZero:  return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER
        }
    }
}

/// Describes a sampler before creating it via `device.makeSamplerState(descriptor:)`.
public final class MTLSamplerDescriptor {

    public var minFilter:    MTLSamplerMinMagFilter = .nearest
    public var magFilter:    MTLSamplerMinMagFilter = .nearest
    public var mipFilter:    MTLSamplerMipFilter    = .notMipmapped
    public var sAddressMode: MTLSamplerAddressMode  = .clampToEdge
    public var tAddressMode: MTLSamplerAddressMode  = .clampToEdge
    public var normalizedCoordinates: Bool = true

    public init() {}
}

/// Wraps a `VkSampler`. Create via `device.makeSamplerState(descriptor:)` - never directly.
public final class MTLSamplerState {

    let sampler: VkSampler?

    private let vkDevice: VkDevice?

    init(sampler: VkSampler?, vkDevice: VkDevice?) {
        self.sampler  = sampler
        self.vkDevice = vkDevice
    }

    deinit {
        if let dev = vkDevice, let s = sampler { vkDestroySampler(dev, s, nil) }
    }
}

public extension MTLDevice {

    /// Creates a sampler for use with `setFragmentSamplerState(_:index:)`.
    func makeSamplerState(descriptor: MTLSamplerDescriptor) -> MTLSamplerState? {
        guard let dev = device else {
            print("[MoltenMTL] makeSamplerState: device is nil")
            return nil
        }

        var ci = VkSamplerCreateInfo()
        ci.sType            = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO
        ci.minFilter        = descriptor.minFilter.vkFilter
        ci.magFilter        = descriptor.magFilter.vkFilter
        ci.mipmapMode       = descriptor.mipFilter.vkMipmapMode
        ci.addressModeU     = descriptor.sAddressMode.vkAddressMode
        ci.addressModeV     = descriptor.tAddressMode.vkAddressMode
        ci.addressModeW     = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        ci.borderColor      = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK
        ci.maxLod           = descriptor.mipFilter == .notMipmapped ? 0.25 : 1000.0 // VK_LOD_CLAMP_NONE
        ci.unnormalizedCoordinates = descriptor.normalizedCoordinates ? VK_FALSE : VK_TRUE

        var sampler: VkSampler? = nil
        let result = vkCreateSampler(dev, &ci, nil, &sampler)
        guard result == VK_SUCCESS, sampler != nil else {
            print("[MoltenMTL] vkCreateSampler failed (VkResult \(result.rawValue))")
            return nil
        }

        return MTLSamplerState(sampler: sampler, vkDevice: dev)
    }

    /// The sampler used for combined-image-sampler bindings that have no explicit sampler bound.
    internal var defaultSampler: MTLSamplerState? {
        if let existing = _defaultSampler { return existing }
        let created = makeSamplerState(descriptor: MTLSamplerDescriptor())
        _defaultSampler = created
        return created
    }

    /// A cached 1×1 opaque-white texture with `usage`, used to fill descriptor
    /// slots a shader declares but the caller left unbound.
    ///
    /// Cached because `MTLTexture.replace` submits and waits on the queue: built
    /// per dispatch, it would stall the GPU on every dispatch.
    internal func dummyTexture(usage: MTLTextureUsage) -> MTLTexture? {
        if let existing = _dummyTextures[usage] { return existing }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        desc.usage = usage
        guard let texture = makeTexture(descriptor: desc) else { return nil }
        texture.replace(region: .make2D(width: 1, height: 1), mipmapLevel: 0,
                        withBytes: [UInt8](repeating: 255, count: 4), bytesPerRow: 4)
        _dummyTextures[usage] = texture
        return texture
    }
}
