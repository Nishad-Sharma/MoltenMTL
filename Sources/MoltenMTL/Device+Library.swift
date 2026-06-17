internal import CVulkan
import Foundation

public extension MTLDevice {

    /// Loads a SPIR-V shader module from a `.spv` file at `url`.
    /// The raw SPIR-V bytes are retained so that binding reflection is available via
    /// `makeComputePipelineState(function:)`.
    /// - Returns: A new `MTLLibrary`, or `nil` if the file cannot be read or the module is invalid.
    func makeLibrary(url: URL) -> MTLLibrary? {
        guard let vkDev = device else { return nil }

        guard let data = try? Data(contentsOf: url) else {
            print("[MoltenMTL] Failed to read SPIR-V from \(url.path)")
            return nil
        }

        // must point to uint32_t-aligned data; Data is heap-allocated and
        // at least 4-byte aligned, so binding directly is safe.
        guard !data.isEmpty, data.count % 4 == 0 else {
            print("[MoltenMTL] SPIR-V size (\(data.count) bytes) must be a non-zero multiple of 4")
            return nil
        }

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
            print("[MoltenMTL] vkCreateShaderModule failed (VkResult \(createResult.rawValue))")
            return nil
        }

        return MTLLibrary(shaderModule: shaderModule, spirvData: data, vkDevice: vkDev)
    }

    /// Convenience wrapper for `makeLibrary(url:)` that takes a file-system path string.
    func makeLibrary(path: String) -> MTLLibrary? {
        makeLibrary(url: URL(fileURLWithPath: path))
    }
}
