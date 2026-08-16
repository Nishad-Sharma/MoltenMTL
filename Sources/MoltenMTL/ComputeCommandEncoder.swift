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
    private var boundSamplers:    [Int: MTLSamplerState] = [:]

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
        guard let buffer = buffer else {
            print("[MoltenMTL] setBuffer: nil buffer for index \(index) - binding unchanged"); return
        }
        boundBuffers[index] = (buffer: buffer, offset: offset)
        // retain while command buffer is recording or in flight.
        commandBuffer.ownedBuffers.append(buffer)
    }

    /// Binds an array of textures to the image slot at `index`.
    /// - Important: **This is not Metal's `setTextures(_:range:)`.** Metal spreads N textures
    ///   across N consecutive texture-table slots; this binds the whole array into a *single*
    ///   descriptor array at one binding, matching `uniform sampler2D tex[N]` in GLSL.
    public func setTextures(_ textures: [MTLTexture], index: Int) {
        boundTextureSets[index] = textures
        commandBuffer.ownedTextures.append(contentsOf: textures)   // see setBuffer
    }

    /// Binds a single texture to the image slot at `index`.
    public func setTexture(_ texture: MTLTexture, index: Int) {
        setTextures([texture], index: index)
    }

    /// Sets the sampler used for the combined-image-sampler slot at `index`.
    /// Passing `nil` clears the slot, returning it to `device.defaultSampler`.
    public func setSamplerState(_ sampler: MTLSamplerState?, index: Int) {
        boundSamplers[index] = sampler
        if let sampler = sampler {
            commandBuffer.ownedSamplers.append(sampler)            // see setBuffer
        }
    }

    /// Binds `accelerationStructure` to the AS descriptor slot at `bufferIndex`.
    public func setAccelerationStructure(_ accelerationStructure: MTLAccelerationStructure,
                                         bufferIndex: Int) {
        boundAccelerationStructures[bufferIndex] = accelerationStructure
        commandBuffer.ownedAccelerationStructures.append(accelerationStructure)  // see setBuffer
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
        // Storage images and combined image samplers are padded separately - they end up in
        // different image layouts, so a single dummy cannot serve both.
        let mtlDevice = commandBuffer.commandQueue.device

        // Resize to exactly the declared count - surplus binds are dropped and short ones padded.
        // Returns nil when a slot cannot be filled: the caller must not dispatch, since
        // the shader would read a descriptor nothing wrote.
        func resizeToDeclared(_ counts: [Int: Int], kind: String,
                              dummy: MTLTexture?) -> [(key: Int, value: [MTLTexture])]? {
            var resized: [(key: Int, value: [MTLTexture])] = []
            for (slot, count) in counts.sorted(by: { $0.key < $1.key }) {
                var textures = self.boundTextureSets[slot] ?? []
                if textures.count > count {
                    print("[MoltenMTL] dispatchThreadgroups: \(textures.count) textures bound at \(kind) binding \(slot), which declares \(count) — ignoring the surplus")
                    textures = Array(textures.prefix(count))
                }
                if textures.count < count {
                    guard let dummy = dummy else {
                        print("[MoltenMTL] dispatchThreadgroups: \(kind) binding \(slot) needs \(count) textures, \(textures.count) bound, and no dummy texture is available")
                        return nil
                    }
                    textures += Array(repeating: dummy, count: count - textures.count)
                }
                resized.append((key: slot, value: textures))
            }
            return resized
        }

        let storageDummy = pso.imageBindingCounts.isEmpty
                         ? nil : mtlDevice.dummyTexture(usage: [.shaderRead, .shaderWrite])
        let sampledDummy = pso.sampledImageBindingCounts.isEmpty
                         ? nil : mtlDevice.dummyTexture(usage: .shaderRead)

        var effectiveTextureSets: [(key: Int, value: [MTLTexture])] = []
        var effectiveSampledSets: [(key: Int, value: [MTLTexture])] = []

        if pso.imageBindingCounts.isEmpty && pso.sampledImageBindingCounts.isEmpty {
            effectiveTextureSets = boundTextureSets.sorted { $0.key < $1.key }
        } else {
            guard let storageSets = resizeToDeclared(pso.imageBindingCounts,
                                                     kind: "storage-image", dummy: storageDummy),
                  let sampledSets = resizeToDeclared(pso.sampledImageBindingCounts,
                                                     kind: "sampled-image", dummy: sampledDummy)
            else { return }
            effectiveTextureSets = storageSets
            effectiveSampledSets = sampledSets
        }

        // A texture bound as both a storage image and a sampled image in the same
        // dispatch can only sit in one layout, has to be GENERAL.
        let alsoStorage = Set(effectiveTextureSets.flatMap { $0.value }.map { ObjectIdentifier($0) })
        func sampledLayout(for tex: MTLTexture) -> VkImageLayout {
            alsoStorage.contains(ObjectIdentifier(tex)) ? VK_IMAGE_LAYOUT_GENERAL
                                                        : VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        }

        let needsDescriptors = !sortedBuffers.isEmpty || !sortedAS.isEmpty
                            || !effectiveTextureSets.isEmpty || !effectiveSampledSets.isEmpty
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
            if !effectiveSampledSets.isEmpty {
                var ps = VkDescriptorPoolSize()
                ps.type            = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
                ps.descriptorCount = UInt32(effectiveSampledSets.map { $0.value.count }.reduce(0, +))
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

            /// Writes one binding's whole descriptor array in a single update.
            /// Returns false when the array could not be completed.
            ///
            /// Every element must be written: dropping a view-less texture would
            /// shift later textures into earlier slots and leave the tail
            /// uninitialised, so such a texture falls back to `dummy`'s view.
            func writeImageArray(_ textures: [MTLTexture], binding: Int,
                                 type: VkDescriptorType, layout: (MTLTexture) -> VkImageLayout,
                                 sampler: VkSampler?, dummy: MTLTexture?) -> Bool {
                var imageInfos: [VkDescriptorImageInfo] = []
                imageInfos.reserveCapacity(textures.count)
                for tex in textures {
                    guard let view = tex.imageView ?? dummy?.imageView else {
                        print("[MoltenMTL] dispatchThreadgroups: no image view for binding \(binding) - descriptor array left incomplete")
                        return false
                    }
                    if tex.imageView == nil {
                        print("[MoltenMTL] dispatchThreadgroups: texture at binding \(binding) has no image view - substituting the dummy texture")
                    }
                    var info = VkDescriptorImageInfo()
                    info.sampler     = sampler
                    info.imageView   = view
                    info.imageLayout = layout(tex)
                    imageInfos.append(info)
                }
                guard !imageInfos.isEmpty else { return true }

                let imageCount = imageInfos.count
                imageInfos.withUnsafeMutableBufferPointer { infosPtr in
                    var w = VkWriteDescriptorSet()
                    w.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
                    w.dstSet          = descSet
                    w.dstBinding      = UInt32(binding)
                    w.dstArrayElement = 0
                    w.descriptorCount = UInt32(imageCount)
                    w.descriptorType  = type
                    w.pImageInfo      = UnsafePointer(infosPtr.baseAddress)
                    vkUpdateDescriptorSets(dev, 1, &w, 0, nil)
                }
                return true
            }

            // Write storage-image descriptors
            for (bindingIndex, textures) in effectiveTextureSets {
                guard writeImageArray(textures, binding: bindingIndex,
                                      type:    VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
                                      layout:  { _ in VK_IMAGE_LAYOUT_GENERAL },
                                      sampler: nil, dummy: storageDummy)
                else { return }
            }

            // Write combined-image-sampler descriptors.
            for (bindingIndex, textures) in effectiveSampledSets {
                var slotSampler = boundSamplers[bindingIndex]
                if slotSampler == nil {
                    if boundTextureSets[bindingIndex] != nil {
                        print("[MoltenMTL] dispatchThreadgroups: no sampler bound at index \(bindingIndex) - pair setTextures with setSamplerState")
                    }
                    slotSampler = mtlDevice.defaultSampler
                }
                guard let vkSampler = slotSampler?.sampler else {
                    print("[MoltenMTL] dispatchThreadgroups: no sampler available for binding \(bindingIndex)"); return
                }
                guard writeImageArray(textures, binding: bindingIndex,
                                      type:    VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                                      layout:  sampledLayout(for:),
                                      sampler: vkSampler, dummy: sampledDummy)
                else { return }
            }

            // Bind descriptor set
            var setToBind: VkDescriptorSet? = descSet
            withUnsafePointer(to: &setToBind) { setPtr in
                vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE,
                                        vkLayout, 0, 1, setPtr, 0, nil)
            }
        }

        /// `force` emits the barrier even when the layout already matches. A barrier
        /// with oldLayout == newLayout is still a memory dependency, and storage
        /// images need one every dispatch: two dispatches sharing one both sit in
        /// GENERAL, so a layout-gated barrier would emit nothing between them and the
        /// second would read what the first wrote with no synchronisation.
        func transition(_ tex: MTLTexture, to target: VkImageLayout,
                        dstAccess: UInt32, force: Bool = false) {
            guard let img = tex.image, force || tex.currentLayout != target else { return }
            let src = sourceScope(leaving: tex.currentLayout)
            imageBarrier(cmd:        cmd,
                         image:      img,
                         oldLayout:  tex.currentLayout,
                         newLayout:  target,
                         srcAccess:  src.access,
                         dstAccess:  dstAccess,
                         srcStage:   src.stage,
                         dstStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT.rawValue),
                         aspectMask: tex.pixelFormat.aspectMask)
            tex.currentLayout = target
        }

        let shaderReadWrite = UInt32(bitPattern: (VK_ACCESS_SHADER_READ_BIT.rawValue
                                                | VK_ACCESS_SHADER_WRITE_BIT.rawValue))
        let shaderRead      = UInt32(bitPattern: VK_ACCESS_SHADER_READ_BIT.rawValue)

        for tex in effectiveTextureSets.flatMap({ $0.value }) {
            transition(tex, to: VK_IMAGE_LAYOUT_GENERAL, dstAccess: shaderReadWrite, force: true)
        }
        // One also bound as a storage image stays in GENERAL — see `sampledLayout(for:)`.
        for tex in effectiveSampledSets.flatMap({ $0.value })
        where !alsoStorage.contains(ObjectIdentifier(tex)) {
            transition(tex, to: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, dstAccess: shaderRead)
        }

        // Dispatch
        vkCmdDispatch(cmd,
                      UInt32(threadgroupsPerGrid.width),
                      UInt32(threadgroupsPerGrid.height),
                      UInt32(threadgroupsPerGrid.depth))
    }

    /// Ends encoding and clears all bindings. Bound resources are already owned by the
    /// parent `MTLCommandBuffer`, which keeps them alive until the GPU has finished.
    public func endEncoding() {
        isEnded = true
        boundBuffers.removeAll()
        boundAccelerationStructures.removeAll()
        boundTextureSets.removeAll()
        boundSamplers.removeAll()
        pipeline = nil
    }
}
