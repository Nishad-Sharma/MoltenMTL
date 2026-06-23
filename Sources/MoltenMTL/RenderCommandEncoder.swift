internal import CVulkan

/// Records draw calls into the parent `MTLCommandBuffer` using dynamic rendering.
/// Create via `commandBuffer.makeRenderCommandEncoder(descriptor:)`.
///
/// Coordinate convention: the viewport is recorded with negative height so NDC
/// follows **Metal's +Y-up convention**. Write vertex shaders as you would for
/// Metal; GLSL written for Vulkan's +Y-down NDC will appear vertically flipped.
///
/// Resource binding follows the same per-stage rule as
/// `device.makeRenderPipelineState(descriptor:)`: vertex-stage resources are
/// descriptor set 0, fragment-stage resources set 1, Metal index = GLSL binding.
public final class MTLRenderCommandEncoder {

    /// Used by GPU debuggers.
    public var label: String?

    private let commandBuffer: MTLCommandBuffer
    private var pipeline: MTLRenderPipelineState?

    private let attachmentTexture: MTLTexture
    private let storeOp: VkAttachmentStoreOp
    private let clearColor: MTLClearColor

    /// Optional depth attachment. `nil` when rendering without depth.
    private let depthTexture: MTLTexture?
    private let depthStoreOp: VkAttachmentStoreOp
    private let clearDepth: Double

    /// Optional stencil attachment. `nil` when rendering without stencil. For a
    /// combined format this is the same texture as `depthTexture`.
    private let stencilTexture: MTLTexture?
    private let stencilStoreOp: VkAttachmentStoreOp
    private let clearStencil: UInt32

    /// Depth/stencil state bound via `setDepthStencilState(_:)`, plus the stencil
    /// reference value. Applied as dynamic state before each draw while
    /// `depthStencilDirty`. `nil` state ⇒ depth/stencil effectively off.
    private var depthStencilState: MTLDepthStencilState?
    private var stencilReferenceFront: UInt32 = 0
    private var stencilReferenceBack:  UInt32 = 0
    private var depthStencilDirty = true

    /// Cull mode + front-face winding, applied as dynamic state before each draw.
    /// Default to Metal's defaults (no culling, clockwise front faces).
    private var cullMode: MTLCullMode = .none
    private var winding:  MTLWinding  = .clockwise

    /// Vertex-stage buffers — resolved at draw time into either Vulkan vertex-input
    /// bindings (indices in the pipeline's vertex descriptor) or set-0 descriptors.
    private var vertexBuffers:    [Int: (buffer: MTLBuffer, offset: Int)] = [:]
    private var fragmentBuffers:  [Int: (buffer: MTLBuffer, offset: Int)] = [:]
    private var fragmentTextures: [Int: MTLTexture] = [:]
    private var fragmentSamplers: [Int: MTLSamplerState] = [:]

    /// Set on any binding/pipeline change; descriptor sets are only rebuilt when
    /// dirty so a UI pass with many draws doesn't allocate a pool per draw.
    private var descriptorsDirty = true
    private var pipelineDirty    = true
    private var renderingActive  = false
    private var isEnded          = false

