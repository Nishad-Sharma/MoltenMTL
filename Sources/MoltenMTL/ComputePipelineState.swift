import CVulkan

/// Wraps a `VkPipeline`, its `VkPipelineLayout`, and `VkDescriptorSetLayout`.
/// Create via `device.makeComputePipelineState(function:)` - never directly.
public final class MTLComputePipelineState {

    let pipeline: VkPipeline?
    let pipelineLayout: VkPipelineLayout?
    let descriptorSetLayout: VkDescriptorSetLayout?

    /// Pool sizing must cover all declared layout slots, not just bound ones.
    let storageBufferCount: Int

    private let vkDevice: VkDevice?

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
