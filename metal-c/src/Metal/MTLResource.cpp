#include "MetalCInternal.hpp"

extern "C" {
void MTLResourceSetLabel(MTLResource* resource, const char* label)
{
    if (resource != nullptr) native<MTL::Resource>(resource)->setLabel(nsString(label));
}
size_t MTLResourceGetAllocatedSize(const MTLResource* resource)
{
    return resource == nullptr ? 0 : native<MTL::Resource>(resource)->allocatedSize();
}
void* MTLBufferGetContents(MTLBuffer* buffer) { return buffer == nullptr ? nullptr : native<MTL::Buffer>(buffer)->contents(); }
size_t MTLBufferGetLength(const MTLBuffer* buffer) { return buffer == nullptr ? 0 : native<MTL::Buffer>(buffer)->length(); }
MTLGPUAddress MTLBufferGetGPUAddress(const MTLBuffer* buffer) { return buffer == nullptr ? 0 : native<MTL::Buffer>(buffer)->gpuAddress(); }
void MTLBufferDidModifyRange(MTLBuffer* buffer, MTLRange range)
{
    if (buffer != nullptr) native<MTL::Buffer>(buffer)->didModifyRange(NS::Range(range.location, range.length));
}

MTLTextureDescriptor* MTLTextureDescriptorCreate(void) { return cobject<MTLTextureDescriptor>(MTL::TextureDescriptor::alloc()->init()); }
MTLTextureDescriptor* MTLTextureDescriptorCreate2D(MTLPixelFormat format, size_t width, size_t height, bool mipmapped)
{
    auto* descriptor = MTL::TextureDescriptor::texture2DDescriptor(static_cast<MTL::PixelFormat>(format), width, height, mipmapped);
    if (descriptor != nullptr) descriptor->retain();
    return cobject<MTLTextureDescriptor>(descriptor);
}
void MTLTextureDescriptorSetTextureType(MTLTextureDescriptor* d, MTLTextureType v) { if (d) native<MTL::TextureDescriptor>(d)->setTextureType(static_cast<MTL::TextureType>(v)); }
void MTLTextureDescriptorSetPixelFormat(MTLTextureDescriptor* d, MTLPixelFormat v) { if (d) native<MTL::TextureDescriptor>(d)->setPixelFormat(static_cast<MTL::PixelFormat>(v)); }
void MTLTextureDescriptorSetWidth(MTLTextureDescriptor* d, size_t v) { if (d) native<MTL::TextureDescriptor>(d)->setWidth(v); }
void MTLTextureDescriptorSetHeight(MTLTextureDescriptor* d, size_t v) { if (d) native<MTL::TextureDescriptor>(d)->setHeight(v); }
void MTLTextureDescriptorSetDepth(MTLTextureDescriptor* d, size_t v) { if (d) native<MTL::TextureDescriptor>(d)->setDepth(v); }
void MTLTextureDescriptorSetArrayLength(MTLTextureDescriptor* d, size_t v) { if (d) native<MTL::TextureDescriptor>(d)->setArrayLength(v); }
void MTLTextureDescriptorSetMipmapLevelCount(MTLTextureDescriptor* d, size_t v) { if (d) native<MTL::TextureDescriptor>(d)->setMipmapLevelCount(v); }
void MTLTextureDescriptorSetResourceOptions(MTLTextureDescriptor* d, MTLResourceOptions v) { if (d) native<MTL::TextureDescriptor>(d)->setResourceOptions(static_cast<MTL::ResourceOptions>(v)); }
void MTLTextureDescriptorSetUsage(MTLTextureDescriptor* d, MTLTextureUsage v) { if (d) native<MTL::TextureDescriptor>(d)->setUsage(static_cast<MTL::TextureUsage>(v)); }
size_t MTLTextureGetWidth(const MTLTexture* t) { return t ? native<MTL::Texture>(t)->width() : 0; }
size_t MTLTextureGetHeight(const MTLTexture* t) { return t ? native<MTL::Texture>(t)->height() : 0; }
size_t MTLTextureGetDepth(const MTLTexture* t) { return t ? native<MTL::Texture>(t)->depth() : 0; }
MTLPixelFormat MTLTextureGetPixelFormat(const MTLTexture* t) { return t ? static_cast<MTLPixelFormat>(native<MTL::Texture>(t)->pixelFormat()) : MTLPixelFormatInvalid; }
MTLResourceID MTLTextureGetGPUResourceID(const MTLTexture* t) { return t ? native<MTL::Texture>(t)->gpuResourceID()._impl : 0; }
void MTLTextureReplaceRegion(MTLTexture* t, MTLRegion region, size_t level, size_t slice, const void* bytes, size_t row, size_t image)
{
    if (t) native<MTL::Texture>(t)->replaceRegion(nativeRegion(region), level, slice, bytes, row, image);
}

size_t MTLAccelerationStructureGetSize(const MTLAccelerationStructure* a) { return a ? native<MTL::AccelerationStructure>(a)->size() : 0; }
MTLResourceID MTLAccelerationStructureGetGPUResourceID(const MTLAccelerationStructure* a) { return a ? native<MTL::AccelerationStructure>(a)->gpuResourceID()._impl : 0; }
size_t MTLComputePipelineStateGetThreadExecutionWidth(const MTLComputePipelineState* p) { return p ? native<MTL::ComputePipelineState>(p)->threadExecutionWidth() : 0; }
size_t MTLComputePipelineStateGetMaxTotalThreadsPerThreadgroup(const MTLComputePipelineState* p) { return p ? native<MTL::ComputePipelineState>(p)->maxTotalThreadsPerThreadgroup() : 0; }
void MTLDrawablePresent(MTLDrawable* d) { if (d) native<MTL::Drawable>(d)->present(); }
uint64_t MTLSharedEventGetSignaledValue(const MTLSharedEvent* e) { return e ? native<MTL::SharedEvent>(e)->signaledValue() : 0; }
bool MTLSharedEventWaitUntilSignaledValue(MTLSharedEvent* e, uint64_t value, uint64_t timeoutMS) { return e && native<MTL::SharedEvent>(e)->waitUntilSignaledValue(value, timeoutMS); }
}
