import CVulkan
import Foundation

/// Wraps a compiled `VkShaderModule` (loaded from a SPIR-V `.spv` file).
/// Create via `device.makeLibrary(url:)` â€” never instantiate directly.
public final class MTLLibrary {

    let shaderModule: VkShaderModule?

    /// SPIR-V bytecode retained for descriptor-binding reflection at pipeline creation.
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

    /// Returns an `MTLFunction` for the named entry point.
    /// The name is validated by Vulkan at pipeline-creation time, not here.
    public func makeFunction(name: String) -> MTLFunction? {
        MTLFunction(name: name, library: self)
    }
}

/// Pairs an entry-point name with its `MTLLibrary` (VkShaderModule).
public final class MTLFunction {

    public let name: String

    /// The parent library â€” keeps `VkShaderModule` alive for as long as this
    /// function is referenced.
    public let library: MTLLibrary


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
