internal import CVulkan
import Foundation

/// Wraps a compiled `VkShaderModule` (loaded from a SPIR-V `.spv` file).
/// Create via `device.makeLibrary(url:)` — never instantiate directly.
public final class MTLLibrary {

    let shaderModule: VkShaderModule?
    let spirvData: Data?

    private let vkDevice: VkDevice?

    init(shaderModule: VkShaderModule?, spirvData: Data?, vkDevice: VkDevice?) {
        self.shaderModule = shaderModule
        self.spirvData    = spirvData
        self.vkDevice     = vkDevice
    }

    deinit {
        if let dev = vkDevice, let mod = shaderModule {
            vkDestroyShaderModule(dev, mod, nil)
        }
    }

    /// Returns an `MTLFunction` for the entry point named `name` in this shader module.
    /// - Returns: An `MTLFunction`, or `nil` if `name` is empty (the name is not validated
    ///   against the SPIR-V until pipeline creation).
    public func makeFunction(name: String) -> MTLFunction? {
        MTLFunction(name: name, library: self)
    }
}

/// A named entry point within an `MTLLibrary` shader module.
/// Create via `library.makeFunction(name:)` — never instantiate directly.
public final class MTLFunction {

    public let name: String

    /// The parent library - keeps `VkShaderModule` alive for as long as this
    /// function is referenced.
    public let library: MTLLibrary


    init(name: String, library: MTLLibrary) {
        self.name    = name
        self.library = library
    }

    /// Returns a compatibility stub. Argument encoders are no-ops on Vulkan — see `MTLArgumentEncoder`.
    public func makeArgumentEncoder(bufferIndex: Int) -> MTLArgumentEncoder {
        return MTLArgumentEncoder()
    }
}

/// Compatibility stub for Metal's `MTLArgumentEncoder`.
///
/// Vulkan uses descriptor sets for resource binding rather than argument buffers, so most
/// methods on this type are no-ops. The type exists so Metal source code that uses argument
/// encoders compiles unchanged.
public final class MTLArgumentEncoder {
    public var encodedLength: Int = 0
    public private(set) var storedTextures: [MTLTexture?] = []

    /// - Note: **No-op on Vulkan.** Vulkan uses descriptor sets rather than argument buffers.
    ///   This method exists for Metal API source compatibility only.
    public func setArgumentBuffer(_ buffer: MTLBuffer?, offset: Int = 0) {
        // no-op: Vulkan uses descriptor sets, not argument buffers
    }

    /// Stores `textures` so they can be accessed later via `storedTextures`.
    /// These are not automatically bound to any shader slot — pass them via `setTextures(_:index:)` on the encoder.
    public func setTextures(_ textures: [MTLTexture?], range: Range<Int>) {
        storedTextures = Array(textures[range])
    }
}
