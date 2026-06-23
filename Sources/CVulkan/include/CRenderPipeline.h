#ifndef CRENDERPIPELINE_H
#define CRENDERPIPELINE_H

#include <vulkan/vulkan_core.h>
#include <stdint.h>

// Creates a graphics pipeline for the render-encoder path (dynamic rendering).
// VkGraphicsPipelineCreateInfo chains ~10 sub-structs with pointer lifetimes,
// so it is assembled here in C rather than via Swift pointer-pinning.
//
// Fixed state: triangle-list topology, no culling, fill mode, single-sampled,
// dynamic viewport + scissor, one color attachment whose format is supplied via
// VkPipelineRenderingCreateInfo (dynamic rendering, no VkRenderPass). The blend
// state is fully resolved by the Swift caller.
//
// Depth/stencil: the pipeline always declares depth and stencil test/write/
// compare/op as dynamic state (set per-encoder via vkCmdSetDepth*/vkCmdSetStencil*).
// Pass depthFormat / stencilFormat = VK_FORMAT_UNDEFINED for depth-less / stencil-less
// rendering, or a format to render with that attachment.
VkResult CVKR_createGraphicsPipeline(
    VkDevice        device,
    VkShaderModule  vertModule, const char* vertEntry,
    VkShaderModule  fragModule, const char* fragEntry,
    const VkVertexInputBindingDescription*   bindings, uint32_t bindingCount,
    const VkVertexInputAttributeDescription* attribs,  uint32_t attribCount,
    VkFormat        colorFormat,
    VkFormat        depthFormat,
    VkFormat        stencilFormat,
    const VkPipelineColorBlendAttachmentState* blend,
    VkPipelineLayout layout,
    VkPipeline*      outPipeline);

#endif // CRENDERPIPELINE_H
