#ifndef METAL_C_MTL_DEVICE_H
#define METAL_C_MTL_DEVICE_H

#include <Metal/MTLAccelerationStructure.h>
#include <Metal/MTLBuffer.h>
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

METAL_C_EXPORT MTLDevice* MTLCreateSystemDefaultDevice(void);
METAL_C_EXPORT const char* MTLDeviceGetName(const MTLDevice* device);
METAL_C_EXPORT bool MTLDeviceSupportsMetal4(const MTLDevice* device);
METAL_C_EXPORT MTLBuffer* MTLDeviceNewBuffer(MTLDevice* device, size_t length, MTLResourceOptions options);
METAL_C_EXPORT MTLBuffer* MTLDeviceNewBufferWithBytes(MTLDevice* device, const void* bytes, size_t length, MTLResourceOptions options);
METAL_C_EXPORT MTLTexture* MTLDeviceNewTexture(MTLDevice* device, const MTLTextureDescriptor* descriptor);
METAL_C_EXPORT MTL4CommandAllocator* MTLDeviceNewCommandAllocator(MTLDevice* device);
METAL_C_EXPORT MTL4CommandBuffer* MTLDeviceNewCommandBuffer(MTLDevice* device);
METAL_C_EXPORT MTL4CommandQueue* MTLDeviceNewMTL4CommandQueue(MTLDevice* device);
METAL_C_EXPORT MTL4Compiler* MTLDeviceNewCompiler(MTLDevice* device, const MTL4CompilerDescriptor* descriptor, MTLError** error);
METAL_C_EXPORT MTL4ArgumentTable* MTLDeviceNewArgumentTable(MTLDevice* device, const MTL4ArgumentTableDescriptor* descriptor, MTLError** error);
METAL_C_EXPORT MTLAccelerationStructureSizes MTLDeviceGetAccelerationStructureSizes(MTLDevice* device, const MTL4AccelerationStructureDescriptor* descriptor);
METAL_C_EXPORT MTLAccelerationStructure* MTLDeviceNewAccelerationStructure(MTLDevice* device, size_t size);
METAL_C_EXPORT MTLResidencySet* MTLDeviceNewResidencySet(MTLDevice* device, const MTLResidencySetDescriptor* descriptor, MTLError** error);
METAL_C_EXPORT MTLSharedEvent* MTLDeviceNewSharedEvent(MTLDevice* device);
#ifdef __cplusplus
}
#endif
#endif
