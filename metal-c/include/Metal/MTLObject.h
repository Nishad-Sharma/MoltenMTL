#ifndef METAL_C_MTL_OBJECT_H
#define METAL_C_MTL_OBJECT_H

#include <Metal/MTLDefines.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MTLAutoreleasePool MTLAutoreleasePool;

METAL_C_EXPORT MTLAutoreleasePool* MTLAutoreleasePoolCreate(void);
METAL_C_EXPORT void* MTLRetain(void* object);
METAL_C_EXPORT void MTLRelease(void* object);

#ifdef __cplusplus
}
#endif

#endif
