internal import CVulkan

/// Thrown when a render pipeline cannot be compiled or linked.
public struct MTLRenderPipelineError: Error {
    public let message: String
}

public extension MTLDevice {

    /// Creates a render pipeline from a vertex + fragment function pair by reflecting
    /// both SPIR-V modules to determine descriptor bindings.
    ///
    /// Descriptor convention (deviation from Metal, mirroring the compute path's
    /// "binding N = index N" rule): the vertex stage's resources live in
    /// `set = 0` and the fragment stage's in `set = 1`; within each set the Metal
    /// index maps directly to the GLSL `binding`. Buffers, textures, and samplers
    /// share one binding space per stage.
    /// - Throws: `MTLRenderPipelineError` if reflection or pipeline creation fails.
    func makeRenderPipelineState(descriptor: MTLRenderPipelineDescriptor) throws -> MTLRenderPipelineState {
        guard let vertexFunction = descriptor.vertexFunction else {
            throw MTLRenderPipelineError(message: "MTLRenderPipelineDescriptor.vertexFunction is nil")
        }
        guard let fragmentFunction = descriptor.fragmentFunction else {
            throw MTLRenderPipelineError(message: "MTLRenderPipelineDescriptor.fragmentFunction is nil")
        }
        guard let vkDev   = device,
              let vertMod = vertexFunction.library.shaderModule,
              let fragMod = fragmentFunction.library.shaderModule else {
            throw MTLRenderPipelineError(message: "Failed to create render pipeline state")
        }

        // Reflect both stages into per-set binding maps:
        // bindingTypes[set][binding] = descriptor type, stageFlags[set][binding] = stage mask.
        var bindingTypes: [[UInt32: VkDescriptorType]] = [[:], [:]]
        var stageFlags:   [[UInt32: UInt32]]           = [[:], [:]]

        try collectBindings(of: vertexFunction,
                            stage: UInt32(bitPattern: VK_SHADER_STAGE_VERTEX_BIT.rawValue),
                            into: &bindingTypes, &stageFlags)
        try collectBindings(of: fragmentFunction,
                            stage: UInt32(bitPattern: VK_SHADER_STAGE_FRAGMENT_BIT.rawValue),
                            into: &bindingTypes, &stageFlags)

        // One descriptor set layout per stage set; descriptor-less sets get an
        // empty layout so set indices stay stable in the pipeline layout.
        var setLayouts: [VkDescriptorSetLayout?] = []
        for set in 0..<2 {
            var layoutBindings: [VkDescriptorSetLayoutBinding] = []
            for (binding, type) in bindingTypes[set].sorted(by: { $0.key < $1.key }) {
                var b = VkDescriptorSetLayoutBinding()
                b.binding         = binding
                b.descriptorType  = type
                b.descriptorCount = 1
                b.stageFlags      = stageFlags[set][binding] ?? 0
                layoutBindings.append(b)
            }

            var dsl: VkDescriptorSetLayout?
            layoutBindings.withUnsafeMutableBufferPointer { ptr in
                var dslCI = VkDescriptorSetLayoutCreateInfo()
                dslCI.sType        = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
                dslCI.bindingCount = UInt32(ptr.count)
                dslCI.pBindings    = UnsafePointer(ptr.baseAddress)
                vkCreateDescriptorSetLayout(vkDev, &dslCI, nil, &dsl)
            }
            guard dsl != nil else {
                setLayouts.forEach { if let l = $0 { vkDestroyDescriptorSetLayout(vkDev, l, nil) } }
                throw MTLRenderPipelineError(message: "vkCreateDescriptorSetLayout failed")
            }
            setLayouts.append(dsl)
        }

        func destroySetLayouts() {
            setLayouts.forEach { if let l = $0 { vkDestroyDescriptorSetLayout(vkDev, l, nil) } }
        }

        // Pipeline layout spanning both sets
        var pipelineLayout: VkPipelineLayout?
        setLayouts.withUnsafeMutableBufferPointer { ptr in
            var plCI = VkPipelineLayoutCreateInfo()
            plCI.sType          = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
            plCI.setLayoutCount = UInt32(ptr.count)
            plCI.pSetLayouts    = UnsafePointer(ptr.baseAddress)
            vkCreatePipelineLayout(vkDev, &plCI, nil, &pipelineLayout)
        }
        guard let pl = pipelineLayout else {
            destroySetLayouts()
            throw MTLRenderPipelineError(message: "vkCreatePipelineLayout failed")
        }

        // Vertex input state from the vertex descriptor
        var vkBindings: [VkVertexInputBindingDescription] = []
        var vkAttribs:  [VkVertexInputAttributeDescription] = []
        var vertexBufferBindings: Set<Int> = []

        if let vd = descriptor.vertexDescriptor {
            for index in vd.layouts.definedIndices {
                let layout = vd.layouts[index]
                var b = VkVertexInputBindingDescription()
                b.binding   = UInt32(index)
                b.stride    = UInt32(layout.stride)
                b.inputRate = layout.stepFunction.vkInputRate
                vkBindings.append(b)
                vertexBufferBindings.insert(index)
            }
            for index in vd.attributes.definedIndices {
                let attr = vd.attributes[index]
                var a = VkVertexInputAttributeDescription()
                a.location = UInt32(index)
                a.binding  = UInt32(attr.bufferIndex)
                a.format   = attr.format.vkFormat
                a.offset   = UInt32(attr.offset)
                vkAttribs.append(a)
            }
        }

        let colorAttachment = descriptor.colorAttachments[0]
        var blendState = colorAttachment.vkBlendState
        let depthFormat   = descriptor.depthAttachmentPixelFormat?.vkFormat ?? VK_FORMAT_UNDEFINED
        let stencilFormat = descriptor.stencilAttachmentPixelFormat?.vkFormat ?? VK_FORMAT_UNDEFINED

        var pipeline: VkPipeline?
        let result = vertexFunction.name.withCString { vertEntry in
            fragmentFunction.name.withCString { fragEntry in
                vkBindings.withUnsafeBufferPointer { bindingsPtr in
                    vkAttribs.withUnsafeBufferPointer { attribsPtr in
                        CVKR_createGraphicsPipeline(
                            vkDev,
                            vertMod, vertEntry,
                            fragMod, fragEntry,
                            bindingsPtr.baseAddress, UInt32(bindingsPtr.count),
                            attribsPtr.baseAddress, UInt32(attribsPtr.count),
                            colorAttachment.pixelFormat.vkFormat,
                            depthFormat,
                            stencilFormat,
                            &blendState,
                            pl,
                            &pipeline)
                    }
                }
            }
        }

        guard result == VK_SUCCESS, pipeline != nil else {
            vkDestroyPipelineLayout(vkDev, pl, nil)
            destroySetLayouts()
            throw MTLRenderPipelineError(
                message: "vkCreateGraphicsPipelines failed (VkResult \(result.rawValue))")
        }

        return MTLRenderPipelineState(pipeline:             pipeline,
                                      pipelineLayout:       pl,
                                      setLayouts:           setLayouts,
                                      bindingTypes:         bindingTypes,
                                      vertexBufferBindings: vertexBufferBindings,
                                      vkDevice:             vkDev)
    }
}

