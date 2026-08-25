#ifndef METAL_C_MTL4_COMPUTE_PIPELINE_H
#define METAL_C_MTL4_COMPUTE_PIPELINE_H
#include <Metal/MTL4LibraryFunctionDescriptor.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4ComputePipelineDescriptor MTL4ComputePipelineDescriptor;
METAL_C_EXPORT MTL4ComputePipelineDescriptor* MTL4ComputePipelineDescriptorCreate(void);
METAL_C_EXPORT void MTL4ComputePipelineDescriptorSetComputeFunctionDescriptor(MTL4ComputePipelineDescriptor* descriptor, const MTL4LibraryFunctionDescriptor* function);
METAL_C_EXPORT void MTL4ComputePipelineDescriptorSetMaxTotalThreadsPerThreadgroup(MTL4ComputePipelineDescriptor* descriptor, size_t count);
#ifdef __cplusplus
}
#endif
#endif
