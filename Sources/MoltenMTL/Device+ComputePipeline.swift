internal import CVulkan


/// Thrown when a compute pipeline cannot be compiled or linked.
public struct MTLComputePipelineError: Error {
    public let message: String
}

public extension MTLDevice {

    /// Creates a compute pipeline by reflecting the SPIR-V bytecode in `function.library` to
    /// determine descriptor bindings automatically.
    /// Prefer `makeComputePipelineState(descriptor:)` if you want to specify bindings explicitly.
    /// - Throws: `MTLComputePipelineError` if reflection or pipeline creation fails.
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

    /// Creates a compute pipeline using explicit binding counts from `descriptor`.
    /// Binding slots are assigned sequentially: storage buffers, acceleration structures,
    /// storage images, then combined image samplers — these must match the
    /// `layout(binding=N)` declarations in your SPIR-V shader.
    /// - Throws: `MTLComputePipelineError` if the function is missing or pipeline creation fails.
    func makeComputePipelineState(descriptor: MTLComputePipelineDescriptor) throws -> MTLComputePipelineState {
        guard let function = descriptor.computeFunction else {
            throw MTLComputePipelineError(message: "MTLComputePipelineDescriptor.computeFunction is nil")
        }
        guard let vkDev     = device,
              let shaderMod = function.library.shaderModule else {
            throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
        }

        let numBuf     = descriptor.storageBufferCount
        let numAS      = descriptor.accelerationStructureCount
        let numImg     = descriptor.storageImageCount
        let numSampled = descriptor.sampledImageCount

        let imgFirst     = numBuf + numAS
        let sampledFirst = imgFirst + numImg

        let bufSlots     = (0..<numBuf).map { UInt32($0) }
        let asSlots      = (numBuf..<imgFirst).map { UInt32($0) }
        let imgSlots     = (imgFirst..<sampledFirst).map { (slot: UInt32($0), count: UInt32(1)) }
        let sampledSlots = (sampledFirst..<sampledFirst + numSampled).map { (slot: UInt32($0), count: UInt32(1)) }

        let bindings = makeLayoutBindings(storageBufferSlots: bufSlots,
                                          asSlots:            asSlots,
                                          imageSlots:         imgSlots,
                                          sampledSlots:       sampledSlots)
        return try buildComputePipeline(device:             vkDev,
                                        shaderModule:       shaderMod,
                                        functionName:       function.name,
                                        bindings:           bindings,
                                        storageBufferCount: numBuf)
    }
}

/// Reflects SPIR-V bytecode to build the binding array.
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
    var imageBindings:         [(slot: UInt32, count: UInt32)] = []
    var sampledBindings:       [(slot: UInt32, count: UInt32)] = []

    for i in 0..<Int(bindingCount) {
        let b = rawBindings[i]
        switch b.descriptorType {
        case UInt32(SPV_BRIDGE_DESCRIPTOR_TYPE_STORAGE_BUFFER):
            storageBufferBindings.append(b.binding)
        case UInt32(SPV_BRIDGE_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR):
            asBindings.append(b.binding)
        case UInt32(SPV_BRIDGE_DESCRIPTOR_TYPE_STORAGE_IMAGE):
            imageBindings.append((slot: b.binding, count: b.count))
        case UInt32(SPV_BRIDGE_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER):
            sampledBindings.append((slot: b.binding, count: b.count))
        default:
            break
        }
    }
    storageBufferBindings.sort()
    asBindings.sort()
    imageBindings.sort   { $0.slot < $1.slot }
    sampledBindings.sort { $0.slot < $1.slot }

    let bindings = makeLayoutBindings(storageBufferSlots: storageBufferBindings,
                                      asSlots:            asBindings,
                                      imageSlots:         imageBindings,
                                      sampledSlots:       sampledBindings)
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

    // Collect per-binding image descriptor counts for pool sizing and array padding.
    let imageBindingCounts: [Int: Int] = Dictionary(
        uniqueKeysWithValues: bindings
            .filter { $0.descriptorType == VK_DESCRIPTOR_TYPE_STORAGE_IMAGE }
            .map    { (Int($0.binding), Int($0.descriptorCount)) })

    // Combined image samplers are tracked separately: they need a sampler attached and
    // want SHADER_READ_ONLY_OPTIMAL rather than the GENERAL layout storage images use.
    let sampledImageBindingCounts: [Int: Int] = Dictionary(
        uniqueKeysWithValues: bindings
            .filter { $0.descriptorType == VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER }
            .map    { (Int($0.binding), Int($0.descriptorCount)) })

    // Descriptor set layout
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
        print("[MoltenMTL] vkCreateDescriptorSetLayout failed")
        throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
    }

    // Pipeline layout
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
        print("[MoltenMTL] vkCreatePipelineLayout failed")
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nil)
        throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
    }

    // Compute pipeline
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
        print("[MoltenMTL] vkCreateComputePipelines failed")
        vkDestroyPipelineLayout(device, pipelineLayout, nil)
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nil)
        throw MTLComputePipelineError(message: "Failed to create compute pipeline state")
    }

    return MTLComputePipelineState(pipeline:            pipeline,
                                   pipelineLayout:      pipelineLayout,
                                   descriptorSetLayout: descriptorSetLayout,
                                   storageBufferCount:  storageBufferCount,
                                   imageBindingCounts:  imageBindingCounts,
                                   sampledImageBindingCounts: sampledImageBindingCounts,
                                   vkDevice:            device)
    }

private func makeLayoutBindings(storageBufferSlots: [UInt32],
                                asSlots:            [UInt32],
                                imageSlots:         [(slot: UInt32, count: UInt32)],
                                sampledSlots:       [(slot: UInt32, count: UInt32)]
) -> [VkDescriptorSetLayoutBinding] {
    let stageFlags = UInt32(bitPattern: VK_SHADER_STAGE_COMPUTE_BIT.rawValue)

    func binding(_ slot: UInt32, _ type: VkDescriptorType, count: UInt32 = 1) -> VkDescriptorSetLayoutBinding {
        var b = VkDescriptorSetLayoutBinding()
        b.binding = slot; b.descriptorType = type
        b.descriptorCount = count; b.stageFlags = stageFlags
        return b
    }

    return storageBufferSlots.map { binding($0, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER) }
         + asSlots.map          { binding($0, VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR) }
         + imageSlots.map       { binding($0.slot, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, count: $0.count) }
         + sampledSlots.map     { binding($0.slot, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, count: $0.count) }
}
