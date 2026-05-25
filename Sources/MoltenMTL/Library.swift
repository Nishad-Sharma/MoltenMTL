import CVulkan
import Foundation

// MARK: - Library

/// Mirrors MTLLibrary.
///
/// Wraps a compiled `VkShaderModule` (loaded from a SPIR-V `.spv` file).
/// Create via `device.makeLibrary(url:)` — never instantiate directly.
public final class MTLLibrary {

    // MARK: Internal Vulkan handle

    /// Raw VkShaderModule — used when building compute/render pipeline states.
    let shaderModule: VkShaderModule?

    /// SPIR-V bytecode retained for descriptor-binding reflection at pipeline creation.
    let spirvData: Data?

    /// Logical device — retained so deinit can destroy the module.
    private let vkDevice: VkDevice?

    // MARK: Init / deinit

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

    // MARK: - makeFunction

    /// Mirrors `MTLLibrary.makeFunction(name:)`.
    ///
    /// Returns an `MTLFunction` identifying the named entry point in this module.
    /// The name is validated by Vulkan at pipeline-creation time, not here.
    public func makeFunction(name: String) -> MTLFunction? {
        MTLFunction(name: name, library: self)
    }
}

// MARK: - MTLFunction

/// Mirrors MTLFunction.
///
/// Pairs an entry-point name with the `MTLLibrary` (VkShaderModule) that contains it.
/// Used when building an `MTLComputePipelineState`.
public final class MTLFunction {

    // MARK: Public properties

    /// The SPIR-V entry-point name (e.g. `"main"`).
    public let name: String

    /// The parent library — keeps `VkShaderModule` alive for as long as this
    /// function is referenced.
    public let library: MTLLibrary

    // MARK: Init (internal)

    init(name: String, library: MTLLibrary) {
        self.name    = name
        self.library = library
    }

    public func makeArgumentEncoder(bufferIndex: Int) -> MTLArgumentEncoder {
        return MTLArgumentEncoder()
    }
}

public final class MTLArgumentEncoder {
    public var encodedLength: Int = 0
    public private(set) var storedTextures: [MTLTexture?] = []

    public func setArgumentBuffer(_ buffer: MTLBuffer?, offset: Int = 0) {
        // no-op: Vulkan uses descriptor sets, not argument buffers
    }

    public func setTextures(_ textures: [MTLTexture?], range: Range<Int>) {
        storedTextures = Array(textures[range])
    }
}