#ifndef METAL_C_MTL_COMPUTE_PIPELINE_H
#define METAL_C_MTL_COMPUTE_PIPELINE_H

#include <Metal/MTLDefines.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLComputePipelineState MTLComputePipelineState;
METAL_C_EXPORT size_t MTLComputePipelineStateGetThreadExecutionWidth(const MTLComputePipelineState* state);
METAL_C_EXPORT size_t MTLComputePipelineStateGetMaxTotalThreadsPerThreadgroup(const MTLComputePipelineState* state);
#ifdef __cplusplus
}
#endif
#endif
