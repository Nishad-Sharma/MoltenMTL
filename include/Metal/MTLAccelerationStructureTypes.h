#ifndef METAL_C_MTL_ACCELERATION_STRUCTURE_TYPES_H
#define METAL_C_MTL_ACCELERATION_STRUCTURE_TYPES_H

#include <Metal/MTLTypes.h>

MTL_C_OPTIONS(uint64_t, MTLAccelerationStructureUsage) {
    MTLAccelerationStructureUsageNone = 0,
    MTLAccelerationStructureUsageRefit = 1,
    MTLAccelerationStructureUsagePreferFastBuild = 2,
    MTLAccelerationStructureUsageExtendedLimits = 4,
    MTLAccelerationStructureUsagePreferFastIntersection = 16,
    MTLAccelerationStructureUsageMinimizeMemory = 32
};

MTL_C_ENUM(uint64_t, MTLAccelerationStructureInstanceDescriptorType) {
    MTLAccelerationStructureInstanceDescriptorTypeDefault = 0,
    MTLAccelerationStructureInstanceDescriptorTypeUserID = 1,
    MTLAccelerationStructureInstanceDescriptorTypeIndirect = 3
};

MTL_C_OPTIONS(uint32_t, MTLAccelerationStructureInstanceOptions) {
    MTLAccelerationStructureInstanceOptionNone = 0,
    MTLAccelerationStructureInstanceOptionDisableTriangleCulling = 1,
    MTLAccelerationStructureInstanceOptionTriangleFrontFacingWindingCounterClockwise = 2,
    MTLAccelerationStructureInstanceOptionOpaque = 4,
    MTLAccelerationStructureInstanceOptionNonOpaque = 8
};

#pragma pack(push, 1)
typedef struct MTLAccelerationStructureInstanceDescriptor {
    MTLPackedFloat4x3 transformationMatrix;
    MTLAccelerationStructureInstanceOptions options;
    uint32_t mask;
    uint32_t intersectionFunctionTableOffset;
    uint32_t accelerationStructureIndex;
} MTLAccelerationStructureInstanceDescriptor;
typedef struct MTLAccelerationStructureUserIDInstanceDescriptor {
    MTLPackedFloat4x3 transformationMatrix;
    MTLAccelerationStructureInstanceOptions options;
    uint32_t mask;
    uint32_t intersectionFunctionTableOffset;
    uint32_t accelerationStructureIndex;
    uint32_t userID;
} MTLAccelerationStructureUserIDInstanceDescriptor;
typedef struct MTLIndirectAccelerationStructureInstanceDescriptor {
    MTLPackedFloat4x3 transformationMatrix;
    MTLAccelerationStructureInstanceOptions options;
    uint32_t mask;
    uint32_t intersectionFunctionTableOffset;
    uint32_t userID;
    MTLResourceID accelerationStructureID;
} MTLIndirectAccelerationStructureInstanceDescriptor;
#pragma pack(pop)

#endif
