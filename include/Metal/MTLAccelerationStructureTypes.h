#ifndef METAL_C_MTL_ACCELERATION_STRUCTURE_TYPES_H
#define METAL_C_MTL_ACCELERATION_STRUCTURE_TYPES_H

#include <Metal/MTLTypes.h>

typedef uint64_t MTLAccelerationStructureUsage;
#define MTLAccelerationStructureUsageNone ((MTLAccelerationStructureUsage)0)
#define MTLAccelerationStructureUsageRefit ((MTLAccelerationStructureUsage)1)
#define MTLAccelerationStructureUsagePreferFastBuild ((MTLAccelerationStructureUsage)2)
#define MTLAccelerationStructureUsageExtendedLimits ((MTLAccelerationStructureUsage)4)
#define MTLAccelerationStructureUsagePreferFastIntersection ((MTLAccelerationStructureUsage)16)
#define MTLAccelerationStructureUsageMinimizeMemory ((MTLAccelerationStructureUsage)32)

typedef enum MTLAccelerationStructureInstanceDescriptorType {
    MTLAccelerationStructureInstanceDescriptorTypeDefault = 0,
    MTLAccelerationStructureInstanceDescriptorTypeUserID = 1,
    MTLAccelerationStructureInstanceDescriptorTypeIndirect = 3
} MTLAccelerationStructureInstanceDescriptorType;

typedef uint32_t MTLAccelerationStructureInstanceOptions;
#define MTLAccelerationStructureInstanceOptionNone ((MTLAccelerationStructureInstanceOptions)0)
#define MTLAccelerationStructureInstanceOptionDisableTriangleCulling ((MTLAccelerationStructureInstanceOptions)1)
#define MTLAccelerationStructureInstanceOptionTriangleFrontFacingWindingCounterClockwise ((MTLAccelerationStructureInstanceOptions)2)
#define MTLAccelerationStructureInstanceOptionOpaque ((MTLAccelerationStructureInstanceOptions)4)
#define MTLAccelerationStructureInstanceOptionNonOpaque ((MTLAccelerationStructureInstanceOptions)8)

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
