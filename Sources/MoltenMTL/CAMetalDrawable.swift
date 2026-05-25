import CVulkan

/// Mirrors CAMetalDrawable — one acquired swapchain image for a single frame.
/// Obtain via `CAMetalLayer.nextDrawable()`.
/// Pass to `MTLCommandBuffer.present(_:)` before calling `commit()`.
public final class CAMetalDrawable {

    /// The swapchain image wrapped as an `MTLTexture`, mirroring Metal's `CAMetalDrawable.texture`.
    /// Supports `.width`, `.height`, and can be used as a blit destination via
    /// `MTLBlitCommandEncoder.copy(from:to:)` or `copyBuffer(_:toImage:width:height:)`.
    ///
    /// The underlying `VkImage` is owned by the swapchain — this texture does **not**
    /// free it on deinit (allocation is nil).
    public let texture: MTLTexture

    /// `true` when the swapchain format is BGRA — caller must swap R/B in the staging buffer.
    public let isBGRA: Bool

    /// Index into the swapchain's image array.
    public let imageIndex: UInt32

    /// Signalled by `vkAcquireNextImageKHR`; waited by the submit.
    let imageAvailableSemaphore: VkSemaphore

    /// Signalled by the submit; waited by `vkQueuePresentKHR`.
    let renderFinishedSemaphore: VkSemaphore

    /// Raw swapchain handle — used in `commit()` for `vkQueuePresentKHR`.
    let swapchainHandle: VkSwapchainKHR

    // todo: this shouldn't be public?
    public init(image: VkImage,
         isBGRA: Bool,
         imageIndex: UInt32,
         width: Int,
         height: Int,
         device: MTLDevice,
         imageAvailableSemaphore: VkSemaphore,
         renderFinishedSemaphore: VkSemaphore,
         swapchainHandle: VkSwapchainKHR) {
        // Wrap the swapchain VkImage as a lightweight MTLTexture.
        // allocation: nil → deinit will NOT call CVMA_destroyImage (swapchain owns the image).
        // imageView:  nil → no VkImageView to destroy.
        self.texture = MTLTexture(
            image:            image,
            imageView:        nil,
            allocation:       nil,
            device:           device,
            width:            width,
            height:           height,
            pixelFormat:      isBGRA ? .bgra8Unorm : .rgba8Unorm,
            mipmapLevelCount: 1,
            usage:            .renderTarget)
        self.isBGRA                   = isBGRA
        self.imageIndex               = imageIndex
        self.imageAvailableSemaphore  = imageAvailableSemaphore
        self.renderFinishedSemaphore  = renderFinishedSemaphore
        self.swapchainHandle          = swapchainHandle
    }
}
