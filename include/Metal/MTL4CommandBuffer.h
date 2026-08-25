#ifndef METAL_C_MTL4_COMMAND_BUFFER_H
#define METAL_C_MTL4_COMMAND_BUFFER_H
#include <Metal/MTL4CommandAllocator.h>
#include <Metal/MTLResidencySet.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4CommandBuffer MTL4CommandBuffer;
typedef struct MTL4ComputeCommandEncoder MTL4ComputeCommandEncoder;
METAL_C_EXPORT void MTL4CommandBufferBegin(MTL4CommandBuffer* commandBuffer, const MTL4CommandAllocator* allocator);
METAL_C_EXPORT MTL4ComputeCommandEncoder* MTL4CommandBufferGetComputeCommandEncoder(MTL4CommandBuffer* commandBuffer);
METAL_C_EXPORT void MTL4CommandBufferUseResidencySet(MTL4CommandBuffer* commandBuffer, const MTLResidencySet* residencySet);
METAL_C_EXPORT void MTL4CommandBufferEnd(MTL4CommandBuffer* commandBuffer);
#ifdef __cplusplus
}
#endif
#endif
