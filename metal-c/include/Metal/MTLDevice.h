#pragma once

#include <Metal/MTLAccelerationStructure.h>
#include <Metal/MTLBuffer.h>
#include <Foundation/NSError.h>
#include <Metal/MTLEvent.h>
#include <Metal/MTLResidencySet.h>
#include <Metal/MTLTexture.h>

#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLDevice MTLDevice;
typedef struct MTL4AccelerationStructureDescriptor MTL4AccelerationStructureDescriptor;
typedef struct MTL4ArgumentTable MTL4ArgumentTable;
typedef struct MTL4ArgumentTableDescriptor MTL4ArgumentTableDescriptor;
typedef struct MTL4CommandAllocator MTL4CommandAllocator;
typedef struct MTL4CommandBuffer MTL4CommandBuffer;
typedef struct MTL4CommandQueue MTL4CommandQueue;
typedef struct MTL4Compiler MTL4Compiler;
typedef struct MTL4CompilerDescriptor MTL4CompilerDescriptor;
typedef struct MTLAccelerationStructureSizes { size_t accelerationStructureSize, buildScratchBufferSize, refitScratchBufferSize; } MTLAccelerationStructureSizes;

METAL_C_EXPORT MTLDevice* MTLDeviceCreateSystemDefault(void);
METAL_C_EXPORT const char* MTLDeviceGetName(const MTLDevice* device);
METAL_C_EXPORT bool MTLDeviceSupportsMetal4(const MTLDevice* device);
METAL_C_EXPORT MTLBuffer* MTLDeviceCreateBuffer(MTLDevice* device, size_t length, MTLResourceOptions options);
METAL_C_EXPORT MTLBuffer* MTLDeviceCreateBufferWithBytes(MTLDevice* device, const void* bytes, size_t length, MTLResourceOptions options);
METAL_C_EXPORT MTLTexture* MTLDeviceCreateTexture(MTLDevice* device, const MTLTextureDescriptor* descriptor);
METAL_C_EXPORT MTL4CommandAllocator* MTLDeviceCreateCommandAllocator(MTLDevice* device);
METAL_C_EXPORT MTL4CommandBuffer* MTLDeviceCreateCommandBuffer(MTLDevice* device);
METAL_C_EXPORT MTL4CommandQueue* MTLDeviceCreateMTL4CommandQueue(MTLDevice* device);
METAL_C_EXPORT MTL4Compiler* MTLDeviceCreateCompiler(MTLDevice* device, const MTL4CompilerDescriptor* descriptor, NSError** error);
METAL_C_EXPORT MTL4ArgumentTable* MTLDeviceCreateArgumentTable(MTLDevice* device, const MTL4ArgumentTableDescriptor* descriptor, NSError** error);
METAL_C_EXPORT MTLAccelerationStructureSizes MTLDeviceGetAccelerationStructureSizes(MTLDevice* device, const MTL4AccelerationStructureDescriptor* descriptor);
METAL_C_EXPORT MTLAccelerationStructure* MTLDeviceCreateAccelerationStructure(MTLDevice* device, size_t size);
METAL_C_EXPORT MTLResidencySet* MTLDeviceCreateResidencySet(MTLDevice* device, const MTLResidencySetDescriptor* descriptor, NSError** error);
METAL_C_EXPORT MTLSharedEvent* MTLDeviceCreateSharedEvent(MTLDevice* device);
#ifdef __cplusplus
}
#endif
