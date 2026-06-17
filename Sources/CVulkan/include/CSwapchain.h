#ifndef CSWAPCHAIN_H
#define CSWAPCHAIN_H

#include <vulkan/vulkan_core.h>
#include <stdint.h>

// Record a buffer-to-image copy into an already-recording command buffer.
// Handles all required image-layout transitions:
//   UNDEFINED → TRANSFER_DST_OPTIMAL  (before copy)
//   TRANSFER_DST_OPTIMAL → PRESENT_SRC_KHR  (after copy)
void CVKS_cmdCopyBufferToImage(VkCommandBuffer cmd,
                                VkBuffer src,
                                VkImage  dst,
                                uint32_t width,
                                uint32_t height);

// Submit cmd with wait/signal semaphores + fence, then call vkQueuePresentKHR.
// waitSemaphore   = imageAvailableSemaphore (GPU waits before executing cmd)
// signalSemaphore = renderFinishedSemaphore (GPU signals when cmd is done)
// fence           = CPU fence for waitUntilCompleted()
VkResult CVKS_submitAndPresent(VkQueue         queue,
                                VkCommandBuffer cmd,
                                VkSemaphore     waitSemaphore,
                                VkSemaphore     signalSemaphore,
                                VkFence         fence,
                                VkSwapchainKHR  swapchain,
                                uint32_t        imageIndex);

// Disable known-buggy implicit Vulkan overlay layers (e.g. Twitch Studio) that
// call vkCreateFramebuffer with a null renderPass when hooking swapchain images,
// causing spurious validation errors.  Must be called before vkCreateInstance.
void CVKS_disableOverlayLayers(void);

#endif // CSWAPCHAIN_H
