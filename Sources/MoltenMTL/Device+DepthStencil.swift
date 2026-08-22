public extension MTLDevice {

    /// Creates a depth/stencil state to bind via `setDepthStencilState(_:)`.
    ///
    /// Unlike most `make…` factories there is no Vulkan object to allocate: depth
    /// test/write/compare are recorded as dynamic state at draw time, so this just
    /// resolves the descriptor into the values the encoder will apply.
    func makeDepthStencilState(descriptor: MTLDepthStencilDescriptor) -> MTLDepthStencilState {
        MTLDepthStencilState(
            depthCompareOp:   descriptor.depthCompareFunction.vkCompareOp,
            depthWriteEnable: descriptor.isDepthWriteEnabled,
            frontStencil:     descriptor.frontFaceStencil.vkStencilOpState,
            backStencil:      descriptor.backFaceStencil.vkStencilOpState,
            stencilEnabled:   descriptor.frontFaceStencil.isActive
                                || descriptor.backFaceStencil.isActive,
            label:            descriptor.label)
    }
}
