import CVulkan

// MARK: - Pipeline creation error

/// Error thrown by the `makeComputePipelineState` overloads.
public struct MTLComputePipelineError: Error {
    public let message: String
}

public extension MTLDevice {

    // MARK: Simple overload — matches Metal's API exactly

    /// Creates a compute pipeline state using SPIR-V reflection to discover
    /// the descriptor layout automatically.
    ///
    /// This overload mirrors the real `MTLDevice.makeComputePipelineSt    /// signature. The library must have been created via `makeLibrary(url:)` so that
    /// SPIR-V bytes are available for reflection.
    func makeComputePipelineState(function: MTLFunction) throws -> MTLComputePipelineState {
        guard let vkDev     = device,
              let shaderMod = function.library.shaderModule else {
            throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
        }

        let (bindings, storageBufferCount) = try reflectBindings(function: function)
        return try buildComputePipeline(device:             vkDev,
                                        shaderModule:       shaderMod,
                                        functionName:       function.name,
                                        bindings:           bindings,
                                        storageBufferCount: storageBufferCount)
    }

    // MARK: Descriptor overload — explicit binding counts, zero reflection overhead

    /// Creates a compute pipeline state from a fully-configured descriptor.
    ///
    /// Builds the `VkDescriptorSetLayout` directly from the counts on the descriptor —
    /// no SPIR-V reflection is performed. You must keep the counts in sync with your
    /// GLSL `layout(binding=N)` declarations.
    func makeComputePipelineState(descriptor: MTLComputePipelineDescriptor) throws -> MTLComputePipelineState {
        guard let function = descriptor.computeFunction else {
            throw MTLComputePipelineError(message: "MTLComputePipelineDescriptor.computeFunction is nil")
        }
        guard let vkDev     = device,
              let shaderMod = function.library.shaderModule else {
            throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
        }

        let numBuf = descriptor.storageBufferCount
        let numAS  = descriptor.accelerationStructureCount
        let numImg = descriptor.storageImageCount

        let bufSlots = (0..<numBuf).map { UInt32($0) }
        let asSlots  = (numBuf..<numBuf + numAS).map { UInt32($0) }
        let imgSlots = (numBuf + numAS..<numBuf + numAS + numImg).map { UInt32($0) }

        let bindings = makeLayoutBindings(storageBufferSlots: bufSlots,
                                          asSlots:            asSlots,
                                          imageSlots:         imgSlots)
        return try buildComputePipeline(device:             vkDev,
                                        shaderModule:       shaderMod,
                                        functionName:       function.name,
                                        bindings:           bindings,
                                        storageBufferCount: numBuf)
    }
}

// MARK: - Private helpers

/// Reflects SPIR-V bytecode to produce the binding array and storage-buffer count.
private func reflectBindings(
    function: MTLFunction
) throws -> (bindings: [VkDescriptorSetLayoutBinding], storageBufferCount: Int) {
    guard let spirvData = function.library.spirvData else {
        throw MTLComputePipelineError(message:
            "No SPIR-V data available for reflection — use makeComputePipelineState(descriptor:) instead")
    }

    var rawBindings = [SPIRVBinding](repeating: SPIRVBinding(), count: 64)
    let bindingCount = rawBindings.withUnsafeMutableBufferPointer { ptr in
        spirvData.withUnsafeBytes { spvPtr in
            spv_get_descriptor_bindings(spvPtr.baseAddress, spirvData.count,
                                        ptr.baseAddress, Int32(64))
        }
    }
    guard bindingCount >= 0 else {
        throw MTLComputePipelineError(message: "SPIR-V reflection failed")
    }

    var storageBufferBindings: [UInt32] = []
    var asBindings:            [UInt32] = []
    var imageBindings:         [UInt32] = []

    for i in 0..<Int(bindingCount) {
        let b = rawBindings[i]
        switch b.descriptorType {
        case UInt32(SPV_BRIDGE_DESCRIPTOR_TYPE_STORAGE_BUFFER):
            storageBufferBindings.append(b.binding)
        case UInt32(SPV_BRIDGE_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR):
            asBindings.append(b.binding)
        case UInt32(SPV_BRIDGE_DESCRIPTOR_TYPE_STORAGE_IMAGE):
            imageBindings.append(b.binding)
        default:
            break
        }
    }
    storageBufferBindings.sort()
    asBindings.sort()
    imageBindings.sort()

    let bindings = makeLayoutBindings(storageBufferSlots: storageBufferBindings,
                                      asSlots:            asBindings,
                                      imageSlots:         imageBindings)
    return (bindings, storageBufferBindings.count)
}

