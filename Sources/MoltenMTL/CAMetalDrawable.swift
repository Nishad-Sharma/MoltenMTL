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
        // Create a view so the drawable can be a render-pass color attachment
        // (`makeRenderCommandEncoder` requires one — e.g. UI drawn over the frame).
        // The view is owned by the MTLTexture and destroyed in its deinit; the
        // IMAGE stays owned by the swapchain (allocation nil → deinit won't free it).
        var view: VkImageView?
        if let dev = device.device {
            var viewCI = VkImageViewCreateInfo()
            viewCI.sType                           = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
            viewCI.image                           = image
            viewCI.viewType                        = VK_IMAGE_VIEW_TYPE_2D
            viewCI.format                          = isBGRA ? VK_FORMAT_B8G8R8A8_UNORM : VK_FORMAT_R8G8B8A8_UNORM
            viewCI.subresourceRange.aspectMask     = VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT.rawValue)
            viewCI.subresourceRange.baseMipLevel   = 0
            viewCI.subresourceRange.levelCount     = 1
            viewCI.subresourceRange.baseArrayLayer = 0
            viewCI.subresourceRange.layerCount     = 1
            if vkCreateImageView(dev, &viewCI, nil, &view) != VK_SUCCESS {
                print("[MoltenMTL] vkCreateImageView failed — drawable not usable as render target")
                view = nil
            }
        }
        self.texture = MTLTexture(
            image:            image,
            imageView:        view,
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
