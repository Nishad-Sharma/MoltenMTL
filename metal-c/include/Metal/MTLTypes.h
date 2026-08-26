#pragma once

#include <Metal/MTLDefines.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint64_t MTLGPUAddress;
typedef uint64_t MTLResourceID;

typedef struct MTLOrigin { size_t x, y, z; } MTLOrigin;
typedef struct MTLSize { size_t width, height, depth; } MTLSize;
typedef struct MTLRange { size_t location, length; } MTLRange;
typedef struct MTLRegion { MTLOrigin origin; MTLSize size; } MTLRegion;
typedef struct MTLPackedFloat4x3 { float columns[4][3]; } MTLPackedFloat4x3;

static inline MTLOrigin MTLOriginMake(size_t x, size_t y, size_t z) { MTLOrigin value = {x, y, z}; return value; }
static inline MTLSize MTLSizeMake(size_t width, size_t height, size_t depth) { MTLSize value = {width, height, depth}; return value; }
static inline MTLRange MTLRangeMake(size_t location, size_t length) { MTLRange value = {location, length}; return value; }
static inline MTLRegion MTLRegionMake3D(size_t x, size_t y, size_t z, size_t width, size_t height, size_t depth) {
    MTLRegion value = {MTLOriginMake(x, y, z), MTLSizeMake(width, height, depth)}; return value;
}

MTL_C_OPTIONS(uint64_t, MTLStages) {
    MTLStageVertex = 1,
    MTLStageFragment = 1 << 1,
    MTLStageTile = 1 << 2,
    MTLStageObject = 1 << 3,
    MTLStageMesh = 1 << 4,
    MTLStageResourceState = 1 << 26,
    MTLStageDispatch = 1 << 27,
    MTLStageBlit = 1 << 28,
    MTLStageAccelerationStructure = 1 << 29
};
#define MTLStageAll ((MTLStages)UINT64_C(0x7fffffffffffffff))

MTL_C_ENUM(uint64_t, MTLIndexType) {
    MTLIndexTypeUInt16 = 0,
    MTLIndexTypeUInt32 = 1
};
MTL_C_ENUM(uint64_t, MTLAttributeFormat) {
    MTLAttributeFormatInvalid = 0,
    MTLAttributeFormatFloat = 28,
    MTLAttributeFormatFloat2 = 29,
    MTLAttributeFormatFloat3 = 30,
    MTLAttributeFormatFloat4 = 31
};

#ifdef __cplusplus
}
#endif
