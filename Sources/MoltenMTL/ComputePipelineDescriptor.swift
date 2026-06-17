/// Carries a compute pipeline's entry point and the explicit binding counts
/// used to build the `VkDescriptorSetLayout`.
///
/// Set the counts to match your GLSL `layout(binding=N)` declarations;
/// binding slots are assigned sequentially:
/// ```
/// storage buffers:         0 ..< storageBufferCount
/// acceleration structures: storageBufferCount ..< storageBufferCount + accelerationStructureCount
/// storage images:          storageBufferCount + accelerationStructureCount ..< total
/// ```
public final class MTLComputePipelineDescriptor {

    public var computeFunction: MTLFunction?

    /// Number of storage-buffer bindings declared in the shader.
    public var storageBufferCount: Int = 0

    /// Number of acceleration-structure bindings declared in the shader.
    public var accelerationStructureCount: Int = 0

    /// Number of storage-image bindings declared in the shader.
    public var storageImageCount: Int = 0

    public init() {}
}