/// Shared Vulkan pipeline creation: descriptor set layout → pipeline layout → compute pipeline.
private func buildComputePipeline(
    device:             VkDevice,
    shaderModule:       VkShaderModule,
    functionName:       String,
    bindings:           [VkDescriptorSetLayoutBinding],
    storageBufferCount: Int
) throws -> MTLComputePipelineState {

    // ── 1. Descriptor set layout ───────────────────────────────────────────
    var descriptorSetLayout: VkDescriptorSetLayout?
    var mutableBindings = bindings
    mutableBindings.withUnsafeMutableBufferPointer { ptr in
        var dslCI = VkDescriptorSetLayoutCreateInfo()
        dslCI.sType        = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
        dslCI.bindingCount = UInt32(bindings.count)
        dslCI.pBindings    = UnsafePointer(ptr.baseAddress)
        vkCreateDescriptorSetLayout(device, &dslCI, nil, &descriptorSetLayout)
    }

    guard descriptorSetLayout != nil else {
        print("[VulkanSwift] vkCreateDescriptorSetLayout failed")
        throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
    }

    // ── 2. Pipeline layout ─────────────────────────────────────────────────
    var pipelineLayout: VkPipelineLayout?
    var dsl = descriptorSetLayout
    withUnsafePointer(to: &dsl) { dslPtr in
        var plCI = VkPipelineLayoutCreateInfo()
        plCI.sType          = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        plCI.setLayoutCount = 1
        plCI.pSetLayouts    = dslPtr
        vkCreatePipelineLayout(device, &plCI, nil, &pipelineLayout)
    }

    guard pipelineLayout != nil else {
        print("[VulkanSwift] vkCreatePipelineLayout failed")
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nil)
        throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
    }

    // ── 3. Compute pipeline ────────────────────────────────────────────────
    var pipeline: VkPipeline?
    functionName.withCString { namePtr in
        var stageCI = VkPipelineShaderStageCreateInfo()
        stageCI.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
        stageCI.stage  = VK_SHADER_STAGE_COMPUTE_BIT
        stageCI.module = shaderModule
        stageCI.pName  = namePtr

        var pipelineCI = VkComputePipelineCreateInfo()
        pipelineCI.sType  = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO
        pipelineCI.stage  = stageCI
        pipelineCI.layout = pipelineLayout!

        vkCreateComputePipelines(device, nil, 1, &pipelineCI, nil, &pipeline)
    }

    guard pipeline != nil else {
        print("[VulkanSwift] vkCreateComputePipelines failed")
        vkDestroyPipelineLayout(device, pipelineLayout, nil)
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nil)
        throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
    }

    return MTLComputePipelineState(pipeline:            pipeline,
                                   pipelineLayout:      pipelineLayout,
                                   descriptorSetLayout: descriptorSetLayout,
                                   storageBufferCount:  storageBufferCount,
                                   vkDevice:            device)
    }

/// Builds a flat `[VkDescriptorSetLayoutBinding]` from three pre-sorted slot arrays.
private func makeLayoutBindings(storageBufferSlots: [UInt32],
                                asSlots:            [UInt32],
                                imageSlots:         [UInt32]) -> [VkDescriptorSetLayoutBinding] {
    let stageFlags = UInt32(bitPattern: VK_SHADER_STAGE_COMPUTE_BIT.rawValue)

    func binding(_ slot: UInt32, _ type: VkDescriptorType) -> VkDescriptorSetLayoutBinding {
        var b = VkDescriptorSetLayoutBinding()
        b.binding = slot; b.descriptorType = type
        b.descriptorCount = 1; b.stageFlags = stageFlags
        return b
    }

    return storageBufferSlots.map { binding($0, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER) }
         + asSlots.map          { binding($0, VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR) }
         + imageSlots.map       { binding($0, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE) }
}
