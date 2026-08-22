internal import CVulkan

/// Wraps a `VkPipeline`, its `VkPipelineLayout`, and `VkDescriptorSetLayout`.
/// Create via `device.makeComputePipelineState(function:)` - never directly.
public final class MTLComputePipelineState {

    /// Read-only in Metal - set through `MTLComputePipelineDescriptor.label`.
    public let label: String?

    let pipeline: VkPipeline?
    let pipelineLayout: VkPipelineLayout?
    let descriptorSetLayout: VkDescriptorSetLayout?

    /// Pool sizing must cover all declared layout slots, not just bound ones.
    let storageBufferCount: Int
    /// Maps each storage-image binding slot to its declared descriptorCount.
    let imageBindingCounts: [Int: Int]
    /// Maps each combined-image-sampler binding slot to its declared descriptorCount.
    let sampledImageBindingCounts: [Int: Int]

    private let vkDevice: VkDevice?

    init(pipeline:            VkPipeline?,
         pipelineLayout:      VkPipelineLayout?,
         descriptorSetLayout: VkDescriptorSetLayout?,
         storageBufferCount:  Int,
         imageBindingCounts:  [Int: Int],
         sampledImageBindingCounts: [Int: Int] = [:],
         vkDevice:            VkDevice?,
         label:               String? = nil) {
        self.label               = label
        self.pipeline            = pipeline
        self.pipelineLayout      = pipelineLayout
        self.descriptorSetLayout = descriptorSetLayout
        self.storageBufferCount  = storageBufferCount
        self.imageBindingCounts  = imageBindingCounts
        self.sampledImageBindingCounts = sampledImageBindingCounts
        self.vkDevice            = vkDevice
    }

    deinit {
        guard let dev = vkDevice else { return }
        if let p   = pipeline            { vkDestroyPipeline(dev, p, nil) }
        if let pl  = pipelineLayout      { vkDestroyPipelineLayout(dev, pl, nil) }
        if let dsl = descriptorSetLayout { vkDestroyDescriptorSetLayout(dev, dsl, nil) }
    }
}
