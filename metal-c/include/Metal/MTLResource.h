#pragma once

#include <Metal/MTLDefines.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MTLResource MTLResource;
MTL_C_OPTIONS(uint64_t, MTLResourceOptions) {
    MTLResourceCPUCacheModeDefaultCache = 0,
    MTLResourceCPUCacheModeWriteCombined = 1,
    MTLResourceStorageModeShared = 0,
    MTLResourceStorageModeManaged = 0x10,
    MTLResourceStorageModePrivate = 0x20,
    MTLResourceStorageModeMemoryless = 0x30,
    MTLResourceHazardTrackingModeDefault = 0,
    MTLResourceHazardTrackingModeUntracked = 0x100,
    MTLResourceHazardTrackingModeTracked = 0x200
};

METAL_C_EXPORT void MTLResourceSetLabel(MTLResource* resource, const char* label);
METAL_C_EXPORT size_t MTLResourceGetAllocatedSize(const MTLResource* resource);

#ifdef __cplusplus
}
#endif
