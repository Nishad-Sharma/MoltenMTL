import CVulkan
import Foundation

public extension MTLDevice {

    // MARK: - makeLibrary (URL)

    /// Mirrors `MTLDevice.makeLibrary(URL:error:)`.
    ///
    /// Loads a compiled SPIR-V file and creates a `VkShaderModule` from it.
    /// The file must contain valid SPIR-V bytecode (size must be a multiple of 4).
    func makeLibrary(url: URL) -> MTLLibrary? {
        guard let vkDev = device else { return nil }

        // ── Load bytes ─────────────────────────────────────────────────────────
        guard let data = try? Data(contentsOf: url) else {
            print("[VulkanSwift] Failed to read SPIR-V from \(url.path)")
            return nil
        }

        guard !data.isEmpty, data.count % 4 == 0 else {
            print("[VulkanSwift] SPIR-V size (\(data.count) bytes) must be a non-zero multiple of 4")
            return nil
        }

        // ── VkShaderModule ─────────────────────────────────────────────────────
        // pCode must point to uint32_t-aligned data; Data is heap-allocated and
        // at least 4-byte aligned, so binding directly is safe.
        var shaderModule: VkShaderModule?
        var createResult: VkResult = VK_SUCCESS

        data.withUnsafeBytes { rawPtr in
            guard let codePtr = rawPtr.bindMemory(to: UInt32.self).baseAddress else {
                createResult = VK_ERROR_UNKNOWN
                return
            }
            var moduleCI = VkShaderModuleCreateInfo()
            moduleCI.sType    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
            moduleCI.codeSize = data.count          // size_t → Int
            moduleCI.pCode    = codePtr             // const uint32_t*
            createResult = vkCreateShaderModule(vkDev, &moduleCI, nil, &shaderModule)
        }

        guard createResult == VK_SUCCESS else {
            print("[VulkanSwift] vkCreateShaderModule failed (VkResult \(createResult.rawValue))")
            return nil
        }

        return MTLLibrary(shaderModule: shaderModule, spirvData: data, vkDevice: vkDev)
    }

    // MARK: - makeLibrary (path)

    /// Convenience overload — mirrors `MTLDevice.makeLibrary(filepath:error:)`.
    func makeLibrary(path: String) -> MTLLibrary? {
        makeLibrary(url: URL(fileURLWithPath: path))
    }
}
