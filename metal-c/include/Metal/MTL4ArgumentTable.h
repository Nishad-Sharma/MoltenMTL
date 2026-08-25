#ifndef METAL_C_MTL4_ARGUMENT_TABLE_H
#define METAL_C_MTL4_ARGUMENT_TABLE_H
#include <Metal/MTLAccelerationStructure.h>
#include <Metal/MTLBuffer.h>
#include <Metal/MTLTexture.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4ArgumentTable MTL4ArgumentTable;
typedef struct MTL4ArgumentTableDescriptor MTL4ArgumentTableDescriptor;
METAL_C_EXPORT MTL4ArgumentTableDescriptor* MTL4ArgumentTableDescriptorCreate(void);
METAL_C_EXPORT void MTL4ArgumentTableDescriptorSetMaxBufferBindCount(MTL4ArgumentTableDescriptor* descriptor, size_t count);
METAL_C_EXPORT void MTL4ArgumentTableDescriptorSetMaxTextureBindCount(MTL4ArgumentTableDescriptor* descriptor, size_t count);
METAL_C_EXPORT void MTL4ArgumentTableDescriptorSetInitializeBindings(MTL4ArgumentTableDescriptor* descriptor, bool initialize);
METAL_C_EXPORT void MTL4ArgumentTableSetAddress(MTL4ArgumentTable* table, MTLGPUAddress address, size_t bindingIndex);
METAL_C_EXPORT void MTL4ArgumentTableSetBuffer(MTL4ArgumentTable* table, const MTLBuffer* buffer, size_t offset, size_t bindingIndex);
METAL_C_EXPORT void MTL4ArgumentTableSetTexture(MTL4ArgumentTable* table, const MTLTexture* texture, size_t bindingIndex);
METAL_C_EXPORT void MTL4ArgumentTableSetAccelerationStructure(MTL4ArgumentTable* table, const MTLAccelerationStructure* accelerationStructure, size_t bindingIndex);
#ifdef __cplusplus
}
#endif
#endif
