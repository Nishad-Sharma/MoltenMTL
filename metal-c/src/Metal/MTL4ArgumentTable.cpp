#include "MetalCInternal.hpp"

extern "C" {
MTL4ArgumentTableDescriptor* MTL4ArgumentTableDescriptorCreate(void) { return cobject<MTL4ArgumentTableDescriptor>(MTL4::ArgumentTableDescriptor::alloc()->init()); }
void MTL4ArgumentTableDescriptorSetMaxBufferBindCount(MTL4ArgumentTableDescriptor* d, size_t v) { if (d) native<MTL4::ArgumentTableDescriptor>(d)->setMaxBufferBindCount(v); }
void MTL4ArgumentTableDescriptorSetMaxTextureBindCount(MTL4ArgumentTableDescriptor* d, size_t v) { if (d) native<MTL4::ArgumentTableDescriptor>(d)->setMaxTextureBindCount(v); }
void MTL4ArgumentTableDescriptorSetInitializeBindings(MTL4ArgumentTableDescriptor* d, bool v) { if (d) native<MTL4::ArgumentTableDescriptor>(d)->setInitializeBindings(v); }
void MTL4ArgumentTableSetAddress(MTL4ArgumentTable* t, MTLGPUAddress address, size_t i) { if (t) native<MTL4::ArgumentTable>(t)->setAddress(address, i); }
void MTL4ArgumentTableSetBuffer(MTL4ArgumentTable* t, const MTLBuffer* b, size_t offset, size_t i) { if (t && b) native<MTL4::ArgumentTable>(t)->setAddress(native<MTL::Buffer>(b)->gpuAddress() + offset, i); }
void MTL4ArgumentTableSetTexture(MTL4ArgumentTable* t, const MTLTexture* texture, size_t i) { if (t && texture) native<MTL4::ArgumentTable>(t)->setTexture(native<MTL::Texture>(texture)->gpuResourceID(), i); }
void MTL4ArgumentTableSetAccelerationStructure(MTL4ArgumentTable* t, const MTLAccelerationStructure* a, size_t i) { if (t && a) native<MTL4::ArgumentTable>(t)->setResource(native<MTL::AccelerationStructure>(a)->gpuResourceID(), i); }
}
