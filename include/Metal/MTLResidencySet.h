#ifndef METAL_C_MTL_RESIDENCY_SET_H
#define METAL_C_MTL_RESIDENCY_SET_H
#include <Metal/MTLDefines.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLAllocation MTLAllocation;
typedef struct MTLAccelerationStructure MTLAccelerationStructure;
typedef struct MTLBuffer MTLBuffer;
typedef struct MTLTexture MTLTexture;
typedef struct MTLResidencySet MTLResidencySet;
typedef struct MTLResidencySetDescriptor MTLResidencySetDescriptor;
METAL_C_EXPORT MTLResidencySetDescriptor* MTLResidencySetDescriptorCreate(void);
METAL_C_EXPORT void MTLResidencySetDescriptorSetInitialCapacity(MTLResidencySetDescriptor* descriptor, size_t capacity);
METAL_C_EXPORT void MTLResidencySetAddAllocation(MTLResidencySet* residencySet, const MTLAllocation* allocation);
METAL_C_EXPORT void MTLResidencySetRemoveAllocation(MTLResidencySet* residencySet, const MTLAllocation* allocation);
METAL_C_EXPORT void MTLResidencySetAddBuffer(MTLResidencySet* residencySet, const MTLBuffer* buffer);
METAL_C_EXPORT void MTLResidencySetAddTexture(MTLResidencySet* residencySet, const MTLTexture* texture);
METAL_C_EXPORT void MTLResidencySetAddAccelerationStructure(MTLResidencySet* residencySet, const MTLAccelerationStructure* accelerationStructure);
METAL_C_EXPORT void MTLResidencySetCommit(MTLResidencySet* residencySet);
#ifdef __cplusplus
}
#endif
#endif
