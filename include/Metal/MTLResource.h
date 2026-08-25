#ifndef METAL_C_MTL_RESOURCE_H
#define METAL_C_MTL_RESOURCE_H

#include <Metal/MTLDefines.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MTLResource MTLResource;
typedef uint64_t MTLResourceOptions;
#define MTLResourceCPUCacheModeDefaultCache ((MTLResourceOptions)0)
#define MTLResourceCPUCacheModeWriteCombined ((MTLResourceOptions)1)
#define MTLResourceStorageModeShared ((MTLResourceOptions)0)
#define MTLResourceStorageModeManaged ((MTLResourceOptions)0x10)
#define MTLResourceStorageModePrivate ((MTLResourceOptions)0x20)
#define MTLResourceStorageModeMemoryless ((MTLResourceOptions)0x30)
#define MTLResourceHazardTrackingModeDefault ((MTLResourceOptions)0)
#define MTLResourceHazardTrackingModeUntracked ((MTLResourceOptions)0x100)
#define MTLResourceHazardTrackingModeTracked ((MTLResourceOptions)0x200)

METAL_C_EXPORT void MTLResourceSetLabel(MTLResource* resource, const char* label);
METAL_C_EXPORT size_t MTLResourceGetAllocatedSize(const MTLResource* resource);

#ifdef __cplusplus
}
#endif
#endif
