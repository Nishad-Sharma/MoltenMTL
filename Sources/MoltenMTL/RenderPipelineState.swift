internal import CVulkan

/// Wraps a graphics `VkPipeline`, its `VkPipelineLayout`, and the per-stage
/// `VkDescriptorSetLayout`s (set 0 = vertex stage, set 1 = fragment stage).
/// Create via `device.makeRenderPipelineState(descriptor:)` - never directly.
public final class MTLRenderPipelineState {

    /// Read-only in Metal - set through `MTLRenderPipelineDescriptor.label`.
    public let label: String?

    let pipeline:       VkPipeline?
    let pipelineLayout: VkPipelineLayout?
    /// `[0]` = vertex-stage set layout, `[1]` = fragment-stage set layout.
    /// A set with no shader bindings still gets an empty layout so indices stay stable.
    let setLayouts: [VkDescriptorSetLayout?]
    /// Reflected descriptor type per (set, binding) — tells the encoder whether a
    /// bound buffer is a uniform or storage descriptor, and which slots are samplers.
    let bindingTypes: [[UInt32: VkDescriptorType]]
    /// Buffer indices declared in the vertex descriptor's `layouts` — these are
    /// real Vulkan vertex-input bindings, not descriptors.
    let vertexBufferBindings: Set<Int>

    private let vkDevice: VkDevice?

    init(pipeline:             VkPipeline?,
         pipelineLayout:       VkPipelineLayout?,
         setLayouts:           [VkDescriptorSetLayout?],
         bindingTypes:         [[UInt32: VkDescriptorType]],
         vertexBufferBindings: Set<Int>,
         vkDevice:             VkDevice?,
         label:                String? = nil) {
        self.label                = label
        self.pipeline             = pipeline
        self.pipelineLayout       = pipelineLayout
        self.setLayouts           = setLayouts
        self.bindingTypes         = bindingTypes
        self.vertexBufferBindings = vertexBufferBindings
        self.vkDevice             = vkDevice
    }

    deinit {
        guard let dev = vkDevice else { return }
        if let p  = pipeline       { vkDestroyPipeline(dev, p, nil) }
        if let pl = pipelineLayout { vkDestroyPipelineLayout(dev, pl, nil) }
        for layout in setLayouts {
            if let dsl = layout { vkDestroyDescriptorSetLayout(dev, dsl, nil) }
        }
    }
}