    init?(commandBuffer: MTLCommandBuffer, descriptor: MTLRenderPassDescriptor) {
        let attachment = descriptor.colorAttachments[0]
        guard let texture = attachment.texture else {
            print("[MoltenMTL] makeRenderCommandEncoder: colorAttachments[0].texture is nil")
            return nil
        }
        guard texture.imageView != nil else {
            print("[MoltenMTL] makeRenderCommandEncoder: attachment texture has no image view")
            return nil
        }

        self.commandBuffer     = commandBuffer
        self.attachmentTexture = texture
        self.storeOp           = attachment.storeAction.vkStoreOp
        self.clearColor        = attachment.clearColor

        let depth = descriptor.depthAttachment
        self.depthTexture = depth.texture
        self.depthStoreOp = depth.storeAction.vkStoreOp
        self.clearDepth   = depth.clearDepth

        let stencil = descriptor.stencilAttachment
        self.stencilTexture = stencil.texture
        self.stencilStoreOp = stencil.storeAction.vkStoreOp
        self.clearStencil   = stencil.clearStencil

        let cmd = commandBuffer.handle

        // Transition the attachment to COLOR_ATTACHMENT_OPTIMAL. The broad
        // ALL_COMMANDS/MEMORY_WRITE source covers a prior compute or blit write
        // (e.g. the ray-traced scene already in the drawable).
        if texture.currentLayout != VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL {
            imageBarrier(cmd:        cmd,
                         image:      texture.image,
                         oldLayout:  texture.currentLayout,
                         newLayout:  VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                         srcAccess:  UInt32(bitPattern: VK_ACCESS_MEMORY_WRITE_BIT.rawValue),
                         dstAccess:  UInt32(bitPattern: (VK_ACCESS_COLOR_ATTACHMENT_READ_BIT.rawValue
                                                       | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT.rawValue)),
                         srcStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue),
                         dstStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue),
                         aspectMask: texture.pixelFormat.aspectMask)
            texture.currentLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        }

        // Transition the depth and stencil attachments (if any) to the depth/stencil
        // attachment layout. A combined-format texture serves both aspects and is
        // shared between the two attachments, so barrier each unique image once —
        // the second `transitionDepthStencil` is a no-op once the layout matches.
        transitionDepthStencil(cmd: cmd, texture: depth.texture)
        transitionDepthStencil(cmd: cmd, texture: stencil.texture)

        beginRendering(loadOp: attachment.loadAction.vkLoadOp,
                       depthLoadOp: depth.loadAction.vkLoadOp,
                       stencilLoadOp: stencil.loadAction.vkLoadOp)

        // Default viewport (full attachment, Metal Y convention) and scissor.
        setViewport(MTLViewport(width: Double(texture.width), height: Double(texture.height)))
        setScissorRect(MTLScissorRect(width: texture.width, height: texture.height))
    }

    /// Sets the render pipeline that subsequent draw calls will use.
    public func setRenderPipelineState(_ pipeline: MTLRenderPipelineState) {
        self.pipeline    = pipeline
        pipelineDirty    = true
        descriptorsDirty = true
        // Binding a pipeline resets dynamic state, so depth/stencil must be re-applied.
        depthStencilDirty = true
    }

    /// Sets the depth/stencil state for subsequent draws. Pass `nil` to disable
    /// depth testing/writing and stencil effects. Applied as Vulkan dynamic state,
    /// so it can be changed between draws without switching pipelines.
    public func setDepthStencilState(_ state: MTLDepthStencilState?) {
        depthStencilState = state
        depthStencilDirty = true
    }

    /// Sets which triangle faces are culled (default `.none`).
    public func setCullMode(_ mode: MTLCullMode) {
        cullMode = mode
    }

    /// Sets the winding order that defines a front-facing triangle (default `.clockwise`).
    public func setFrontFacingWinding(_ winding: MTLWinding) {
        self.winding = winding
    }

    /// Sets the stencil reference value for both faces.
    public func setStencilReferenceValue(_ referenceValue: UInt32) {
        stencilReferenceFront = referenceValue
        stencilReferenceBack  = referenceValue
        depthStencilDirty     = true
    }

    /// Sets separate stencil reference values for front- and back-facing triangles.
    public func setStencilReferenceValues(front: UInt32, back: UInt32) {
        stencilReferenceFront = front
        stencilReferenceBack  = back
        depthStencilDirty     = true
    }

    /// Binds `buffer` for the vertex stage at `index` — either a vertex-input
    /// binding (if `index` appears in the pipeline's vertex descriptor) or a
    /// set-0 descriptor.
    public func setVertexBuffer(_ buffer: MTLBuffer?, offset: Int = 0, index: Int) {
        guard let buffer = buffer else {
            print("[MoltenMTL] setVertexBuffer: nil buffer for index \(index)"); return
        }
        vertexBuffers[index] = (buffer: buffer, offset: offset)
        // Retain immediately: a draw records this buffer into a descriptor set or
        // vertex binding, and a later rebind of the same index must not free it
        // while the command buffer is still recording or in flight.
        commandBuffer.ownedBuffers.append(buffer)
        descriptorsDirty = true
    }

    /// Convenience for small per-draw constants: copies bytes into a transient
    /// shared buffer and binds it to the vertex stage at `index`.
    public func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
        guard let buf = makeTransientBuffer(bytes: bytes, length: length) else { return }
        setVertexBuffer(buf, offset: 0, index: index)
    }

    /// Binds `buffer` to the fragment-stage descriptor (set 1) at `index`.
    public func setFragmentBuffer(_ buffer: MTLBuffer?, offset: Int = 0, index: Int) {
        guard let buffer = buffer else {
            print("[MoltenMTL] setFragmentBuffer: nil buffer for index \(index)"); return
        }
        fragmentBuffers[index] = (buffer: buffer, offset: offset)
        commandBuffer.ownedBuffers.append(buffer)   // see setVertexBuffer
        descriptorsDirty = true
    }

    /// Convenience for small per-draw constants: copies bytes into a transient
    /// shared buffer and binds it to the fragment stage at `index`.
    public func setFragmentBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
        guard let buf = makeTransientBuffer(bytes: bytes, length: length) else { return }
        setFragmentBuffer(buf, offset: 0, index: index)
    }

    /// Binds `texture` for sampling in the fragment shader at `index`.
    /// Pair with `setFragmentSamplerState(_:index:)` at the same index — together
    /// they fill one combined image sampler (GLSL `sampler2D`) at set 1, binding `index`.
    public func setFragmentTexture(_ texture: MTLTexture?, index: Int) {
        guard let texture = texture else {
            print("[MoltenMTL] setFragmentTexture: nil texture for index \(index)"); return
        }
        fragmentTextures[index] = texture
        commandBuffer.ownedTextures.append(texture)   // see setVertexBuffer
        descriptorsDirty = true
    }

    /// Binds `sampler` at fragment index `index`. See `setFragmentTexture(_:index:)`.
    public func setFragmentSamplerState(_ sampler: MTLSamplerState?, index: Int) {
        guard let sampler = sampler else {
            print("[MoltenMTL] setFragmentSamplerState: nil sampler for index \(index)"); return
        }
        fragmentSamplers[index] = sampler
        commandBuffer.ownedSamplers.append(sampler)   // see setVertexBuffer
        descriptorsDirty = true
    }

    /// Sets the viewport. `viewport` uses Metal's top-left-origin convention;
    /// it is recorded as a negative-height Vulkan viewport to preserve +Y-up NDC.
    public func setViewport(_ viewport: MTLViewport) {
        var vk = VkViewport()
        vk.x        = Float(viewport.originX)
        vk.y        = Float(viewport.originY + viewport.height)
        vk.width    = Float(viewport.width)
        vk.height   = Float(-viewport.height)
        vk.minDepth = Float(viewport.znear)
        vk.maxDepth = Float(viewport.zfar)
        vkCmdSetViewport(commandBuffer.handle, 0, 1, &vk)
    }

    /// Sets the scissor rectangle in framebuffer pixels.
    public func setScissorRect(_ rect: MTLScissorRect) {
        var vk = VkRect2D()
        vk.offset.x      = Int32(rect.x)
        vk.offset.y      = Int32(rect.y)
        vk.extent.width  = UInt32(rect.width)
        vk.extent.height = UInt32(rect.height)
        vkCmdSetScissor(commandBuffer.handle, 0, 1, &vk)
    }

    /// Encodes a non-indexed draw.
    public func drawPrimitives(type: MTLPrimitiveType, vertexStart: Int, vertexCount: Int) {
        guard prepareDraw(type: type) else { return }
        vkCmdDraw(commandBuffer.handle, UInt32(vertexCount), 1, UInt32(vertexStart), 0)
    }

    /// Encodes an indexed draw reading indices from `indexBuffer`.
    public func drawIndexedPrimitives(type: MTLPrimitiveType,
                                      indexCount: Int,
                                      indexType: MTLIndexType,
                                      indexBuffer: MTLBuffer,
                                      indexBufferOffset: Int = 0) {
        guard prepareDraw(type: type) else { return }
        let vkIndexType = indexType == .uint16 ? VK_INDEX_TYPE_UINT16 : VK_INDEX_TYPE_UINT32
        vkCmdBindIndexBuffer(commandBuffer.handle, indexBuffer.handle,
                             VkDeviceSize(indexBufferOffset), vkIndexType)
        commandBuffer.ownedBuffers.append(indexBuffer)
        vkCmdDrawIndexed(commandBuffer.handle, UInt32(indexCount), 1, 0, 0, 0)
    }

    /// Ends the render pass. Bound buffers/textures/samplers were already handed
    /// to the parent `MTLCommandBuffer` for lifetime at bind time; here we only
    /// retain the attachment and pipeline. The attachment is left in
    /// `COLOR_ATTACHMENT_OPTIMAL`.
    public func endEncoding() {
        guard !isEnded else { return }
        isEnded = true
        if renderingActive {
            vkCmdEndRendering(commandBuffer.handle)
            renderingActive = false
        }

        commandBuffer.ownedTextures.append(attachmentTexture)
        if let depthTex = depthTexture { commandBuffer.ownedTextures.append(depthTex) }
        // Retain the stencil texture too, unless it's the same object as the depth
        // texture (combined format), which was just retained above.
        if let stencilTex = stencilTexture, stencilTex !== depthTexture {
            commandBuffer.ownedTextures.append(stencilTex)
        }
        if let pso = pipeline { commandBuffer.ownedRenderPipelines.append(pso) }

        vertexBuffers.removeAll()
        fragmentBuffers.removeAll()
        fragmentTextures.removeAll()
        fragmentSamplers.removeAll()
        pipeline = nil
    }

    // MARK: - Draw preparation

    /// Binds the pipeline, transitions sampled textures, and (re)builds descriptor
    /// sets if any binding changed since the previous draw.
    private func prepareDraw(type: MTLPrimitiveType) -> Bool {
        guard !isEnded else {
            print("[MoltenMTL] draw called after endEncoding"); return false
        }
        guard type == .triangle else {
            print("[MoltenMTL] only .triangle primitives are supported (pipelines use triangle-list topology)")
            return false
        }
        guard let pso        = pipeline,
              let vkPipeline = pso.pipeline,
              let vkLayout   = pso.pipelineLayout,
              let dev        = commandBuffer.commandQueue.vkDevice else {
            print("[MoltenMTL] draw: pipeline or device not set"); return false
        }

        let cmd = commandBuffer.handle

        transitionSampledTextures(cmd: cmd)

        if pipelineDirty {
            vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, vkPipeline)
            pipelineDirty = false
        }

        // Depth and stencil test/write/compare/op are dynamic state on every
        // pipeline, so they must be set before the first draw and re-set after any
        // pipeline bind. No bound state ⇒ always-pass compares with no writes
        // (depth/stencil effectively disabled).
        if depthStencilDirty {
            applyDepthStencilState(cmd: cmd)
            depthStencilDirty = false
        }

        // Cull mode + front face are dynamic on every pipeline, so they must be set
        // before each draw (and re-set after a pipeline bind). Emitted unconditionally.
        vkCmdSetCullMode(cmd, cullMode.vkCullMode)
        vkCmdSetFrontFace(cmd, winding.vkFrontFace)

        if descriptorsDirty {
            guard bindDescriptorSets(dev: dev, cmd: cmd, pso: pso, layout: vkLayout) else {
                return false
            }
            descriptorsDirty = false
        }

        // Vertex-input bindings (indices declared in the pipeline's vertex descriptor)
        for index in pso.vertexBufferBindings.sorted() {
            guard let binding = vertexBuffers[index] else {
                print("[MoltenMTL] draw: no vertex buffer bound at index \(index)")
                return false
            }
            var buf:    VkBuffer?    = binding.buffer.handle
            var offset: VkDeviceSize = VkDeviceSize(binding.offset)
            vkCmdBindVertexBuffers(cmd, UInt32(index), 1, &buf, &offset)
        }

        return true
    }

    /// Sampled textures must be in `SHADER_READ_ONLY_OPTIMAL`, and barriers are
    /// illegal inside dynamic rendering — so when a bound texture is in the wrong
    /// layout, suspend the pass (end → barrier → re-begin with `loadOp = LOAD`).
    /// `MTLTexture.replace(...)` already leaves `.shaderRead` textures in the right
    /// layout, so this fallback normally never fires.
    private func transitionSampledTextures(cmd: VkCommandBuffer) {
        let stale = fragmentTextures.values.filter {
            $0.currentLayout != VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        }
        guard !stale.isEmpty else { return }

        if renderingActive {
            vkCmdEndRendering(cmd)
            renderingActive = false
        }
        for tex in stale {
            imageBarrier(cmd:        cmd,
                         image:      tex.image,
                         oldLayout:  tex.currentLayout,
                         newLayout:  VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                         srcAccess:  UInt32(bitPattern: VK_ACCESS_MEMORY_WRITE_BIT.rawValue),
                         dstAccess:  UInt32(bitPattern: VK_ACCESS_SHADER_READ_BIT.rawValue),
                         srcStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue),
                         dstStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT.rawValue),
                         aspectMask: tex.pixelFormat.aspectMask)
            tex.currentLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        }
        // Resume preserving color, depth, and stencil contents written so far.
        beginRendering(loadOp: VK_ATTACHMENT_LOAD_OP_LOAD,
                       depthLoadOp: VK_ATTACHMENT_LOAD_OP_LOAD,
                       stencilLoadOp: VK_ATTACHMENT_LOAD_OP_LOAD)
    }

    // MARK: - Descriptor sets

    /// Creates a transient pool sized from the pipeline's declared layout slots,
    /// allocates one set per non-empty stage set, writes all bound resources, and
    /// binds the sets. Returns `false` on a Vulkan failure.
    private func bindDescriptorSets(dev: VkDevice, cmd: VkCommandBuffer,
                                    pso: MTLRenderPipelineState,
                                    layout: VkPipelineLayout) -> Bool {
        let nonEmptySets = (0..<2).filter { !pso.bindingTypes[$0].isEmpty }
        guard !nonEmptySets.isEmpty else { return true }

        // Pool sized to cover every declared layout slot, not just bound ones.
        var countsByType: [Int32: UInt32] = [:]
        for set in nonEmptySets {
            for type in pso.bindingTypes[set].values {
                countsByType[type.rawValue, default: 0] += 1
            }
        }
        let poolSizes: [VkDescriptorPoolSize] = countsByType.map { rawType, count in
            var ps = VkDescriptorPoolSize()
            ps.type            = VkDescriptorType(rawValue: rawType)
            ps.descriptorCount = count
            return ps
        }

        var pool: VkDescriptorPool?
        poolSizes.withUnsafeBufferPointer { psPtr in
            var poolCI = VkDescriptorPoolCreateInfo()
            poolCI.sType         = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
            poolCI.maxSets       = UInt32(nonEmptySets.count)
            poolCI.poolSizeCount = UInt32(psPtr.count)
            poolCI.pPoolSizes    = psPtr.baseAddress
            vkCreateDescriptorPool(dev, &poolCI, nil, &pool)
        }
        guard pool != nil else {
            print("[MoltenMTL] vkCreateDescriptorPool failed"); return false
        }
        commandBuffer.ownedPools.append(pool)

        for set in nonEmptySets {
            var descriptorSet: VkDescriptorSet?
            var dsl = pso.setLayouts[set]
            withUnsafePointer(to: &dsl) { dslPtr in
                var allocInfo = VkDescriptorSetAllocateInfo()
                allocInfo.sType              = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
                allocInfo.descriptorPool     = pool!
                allocInfo.descriptorSetCount = 1
                allocInfo.pSetLayouts        = dslPtr
                vkAllocateDescriptorSets(dev, &allocInfo, &descriptorSet)
            }
            guard let descSet = descriptorSet else {
                print("[MoltenMTL] vkAllocateDescriptorSets failed"); return false
            }

            writeDescriptors(dev: dev, set: set, descSet: descSet, pso: pso)

            var setToBind: VkDescriptorSet? = descSet
            withUnsafePointer(to: &setToBind) { setPtr in
                vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS,
                                        layout, UInt32(set), 1, setPtr, 0, nil)
            }
        }
        return true
    }

    /// Writes buffer and combined-image-sampler descriptors for one stage set.
    /// Set 0 sources from `vertexBuffers` (excluding vertex-input indices);
    /// set 1 from `fragmentBuffers` + `fragmentTextures`/`fragmentSamplers` pairs.
    private func writeDescriptors(dev: VkDevice, set: Int,
                                  descSet: VkDescriptorSet,
                                  pso: MTLRenderPipelineState) {
        for (binding, type) in pso.bindingTypes[set] {
            let index = Int(binding)

            switch type {
            case VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER:
                let bound = set == 0 ? vertexBuffers[index] : fragmentBuffers[index]
                guard let bound = bound else {
                    print("[MoltenMTL] draw: no \(set == 0 ? "vertex" : "fragment") buffer bound at index \(index)")
                    continue
                }
                var info = VkDescriptorBufferInfo()
                info.buffer = bound.buffer.handle
                info.offset = VkDeviceSize(bound.offset)
                info.range  = UInt64.max    // VK_WHOLE_SIZE
                withUnsafePointer(to: &info) { infoPtr in
                    var w = VkWriteDescriptorSet()
                    w.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
                    w.dstSet          = descSet
                    w.dstBinding      = binding
                    w.descriptorCount = 1
                    w.descriptorType  = type
                    w.pBufferInfo     = infoPtr
                    vkUpdateDescriptorSets(dev, 1, &w, 0, nil)
                }

            case VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER:
                guard set == 1 else {
                    print("[MoltenMTL] draw: sampled textures are only supported in the fragment stage (set 1)")
                    continue
                }
                guard let texture = fragmentTextures[index], let view = texture.imageView else {
                    print("[MoltenMTL] draw: no fragment texture bound at index \(index)")
                    continue
                }
                guard let sampler = fragmentSamplers[index] else {
                    print("[MoltenMTL] draw: no sampler bound at index \(index) — pair setFragmentTexture with setFragmentSamplerState")
                    continue
                }
                var info = VkDescriptorImageInfo()
                info.sampler     = sampler.sampler
                info.imageView   = view
                info.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
                withUnsafePointer(to: &info) { infoPtr in
                    var w = VkWriteDescriptorSet()
                    w.sType           = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
                    w.dstSet          = descSet
                    w.dstBinding      = binding
                    w.descriptorCount = 1
                    w.descriptorType  = type
                    w.pImageInfo      = infoPtr
                    vkUpdateDescriptorSets(dev, 1, &w, 0, nil)
                }

            default:
                print("[MoltenMTL] draw: unsupported descriptor type \(type.rawValue) at set \(set), binding \(binding)")
            }
        }
    }

    // MARK: - Helpers

    private func makeTransientBuffer(bytes: UnsafeRawPointer, length: Int) -> MTLBuffer? {
        guard let buf = commandBuffer.commandQueue.device
                .makeBuffer(length: max(length, 4), options: .shared) else { return nil }
        buf.contents().copyMemory(from: bytes, byteCount: length)
        return buf
    }

    /// The attachment layout for a depth/stencil image: the combined layout when
    /// the format carries stencil, otherwise the depth-only layout.
    private func depthStencilLayout(for texture: MTLTexture) -> VkImageLayout {
        texture.pixelFormat.hasStencil ? VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
                                       : VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL
    }

    /// Transitions a depth/stencil attachment to its attachment-optimal layout.
    /// A no-op when `texture` is nil or already in the right layout — so calling it
    /// for both the depth and stencil attachments of a shared combined-format
    /// texture barriers the image exactly once.
    private func transitionDepthStencil(cmd: VkCommandBuffer, texture: MTLTexture?) {
        guard let texture = texture else { return }
        let target = depthStencilLayout(for: texture)
        guard texture.currentLayout != target else { return }
        imageBarrier(cmd:        cmd,
                     image:      texture.image,
                     oldLayout:  texture.currentLayout,
                     newLayout:  target,
                     srcAccess:  UInt32(bitPattern: VK_ACCESS_MEMORY_WRITE_BIT.rawValue),
                     dstAccess:  UInt32(bitPattern: (VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT.rawValue
                                                   | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT.rawValue)),
                     srcStage:   UInt32(bitPattern: VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue),
                     dstStage:   UInt32(bitPattern: (VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT.rawValue
                                                   | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT.rawValue)),
                     aspectMask: texture.pixelFormat.aspectMask)
        texture.currentLayout = target
    }

    /// Records the bound depth/stencil state (and stencil reference) as dynamic
    /// state. With no state bound, depth/stencil pass through with no writes.
    private func applyDepthStencilState(cmd: VkCommandBuffer) {
        // Depth.
        let depthWrite: VkBool32 = (depthStencilState?.depthWriteEnable ?? false) ? VK_TRUE : VK_FALSE
        let depthCompare         = depthStencilState?.depthCompareOp ?? VK_COMPARE_OP_ALWAYS
        vkCmdSetDepthTestEnable(cmd, VK_TRUE)
        vkCmdSetDepthWriteEnable(cmd, depthWrite)
        vkCmdSetDepthCompareOp(cmd, depthCompare)

        // Stencil — per face. Without a bound state, an always-pass / keep
        // configuration leaves the stencil buffer untouched.
        vkCmdSetStencilTestEnable(cmd, VK_TRUE)
        let front = depthStencilState?.frontStencil ?? defaultStencilOpState
        let back  = depthStencilState?.backStencil  ?? defaultStencilOpState
        let frontFace = UInt32(bitPattern: VK_STENCIL_FACE_FRONT_BIT.rawValue)
        let backFace  = UInt32(bitPattern: VK_STENCIL_FACE_BACK_BIT.rawValue)

        vkCmdSetStencilOp(cmd, frontFace, front.failOp, front.passOp, front.depthFailOp, front.compareOp)
        vkCmdSetStencilOp(cmd, backFace,  back.failOp,  back.passOp,  back.depthFailOp,  back.compareOp)
        vkCmdSetStencilCompareMask(cmd, frontFace, front.compareMask)
        vkCmdSetStencilCompareMask(cmd, backFace,  back.compareMask)
        vkCmdSetStencilWriteMask(cmd, frontFace, front.writeMask)
        vkCmdSetStencilWriteMask(cmd, backFace,  back.writeMask)
        vkCmdSetStencilReference(cmd, frontFace, stencilReferenceFront)
        vkCmdSetStencilReference(cmd, backFace,  stencilReferenceBack)
    }

    /// Pass-through stencil op state used when no depth/stencil state is bound.
    private var defaultStencilOpState: VkStencilOpState {
        var s = VkStencilOpState()
        s.failOp      = VK_STENCIL_OP_KEEP
        s.passOp      = VK_STENCIL_OP_KEEP
        s.depthFailOp = VK_STENCIL_OP_KEEP
        s.compareOp   = VK_COMPARE_OP_ALWAYS
        s.compareMask = 0xFFFF_FFFF
        s.writeMask   = 0xFFFF_FFFF
        s.reference   = 0
        return s
    }

    private func beginRendering(loadOp: VkAttachmentLoadOp,
                                depthLoadOp: VkAttachmentLoadOp,
                                stencilLoadOp: VkAttachmentLoadOp) {
        var attachment = VkRenderingAttachmentInfo()
        attachment.sType       = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO
        attachment.imageView   = attachmentTexture.imageView
        attachment.imageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        attachment.loadOp      = loadOp
        attachment.storeOp     = storeOp
        attachment.clearValue.color.float32 = (Float(clearColor.red),
                                               Float(clearColor.green),
                                               Float(clearColor.blue),
                                               Float(clearColor.alpha))

        var depthAttachment = VkRenderingAttachmentInfo()
        if let depthTex = depthTexture {
            depthAttachment.sType       = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO
            depthAttachment.imageView   = depthTex.imageView
            depthAttachment.imageLayout = depthStencilLayout(for: depthTex)
            depthAttachment.loadOp      = depthLoadOp
            depthAttachment.storeOp     = depthStoreOp
            depthAttachment.clearValue.depthStencil.depth = Float(clearDepth)
        }

        var stencilAttachment = VkRenderingAttachmentInfo()
        if let stencilTex = stencilTexture {
            stencilAttachment.sType       = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO
            stencilAttachment.imageView   = stencilTex.imageView
            stencilAttachment.imageLayout = depthStencilLayout(for: stencilTex)
            stencilAttachment.loadOp      = stencilLoadOp
            stencilAttachment.storeOp     = stencilStoreOp
            stencilAttachment.clearValue.depthStencil.stencil = clearStencil
        }

        withUnsafePointer(to: &attachment) { attPtr in
            withUnsafePointer(to: &depthAttachment) { depthPtr in
                withUnsafePointer(to: &stencilAttachment) { stencilPtr in
                    var info = VkRenderingInfo()
                    info.sType                    = VK_STRUCTURE_TYPE_RENDERING_INFO
                    info.renderArea.extent.width  = UInt32(attachmentTexture.width)
                    info.renderArea.extent.height = UInt32(attachmentTexture.height)
                    info.layerCount               = 1
                    info.colorAttachmentCount     = 1
                    info.pColorAttachments        = attPtr
                    info.pDepthAttachment         = depthTexture   != nil ? depthPtr   : nil
                    info.pStencilAttachment       = stencilTexture != nil ? stencilPtr : nil
                    vkCmdBeginRendering(commandBuffer.handle, &info)
                }
            }
        }
        renderingActive = true
    }
}
