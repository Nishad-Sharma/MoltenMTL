#pragma once

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