/// Reflects one stage's SPIR-V and merges its descriptor bindings into the
/// per-set maps, ORing stage flags when both stages share a (set, binding).
private func collectBindings(of function: MTLFunction,
                             stage: UInt32,
                             into bindingTypes: inout [[UInt32: VkDescriptorType]],
                             _ stageFlags: inout [[UInt32: UInt32]]) throws {
    guard let spirvData = function.library.spirvData else {
        throw MTLRenderPipelineError(message:
            "No SPIR-V data available for reflection of '\(function.name)'")
    }

    var rawBindings = [SPIRVBinding](repeating: SPIRVBinding(), count: 64)
    let bindingCount = rawBindings.withUnsafeMutableBufferPointer { ptr in
        spirvData.withUnsafeBytes { spvPtr in
            spv_get_descriptor_bindings(spvPtr.baseAddress, spirvData.count,
                                        ptr.baseAddress, Int32(64))
        }
    }
    guard bindingCount >= 0 else {
        throw MTLRenderPipelineError(message: "SPIR-V reflection failed for '\(function.name)'")
    }

    for i in 0..<Int(bindingCount) {
        let b = rawBindings[i]
        guard b.set < 2 else {
            throw MTLRenderPipelineError(message:
                "'\(function.name)' uses descriptor set \(b.set) — render pipelines support set 0 (vertex) and set 1 (fragment) only")
        }
        let set  = Int(b.set)
        let type = VkDescriptorType(rawValue: Int32(bitPattern: b.descriptorType))
        if let existing = bindingTypes[set][b.binding], existing != type {
            throw MTLRenderPipelineError(message:
                "Conflicting descriptor types at set \(set), binding \(b.binding)")
        }
        bindingTypes[set][b.binding] = type
        stageFlags[set][b.binding]   = (stageFlags[set][b.binding] ?? 0) | stage
    }
}
