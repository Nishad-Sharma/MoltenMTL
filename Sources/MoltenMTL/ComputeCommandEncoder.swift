internal import CVulkan

/// Records compute commands into the parent `CommandBuffer`.
/// Create via `commandBuffer.makeComputeCommandEncoder()`.
public final class MTLComputeCommandEncoder {

    /// Used by GPU debuggers.
    public var label: String?

    private let commandBuffer: MTLCommandBuffer
    private var pipeline:      MTLComputePipelineState?

    private var boundBuffers: [Int: (buffer: MTLBuffer, offset: Int)] = [:]
    private var boundAccelerationStructures: [Int: MTLAccelerationStructure] = [:]
    private var boundTextureSets: [Int: [MTLTexture]] = [:]

    private var isEnded = false

    init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
    }

    /// Sets the compute pipeline that subsequent `dispatchThreadgroups` calls will use.
    public func setComputePipelineState(_ pipeline: MTLComputePipelineState) {
        self.pipeline = pipeline
    }

    /// Mirrors `MTLComputeCommandEncoder.setBuffer(_:offset:index:)`.
    /// Binds `buffer` to the storage-buffer descriptor slot at `index`.
    public func setBuffer(_ buffer: MTLBuffer?, offset: Int = 0, index: Int) {
        if let buffer = buffer {
            boundBuffers[index] = (buffer: buffer, offset: offset)
        } else {
            print("[MoltenMTL] setBuffer: nil buffer for index \(index) — binding unchanged")
        }
    }

    /// Binds an array of textures to the storage-image slot at `index`.
    public func setTextures(_ textures: [MTLTexture], index: Int = 0) {
        boundTextureSets[index] = textures
    }

    /// Binds a single texture to the storage-image slot at `index`.
    public func setTexture(_ texture: MTLTexture, index: Int) {
        setTextures([texture], index: index)
    }

    /// Binds `accelerationStructure` to the AS descriptor slot at `bufferIndex`.
    public func setAccelerationStructure(_ accelerationStructure: MTLAccelerationStructure,
                                         bufferIndex: Int) {
        boundAccelerationStructures[bufferIndex] = accelerationStructure
    }

    /// Convenience for small per-dispatch constants: copies bytes into a transient shared buffer and binds it.
    public func setBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
        guard let buf = commandBuffer.commandQueue.device
                .makeBuffer(length: max(length, 4), options: .shared) else { return }
        buf.contents().copyMemory(from: bytes, byteCount: length)
        setBuffer(buf, offset: 0, index: index)
    }

    /// - Note: **No-op on Vulkan.** Vulkan manages resource residency automatically through
    ///   descriptor bindings. This method exists for Metal API source compatibility only.
    public func useResource(_ resource: AnyObject, usage: MTLResourceUsage) { }

    /// - Note: **No-op on Vulkan.** Heap residency is managed automatically. This method exists
    ///   for Metal API source compatibility only.
    public func useHeap(_ heap: MTLHeap) { }

    /// Encodes a compute dispatch of `threadgroupsPerGrid` threadgroups, each of size `threadsPerThreadgroup`.
    /// Writes all bound descriptors (buffers, acceleration structures, textures) to a transient
    /// `VkDescriptorSet` before issuing `vkCmdDispatch`.
    public func dispatchThreadgroups(_ threadgroupsPerGrid: MTLSize,
                                     threadsPerThreadgroup: MTLSize) {
        guard !isEnded else {
            print("[MoltenMTL] dispatchThreadgroups called after endEncoding"); return
        }
        guard let pso        = pipeline,
              let vkPipeline = pso.pipeline,
              let vkLayout   = pso.pipelineLayout,
              let dev         = commandBuffer.commandQueue.vkDevice else {
            print("[MoltenMTL] dispatchThreadgroups: pipeline or device not set"); return
        }

        let cmd = commandBuffer.handle

        // Bind compute pipeline
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, vkPipeline)

        // Descriptor set
        let sortedBuffers = boundBuffers.sorted              { $0.key < $1.key }
        let sortedAS      = boundAccelerationStructures.sorted { $0.key < $1.key }

        // Build effective texture sets: pad each declared image binding to its layout count
        // with a 1×1 dummy texture so all declared descriptor slots are written.
        var effectiveTextureSets: [(key: Int, value: [MTLTexture])] = []
        if !pso.imageBindingCounts.isEmpty {
            let mtlDevice = commandBuffer.commandQueue.device
            let dummyDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
            dummyDesc.usage = [.shaderRead, .shaderWrite]
            if let dummy = mtlDevice.makeTexture(descriptor: dummyDesc) {
                dummy.replace(region: .make2D(width: 1, height: 1), mipmapLevel: 0,
                              withBytes: [UInt8](repeating: 255, count: 4), bytesPerRow: 4)
                commandBuffer.ownedTextures.append(dummy)
                for (slot, count) in pso.imageBindingCounts.sorted(by: { $0.key < $1.key }) {
                    let bound = boundTextureSets[slot] ?? []
                    let padded = bound + Array(repeating: dummy, count: max(0, count - bound.count))
                    effectiveTextureSets.append((key: slot, value: padded))
                }
            }
        } else {
            effectiveTextureSets = boundTextureSets.sorted { $0.key < $1.key }
        }

        let needsDescriptors = !sortedBuffers.isEmpty || !sortedAS.isEmpty || !effectiveTextureSets.isEmpty
        if needsDescriptors, let dsl = pso.descriptorSetLayout {

            // Pool
            var poolSizes: [VkDescriptorPoolSize] = []
            if !sortedBuffers.isEmpty {
                var ps = VkDescriptorPoolSize()
                ps.type            = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
                // Pool must cover all declared layout slots, not just bound ones.
                ps.descriptorCount = UInt32(pso.storageBufferCount)
                poolSizes.append(ps)
            }
            if !sortedAS.isEmpty {
                var ps = VkDescriptorPoolSize()
                ps.type            = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR
                ps.descriptorCount = UInt32(sortedAS.count)
                poolSizes.append(ps)
            }
            if !effectiveTextureSets.isEmpty {
                var ps = VkDescriptorPoolSize()
                ps.type            = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE
                // Use declared counts (from layout), not bound count, to size correctly.
                ps.descriptorCount = UInt32(effectiveTextureSets.map { $0.value.count }.reduce(0, +))
                poolSizes.append(ps)
            }

            var pool: VkDescriptorPool?
            poolSizes.withUnsafeBufferPointer { psPtr in
                var poolCI = VkDescriptorPoolCreateInfo()
                poolCI.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
                poolCI.maxSets       = 1
                poolCI.poolSizeCount = UInt32(poolSizes.count)
                poolCI.pPoolSizes    = psPtr.baseAddress
                vkCreateDescriptorPool(dev, &poolCI, nil, &pool)
            }
            guard pool != nil else {
                print("[MoltenMTL] vkCreateDescriptorPool failed"); return
            }
            commandBuffer.ownedPools.append(pool)

            // Allocate descriptor set
            var descriptorSet: VkDescriptorSet?
            var dslCopy: VkDescriptorSetLayout? = dsl
            withUnsafePointer(to: &dslCopy) { dslPtr in
                var allocInfo = VkDescriptorSetAllocateInfo()
                allocInfo.sType              = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
                allocInfo.descriptorPool     = pool!
                allocInfo.descriptorSetCount = 1
                allocInfo.pSetLayouts        = dslPtr
                vkAllocateDescriptorSets(dev, &allocInfo, &descriptorSet)
            }
            guard let descSet = descriptorSet else {
                print("[MoltenMTL] vkAllocateDescriptorSets failed"); return
            }

            // Write buffer descriptors
            if !sortedBuffers.isEmpty {
                var bufferInfos: [VkDescriptorBufferInfo] = sortedBuffers.map { _, binding in
                    var info = VkDescriptorBufferInfo()
                    info.buffer = binding.buffer.handle
                    info.offset = VkDeviceSize(binding.offset)
                    info.range  = UInt64.max    // VK_WHOLE_SIZE
                    return info
                }

                bufferInfos.withUnsafeMutableBufferPointer { infosPtr in
                    let writes: [VkWriteDescriptorSet] = sortedBuffers.enumerated().map { i, kv in
                        var w = VkWriteDescriptorSet()
                        w.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
                        w.dstSet          = descSet
                        w.dstBinding      = UInt32(kv.key)
                        w.descriptorCount = 1
                        w.descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
                        w.pBufferInfo     = UnsafePointer(infosPtr.baseAddress).map { $0 + i }
                        return w
                    }
                    writes.withUnsafeBufferPointer { writesPtr in
                        vkUpdateDescriptorSets(dev, UInt32(writes.count),
                                               writesPtr.baseAddress, 0, nil)
                    }
                }
            }

            // Write acceleration structure descriptors
            // Each AS write uses pNext → VkWriteDescriptorSetAccelerationStructureKHR.
            // Written one at a time to keep the pointer lifetimes trivial.
            for (bindingIndex, asStruct) in sortedAS {
                var handle: VkAccelerationStructureKHR? = asStruct.handle
                withUnsafePointer(to: &handle) { handlePtr in
                    var asWriteInfo = VkWriteDescriptorSetAccelerationStructureKHR()
                    asWriteInfo.sType                      = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_ACCELERATION_STRUCTURE_KHR
                    asWriteInfo.accelerationStructureCount = 1
                    asWriteInfo.pAccelerationStructures    = handlePtr
                    withUnsafePointer(to: &asWriteInfo) { wiPtr in
                        var w = VkWriteDescriptorSet()
                        w.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
                        w.pNext           = UnsafeRawPointer(wiPtr)
                        w.dstSet          = descSet
                        w.dstBinding      = UInt32(bindingIndex)
                        w.descriptorCount = 1
                        w.descriptorType  = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR
                        vkUpdateDescriptorSets(dev, 1, &w, 0, nil)
                    }
                }
            }

            // Write storage-image descriptors (effectiveTextureSets is already padded to declared count)
            if !effectiveTextureSets.isEmpty {
                for (bindingIndex, textures) in effectiveTextureSets {
                    var imageInfos: [VkDescriptorImageInfo] = textures.compactMap { tex in
                        guard let view = tex.imageView else { return nil }
                        var info = VkDescriptorImageInfo()
                        info.sampler     = nil
                        info.imageView   = view
                        info.imageLayout = VK_IMAGE_LAYOUT_GENERAL
                        return info
                    }
                    guard !imageInfos.isEmpty else { continue }

                    let imageCount = imageInfos.count
                    imageInfos.withUnsafeMutableBufferPointer { infosPtr in
                        var w = VkWriteDescriptorSet()
                        w.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
                        w.dstSet          = descSet
                        w.dstBinding      = UInt32(bindingIndex)
                        w.dstArrayElement = 0
                        w.descriptorCount = UInt32(imageCount)
                        w.descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE
                        w.pImageInfo      = UnsafePointer(infosPtr.baseAddress)
                        vkUpdateDescriptorSets(dev, 1, &w, 0, nil)
                    }
                }
            }

            // Bind descriptor set
            var setToBind: VkDescriptorSet? = descSet
            withUnsafePointer(to: &setToBind) { setPtr in
                vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE,
                                        vkLayout, 0, 1, setPtr, 0, nil)
            }
        }

        // Transition storage images to GENERAL (if not already there)
        for (_, textures) in effectiveTextureSets {
            for tex in textures {
                guard let img = tex.image,
                      tex.currentLayout != VK_IMAGE_LAYOUT_GENERAL else { continue }
                imageBarrier(cmd:        cmd,
                             image:      img,
                             oldLayout:  tex.currentLayout,
                             newLayout:  VK_IMAGE_LAYOUT_GENERAL,
                             srcAccess:  0,
                             dstAccess:  UInt32(bitPattern: (VK_ACCESS_SHADER_READ_BIT.rawValue
                                                           | VK_ACCESS_SHADER_WRITE_BIT.rawValue)),
                             srcStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT.rawValue),
                             dstStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT.rawValue),
                             aspectMask: tex.pixelFormat.aspectMask)
                tex.currentLayout = VK_IMAGE_LAYOUT_GENERAL
            }
        }

        // Dispatch
        vkCmdDispatch(cmd,
                      UInt32(threadgroupsPerGrid.width),
                      UInt32(threadgroupsPerGrid.height),
                      UInt32(threadgroupsPerGrid.depth))
    }

    /// Ends encoding and transfers ownership of bound resources to the parent `MTLCommandBuffer`
    /// so they remain alive until the GPU has finished execution.
    public func endEncoding() {
        isEnded = true
        // Transfer all bound resources to the command buffer so their Vulkan
        // handles remain valid through GPU completion.
        for (_, binding) in boundBuffers {
            commandBuffer.ownedBuffers.append(binding.buffer)
        }
        for (_, as_) in boundAccelerationStructures {
            commandBuffer.ownedAccelerationStructures.append(as_)
        }
        for (_, textures) in boundTextureSets {
            commandBuffer.ownedTextures.append(contentsOf: textures)
        }
        boundBuffers.removeAll()
        boundAccelerationStructures.removeAll()
        boundTextureSets.removeAll()
        pipeline = nil
    }
}
