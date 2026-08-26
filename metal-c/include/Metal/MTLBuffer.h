#pragma once

#include <Metal/MTLResource.h>
#include <Metal/MTLTypes.h>

#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLBuffer MTLBuffer;
METAL_C_EXPORT void* MTLBufferGetContents(MTLBuffer* buffer);
METAL_C_EXPORT size_t MTLBufferGetLength(const MTLBuffer* buffer);
METAL_C_EXPORT MTLGPUAddress MTLBufferGetGPUAddress(const MTLBuffer* buffer);
METAL_C_EXPORT void MTLBufferDidModifyRange(MTLBuffer* buffer, MTLRange range);
#ifdef __cplusplus
}
#endif
