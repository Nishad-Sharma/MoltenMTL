#ifndef METAL_C_MTL4_COMPUTE_COMMAND_ENCODER_H
#define METAL_C_MTL4_COMPUTE_COMMAND_ENCODER_H
#include <Metal/MTL4ArgumentTable.h>
#include <Metal/MTL4CommandEncoder.h>
#include <Metal/MTL4ComputePipeline.h>
#include <Metal/MTLComputePipeline.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4AccelerationStructureDescriptor MTL4AccelerationStructureDescriptor;
typedef struct MTL4ComputeCommandEncoder MTL4ComputeCommandEncoder;
typedef struct MTL4BufferRange { MTLGPUAddress address; size_t length; } MTL4BufferRange;
METAL_C_EXPORT MTL4BufferRange MTL4BufferRangeMake(const MTLBuffer* buffer, size_t offset, size_t length);
METAL_C_EXPORT void MTL4ComputeCommandEncoderSetComputePipelineState(MTL4ComputeCommandEncoder* encoder, const MTLComputePipelineState* state);
METAL_C_EXPORT void MTL4ComputeCommandEncoderSetArgumentTable(MTL4ComputeCommandEncoder* encoder, const MTL4ArgumentTable* table);
METAL_C_EXPORT void MTL4ComputeCommandEncoderBarrierAfterEncoderStages(MTL4ComputeCommandEncoder* encoder, MTLStages after, MTLStages before, MTL4VisibilityOptions visibility);
METAL_C_EXPORT void MTL4ComputeCommandEncoderEndEncoding(MTL4ComputeCommandEncoder* encoder);
METAL_C_EXPORT void MTL4ComputeCommandEncoderDispatchThreads(MTL4ComputeCommandEncoder* encoder, MTLSize threadsPerGrid, MTLSize threadsPerThreadgroup);
METAL_C_EXPORT void MTL4ComputeCommandEncoderDispatchThreadgroups(MTL4ComputeCommandEncoder* encoder, MTLSize threadgroupsPerGrid, MTLSize threadsPerThreadgroup);
METAL_C_EXPORT void MTL4ComputeCommandEncoderCopyBuffer(MTL4ComputeCommandEncoder* encoder, const MTLBuffer* source, size_t sourceOffset, const MTLBuffer* destination, size_t destinationOffset, size_t size);
METAL_C_EXPORT void MTL4ComputeCommandEncoderCopyBufferToTexture(MTL4ComputeCommandEncoder* encoder, const MTLBuffer* source, size_t sourceOffset, size_t sourceBytesPerRow, size_t sourceBytesPerImage, MTLSize sourceSize, const MTLTexture* destination, size_t destinationSlice, size_t destinationLevel, MTLOrigin destinationOrigin);
METAL_C_EXPORT void MTL4ComputeCommandEncoderBuildAccelerationStructure(MTL4ComputeCommandEncoder* encoder, const MTLAccelerationStructure* accelerationStructure, const MTL4AccelerationStructureDescriptor* descriptor, MTL4BufferRange scratchBuffer);
METAL_C_EXPORT void MTL4ComputeCommandEncoderRefitAccelerationStructure(MTL4ComputeCommandEncoder* encoder, const MTLAccelerationStructure* source, const MTL4AccelerationStructureDescriptor* descriptor, const MTLAccelerationStructure* destination, MTL4BufferRange scratchBuffer);
#ifdef __cplusplus
}
#endif
#endif
