internal import CVulkan

/// Obtain via `CAMetalLayer.nextDrawable()`, then pass to `MTLCommandBuffer.present(_:)` before `commit()`.
public final class CAMetalDrawable {

    /// The swapchain image as an `MTLTexture`.
    /// The underlying `VkImage` is owned by the swapchain - this texture does **not** free it on deinit.
    public let texture: MTLTexture

    public let isBGRA: Bool

    /// Index into the swapchain's image array.
    public let imageIndex: UInt32

    let imageAvailableSemaphore: VkSemaphore

    let renderFinishedSemaphore: VkSemaphore

    /// Raw swapchain handle - used in `commit()` for `vkQueuePresentKHR`.
    let swapchainHandle: VkSwapchainKHR

    init(image: VkImage,
         isBGRA: Bool,
         imageIndex: UInt32,
         width: Int,
         height: Int,
         device: MTLDevice,
         imageAvailableSemaphore: VkSemaphore,
         renderFinishedSemaphore: VkSemaphore,
         swapchainHandle: VkSwapchainKHR) {
        // allocation/imageView nil - swapchain owns the image; deinit must not free it.
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
