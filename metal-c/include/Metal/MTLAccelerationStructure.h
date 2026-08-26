#pragma once

#include <Metal/MTLDefines.h>
#include <Metal/MTLTypes.h>

#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLAccelerationStructure MTLAccelerationStructure;
METAL_C_EXPORT size_t MTLAccelerationStructureGetSize(const MTLAccelerationStructure* accelerationStructure);
METAL_C_EXPORT MTLResourceID MTLAccelerationStructureGetGPUResourceID(const MTLAccelerationStructure* accelerationStructure);
#ifdef __cplusplus
}
#endif
