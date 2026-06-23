#include "include/CRenderPipeline.h"

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
    VkPipeline*      outPipeline)
{
    VkPipelineShaderStageCreateInfo stages[2] = {0};
    stages[0].sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[0].stage  = VK_SHADER_STAGE_VERTEX_BIT;
    stages[0].module = vertModule;
    stages[0].pName  = vertEntry;
    stages[1].sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[1].stage  = VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1].module = fragModule;
    stages[1].pName  = fragEntry;

    VkPipelineVertexInputStateCreateInfo vertexInput = {0};
    vertexInput.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertexInput.vertexBindingDescriptionCount   = bindingCount;
    vertexInput.pVertexBindingDescriptions     = bindings;
    vertexInput.vertexAttributeDescriptionCount = attribCount;
    vertexInput.pVertexAttributeDescriptions   = attribs;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly = {0};
    inputAssembly.sType    = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    // Counts only - actual viewport/scissor are dynamic state.
    VkPipelineViewportStateCreateInfo viewportState = {0};
    viewportState.sType         = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewportState.viewportCount = 1;
    viewportState.scissorCount  = 1;

    VkPipelineRasterizationStateCreateInfo rasterization = {0};
    rasterization.sType       = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterization.polygonMode = VK_POLYGON_MODE_FILL;
    rasterization.cullMode    = VK_CULL_MODE_NONE;
    rasterization.frontFace   = VK_FRONT_FACE_COUNTER_CLOCKWISE;
    rasterization.lineWidth   = 1.0f;

    VkPipelineMultisampleStateCreateInfo multisample = {0};
    multisample.sType                = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisample.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

    VkPipelineColorBlendStateCreateInfo colorBlend = {0};
    colorBlend.sType           = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    colorBlend.attachmentCount = 1;
    colorBlend.pAttachments    = blend;

    // Viewport/scissor are always dynamic; cull mode + front face and depth/stencil
    // test/write/compare/op are dynamic so a single pipeline honours whatever the
    // encoder binds (MTLCullMode / winding / MTLDepthStencilState / stencil reference).
    VkDynamicState dynamicStates[12] = {
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_SCISSOR,
        VK_DYNAMIC_STATE_CULL_MODE,
        VK_DYNAMIC_STATE_FRONT_FACE,
        VK_DYNAMIC_STATE_DEPTH_TEST_ENABLE,
        VK_DYNAMIC_STATE_DEPTH_WRITE_ENABLE,
        VK_DYNAMIC_STATE_DEPTH_COMPARE_OP,
        VK_DYNAMIC_STATE_STENCIL_TEST_ENABLE,
        VK_DYNAMIC_STATE_STENCIL_OP,
        VK_DYNAMIC_STATE_STENCIL_COMPARE_MASK,
        VK_DYNAMIC_STATE_STENCIL_WRITE_MASK,
        VK_DYNAMIC_STATE_STENCIL_REFERENCE
    };
    VkPipelineDynamicStateCreateInfo dynamicState = {0};
    dynamicState.sType             = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamicState.dynamicStateCount = 12;
    dynamicState.pDynamicStates    = dynamicStates;

    // Static depth/stencil values are placeholders — test/write/compare/op fields
    // above are all dynamic. Depth-bounds testing is unused. Providing this struct
    // is harmless when depthFormat/stencilFormat are VK_FORMAT_UNDEFINED.
    VkPipelineDepthStencilStateCreateInfo depthStencil = {0};
    depthStencil.sType             = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
    depthStencil.depthTestEnable   = VK_TRUE;
    depthStencil.depthWriteEnable  = VK_TRUE;
    depthStencil.depthCompareOp    = VK_COMPARE_OP_LESS_OR_EQUAL;
    depthStencil.stencilTestEnable = VK_TRUE;

    VkPipelineRenderingCreateInfo rendering = {0};
    rendering.sType                   = VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
    rendering.colorAttachmentCount    = 1;
    rendering.pColorAttachmentFormats = &colorFormat;
    rendering.depthAttachmentFormat   = depthFormat;
    rendering.stencilAttachmentFormat = stencilFormat;

    VkGraphicsPipelineCreateInfo ci = {0};
    ci.sType               = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    ci.pNext               = &rendering;
    ci.stageCount          = 2;
    ci.pStages             = stages;
    ci.pVertexInputState   = &vertexInput;
    ci.pInputAssemblyState = &inputAssembly;
    ci.pViewportState      = &viewportState;
    ci.pRasterizationState = &rasterization;
    ci.pMultisampleState   = &multisample;
    ci.pDepthStencilState  = &depthStencil;
    ci.pColorBlendState    = &colorBlend;
    ci.pDynamicState       = &dynamicState;
    ci.layout              = layout;

    return vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &ci, NULL, outPipeline);
}
