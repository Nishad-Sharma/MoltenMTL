#include "include/CSwapchain.h"
#include <string.h>
#include <stdlib.h>

// ── Buffer → image copy with layout transitions ───────────────────────────────

void CVKS_cmdCopyBufferToImage(VkCommandBuffer cmd,
                                VkBuffer src, VkImage dst,
                                uint32_t width, uint32_t height) {
    // Barrier 1: UNDEFINED → TRANSFER_DST_OPTIMAL
    VkImageMemoryBarrier barrier1;
    memset(&barrier1, 0, sizeof(barrier1));
    barrier1.sType               = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier1.srcAccessMask       = 0;
    barrier1.dstAccessMask       = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier1.oldLayout           = VK_IMAGE_LAYOUT_UNDEFINED;
    barrier1.newLayout           = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier1.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier1.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier1.image               = dst;
    barrier1.subresourceRange.aspectMask     = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier1.subresourceRange.baseMipLevel   = 0;
    barrier1.subresourceRange.levelCount     = 1;
    barrier1.subresourceRange.baseArrayLayer = 0;
    barrier1.subresourceRange.layerCount     = 1;

    vkCmdPipelineBarrier(cmd,
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
        0, 0, NULL, 0, NULL, 1, &barrier1);

    // Copy
    VkBufferImageCopy region;
    memset(&region, 0, sizeof(region));
    region.bufferOffset      = 0;
    region.bufferRowLength   = 0;   // tightly packed
    region.bufferImageHeight = 0;
    region.imageSubresource.aspectMask     = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.mipLevel       = 0;
    region.imageSubresource.baseArrayLayer = 0;
    region.imageSubresource.layerCount     = 1;
    region.imageOffset.x = 0; region.imageOffset.y = 0; region.imageOffset.z = 0;
    region.imageExtent.width  = width;
    region.imageExtent.height = height;
    region.imageExtent.depth  = 1;

    vkCmdCopyBufferToImage(cmd, src, dst,
                           VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);

    // Barrier 2: TRANSFER_DST_OPTIMAL → PRESENT_SRC_KHR
    VkImageMemoryBarrier barrier2;
    memset(&barrier2, 0, sizeof(barrier2));
    barrier2.sType               = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier2.srcAccessMask       = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier2.dstAccessMask       = 0;
    barrier2.oldLayout           = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier2.newLayout           = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    barrier2.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier2.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier2.image               = dst;
    barrier2.subresourceRange.aspectMask     = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier2.subresourceRange.baseMipLevel   = 0;
    barrier2.subresourceRange.levelCount     = 1;
    barrier2.subresourceRange.baseArrayLayer = 0;
    barrier2.subresourceRange.layerCount     = 1;

    vkCmdPipelineBarrier(cmd,
        VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        0, 0, NULL, 0, NULL, 1, &barrier2);
}

// ── Submit + present ──────────────────────────────────────────────────────────

VkResult CVKS_submitAndPresent(VkQueue         queue,
                                VkCommandBuffer cmd,
                                VkSemaphore     waitSemaphore,
                                VkSemaphore     signalSemaphore,
                                VkFence         fence,
                                VkSwapchainKHR  swapchain,
                                uint32_t        imageIndex) {
    VkPipelineStageFlags waitStage = VK_PIPELINE_STAGE_TRANSFER_BIT;

    VkSubmitInfo si;
    memset(&si, 0, sizeof(si));
    si.sType                = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    si.waitSemaphoreCount   = 1;
    si.pWaitSemaphores      = &waitSemaphore;
    si.pWaitDstStageMask    = &waitStage;
    si.commandBufferCount   = 1;
    si.pCommandBuffers      = &cmd;
    si.signalSemaphoreCount = 1;
    si.pSignalSemaphores    = &signalSemaphore;

    VkResult submitResult = vkQueueSubmit(queue, 1, &si, fence);
    if (submitResult != VK_SUCCESS) return submitResult;

    VkPresentInfoKHR pi;
    memset(&pi, 0, sizeof(pi));
    pi.sType              = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    pi.waitSemaphoreCount = 1;
    pi.pWaitSemaphores    = &signalSemaphore;
    pi.swapchainCount     = 1;
    pi.pSwapchains        = &swapchain;
    pi.pImageIndices      = &imageIndex;

    return vkQueuePresentKHR(queue, &pi);
}

// ── Disable buggy implicit overlay layers ─────────────────────────────────────
//
// Several game-overlay Vulkan layers auto-inject into every app via the Windows
// registry.  On machines where Twitch Studio is installed,
// VK_LAYER_Twitch_Overlay calls vkCreateFramebuffer with a null renderPass when
// hooking each swapchain image (once per image), and leaks the semaphores it
// creates — both surface as validation errors even though the application code
// is correct.  Set the layer's own disable env var before vkCreateInstance so
// the Vulkan loader skips it.
//
// Must be called before the first vkCreateInstance.

void CVKS_disableOverlayLayers(void) {
#ifdef _WIN32
    _putenv_s("DISABLE_TWITCH_VULKAN_OVERLAY",            "1");  // Twitch Studio
    _putenv_s("DISABLE_VK_LAYER_VALVE_steam_overlay_1",   "1");  // Steam overlay
    _putenv_s("DISABLE_VK_LAYER_VALVE_steam_fossilize_1", "1");  // Steam shader cache
    _putenv_s("DISABLE_VULKAN_OW_OVERLAY_LAYER",          "1");  // Overwolf overlay
    _putenv_s("DISABLE_VULKAN_OW_OBS_CAPTURE",            "1");  // Overwolf OBS capture
    _putenv_s("DISABLE_VULKAN_OBS_CAPTURE",               "1");  // OBS Studio
#endif
}
