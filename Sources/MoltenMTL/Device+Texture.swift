internal import CVulkan

public extension MTLDevice {

    /// Creates a GPU-only 2-D texture (VMA-managed, optimal tiling) with a `VkImageView` spanning all mip levels.
    func makeTexture(descriptor: MTLTextureDescriptor) -> MTLTexture? {
        guard let vmaAlloc = allocator,
              let vkDev    = device else { return nil }

        var img:   VkImage?
        var alloc: VmaAllocation?

        guard CVMA_createImage(vmaAlloc,
                               UInt32(descriptor.width),
                               UInt32(descriptor.height),
                               descriptor.pixelFormat.vkFormat,
                               descriptor.vkUsage,
                               UInt32(descriptor.mipmapLevelCount),
                               &img,
                               &alloc) == VK_SUCCESS else {
            print("[MoltenMTL] CVMA_createImage failed")
            return nil
        }

        var viewCI = VkImageViewCreateInfo()
        viewCI.sType                           = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
        viewCI.image                           = img
        viewCI.viewType                        = VK_IMAGE_VIEW_TYPE_2D
        viewCI.format                          = descriptor.pixelFormat.vkFormat
        viewCI.components.r                    = VK_COMPONENT_SWIZZLE_IDENTITY
        viewCI.components.g                    = VK_COMPONENT_SWIZZLE_IDENTITY
        viewCI.components.b                    = VK_COMPONENT_SWIZZLE_IDENTITY
        viewCI.components.a                    = VK_COMPONENT_SWIZZLE_IDENTITY
        viewCI.subresourceRange.aspectMask     = descriptor.pixelFormat.aspectMask
        viewCI.subresourceRange.baseMipLevel   = 0
        viewCI.subresourceRange.levelCount     = UInt32(descriptor.mipmapLevelCount)
        viewCI.subresourceRange.baseArrayLayer = 0
        viewCI.subresourceRange.layerCount     = 1

        var view: VkImageView?
        guard vkCreateImageView(vkDev, &viewCI, nil, &view) == VK_SUCCESS else {
            print("[MoltenMTL] vkCreateImageView failed")
            if let a = allocator, let i = img, let al = alloc {
                CVMA_destroyImage(a, i, al)
            }
            return nil
        }

        return MTLTexture(image:            img,
                       imageView:        view,
                       allocation:       alloc,
                       device:           self,
                       width:            descriptor.width,
                       height:           descriptor.height,
                       pixelFormat:      descriptor.pixelFormat,
                       mipmapLevelCount: descriptor.mipmapLevelCount,
                       usage:            descriptor.usage)
    }
}
