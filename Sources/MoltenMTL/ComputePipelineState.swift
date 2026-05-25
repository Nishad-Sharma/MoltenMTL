import CVulkan

// MARK: - ComputePipelineState

/// Mirrors MTLComputePipelineState.
///
/// Wraps a `VkPipeline` (compute), its `VkPipelineLayout`, and the
/// `VkDescriptorSetLayout` used to describe storage-buffer bindings.
///
/// Create via `device.makeComputePipelineState(function:)` — never directly.
public final class MTLComputePipelineState {

    // MARK: Internal Vulkan handles
    // (internal so ComputeCommandEncoder can access them; not part of the public API)

    /// The compiled Vulkan compute pipeline.
    let pipeline: VkPipeline?

    /// Layout describing push constants and descriptor sets for this pipeline.
    let pipelineLayout: VkPipelineLayout?

    /// Descriptor set layout derived from SPIR-V reflection.
    let descriptorSetLayout: VkDescriptorSetLayout?

    /// Number of storage-buffer binding slots declared in the reflected layout.
    /// Used to size the descriptor pool — must cover all declared slots, not just
    /// the ones that happen to be bound in a given dispatch.
    let storageBufferCount: Int

    private let vkDevice: VkDevice?

    // MARK: Init / deinit

    init(pipeline:            VkPipeline?,
         pipelineLayout:      VkPipelineLayout?,
         descriptorSetLayout: VkDescriptorSetLayout?,
         storageBufferCount:  Int,
         vkDevice:            VkDevice?) {
        self.pipeline            = pipeline
        self.pipelineLayout      = pipelineLayout
        self.descriptorSetLayout = descriptorSetLayout
        self.storageBufferCount  = storageBufferCount
        self.vkDevice            = vkDevice
    }

    deinit {
        guard let dev = vkDevice else { return }
        if let p   = pipeline            { vkDestroyPipeline(dev, p, nil) }
        if let pl  = pipelineLayout      { vkDestroyPipelineLayout(dev, pl, nil) }
        if let dsl = descriptorSetLayout { vkDestroyDescriptorSetLayout(dev, dsl, nil) }
    }
}
