#ifndef METAL_C_MTL_TEXTURE_H
#define METAL_C_MTL_TEXTURE_H

#include <Metal/MTLPixelFormat.h>
#include <Metal/MTLResource.h>
#include <Metal/MTLTypes.h>

#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLTexture MTLTexture;
typedef struct MTLTextureDescriptor MTLTextureDescriptor;
MTL_C_ENUM(uint64_t, MTLTextureType) {
    MTLTextureType1D = 0,
    MTLTextureType1DArray = 1,
    MTLTextureType2D = 2,
    MTLTextureType2DArray = 3,
    MTLTextureTypeCube = 5,
    MTLTextureTypeCubeArray = 6,
    MTLTextureType3D = 7
};
MTL_C_OPTIONS(uint64_t, MTLTextureUsage) {
    MTLTextureUsageUnknown = 0,
    MTLTextureUsageShaderRead = 1,
    MTLTextureUsageShaderWrite = 2,
    MTLTextureUsageRenderTarget = 4,
    MTLTextureUsagePixelFormatView = 16
};

METAL_C_EXPORT MTLTextureDescriptor* MTLTextureDescriptorCreate(void);
METAL_C_EXPORT MTLTextureDescriptor* MTLTextureDescriptorCreate2D(MTLPixelFormat format, size_t width, size_t height, bool mipmapped);
METAL_C_EXPORT void MTLTextureDescriptorSetTextureType(MTLTextureDescriptor* descriptor, MTLTextureType type);
METAL_C_EXPORT void MTLTextureDescriptorSetPixelFormat(MTLTextureDescriptor* descriptor, MTLPixelFormat format);
METAL_C_EXPORT void MTLTextureDescriptorSetWidth(MTLTextureDescriptor* descriptor, size_t width);
METAL_C_EXPORT void MTLTextureDescriptorSetHeight(MTLTextureDescriptor* descriptor, size_t height);
METAL_C_EXPORT void MTLTextureDescriptorSetDepth(MTLTextureDescriptor* descriptor, size_t depth);
METAL_C_EXPORT void MTLTextureDescriptorSetArrayLength(MTLTextureDescriptor* descriptor, size_t length);
METAL_C_EXPORT void MTLTextureDescriptorSetMipmapLevelCount(MTLTextureDescriptor* descriptor, size_t count);
METAL_C_EXPORT void MTLTextureDescriptorSetResourceOptions(MTLTextureDescriptor* descriptor, MTLResourceOptions options);
METAL_C_EXPORT void MTLTextureDescriptorSetUsage(MTLTextureDescriptor* descriptor, MTLTextureUsage usage);

METAL_C_EXPORT size_t MTLTextureGetWidth(const MTLTexture* texture);
METAL_C_EXPORT size_t MTLTextureGetHeight(const MTLTexture* texture);
METAL_C_EXPORT size_t MTLTextureGetDepth(const MTLTexture* texture);
METAL_C_EXPORT MTLPixelFormat MTLTextureGetPixelFormat(const MTLTexture* texture);
METAL_C_EXPORT MTLResourceID MTLTextureGetGPUResourceID(const MTLTexture* texture);
METAL_C_EXPORT void MTLTextureReplaceRegion(MTLTexture* texture, MTLRegion region, size_t mipmapLevel, size_t slice, const void* bytes, size_t bytesPerRow, size_t bytesPerImage);
#ifdef __cplusplus
}
#endif
#endif
