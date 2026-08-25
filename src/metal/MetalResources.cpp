#include "MetalBackendInternal.hpp"

#include <new>

bool getNativePixelFormat(
    MMTLPixelFormat pixelFormat,
    MTL::PixelFormat* outPixelFormat,
    uint32_t* outBytesPerPixel)
{
    switch (pixelFormat) {
    case MMTL_PIXEL_FORMAT_RGBA8_UNORM:
        *outPixelFormat = MTL::PixelFormatRGBA8Unorm;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_BGRA8_UNORM:
        *outPixelFormat = MTL::PixelFormatBGRA8Unorm;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA8_UNORM_SRGB:
        *outPixelFormat = MTL::PixelFormatRGBA8Unorm_sRGB;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_BGRA8_UNORM_SRGB:
        *outPixelFormat = MTL::PixelFormatBGRA8Unorm_sRGB;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_R8_UNORM:
        *outPixelFormat = MTL::PixelFormatR8Unorm;
        *outBytesPerPixel = 1;
        return true;
    case MMTL_PIXEL_FORMAT_R8_UNORM_SRGB:
        *outPixelFormat = MTL::PixelFormatR8Unorm_sRGB;
        *outBytesPerPixel = 1;
        return true;
    case MMTL_PIXEL_FORMAT_R8_SNORM:
        *outPixelFormat = MTL::PixelFormatR8Snorm;
        *outBytesPerPixel = 1;
        return true;
    case MMTL_PIXEL_FORMAT_R8_UINT:
        *outPixelFormat = MTL::PixelFormatR8Uint;
        *outBytesPerPixel = 1;
        return true;
    case MMTL_PIXEL_FORMAT_R8_SINT:
        *outPixelFormat = MTL::PixelFormatR8Sint;
        *outBytesPerPixel = 1;
        return true;
    case MMTL_PIXEL_FORMAT_R16_UNORM:
        *outPixelFormat = MTL::PixelFormatR16Unorm;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_R16_SNORM:
        *outPixelFormat = MTL::PixelFormatR16Snorm;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_R16_UINT:
        *outPixelFormat = MTL::PixelFormatR16Uint;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_R16_SINT:
        *outPixelFormat = MTL::PixelFormatR16Sint;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_R16_FLOAT:
        *outPixelFormat = MTL::PixelFormatR16Float;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_R32_UINT:
        *outPixelFormat = MTL::PixelFormatR32Uint;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_R32_SINT:
        *outPixelFormat = MTL::PixelFormatR32Sint;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_R32_FLOAT:
        *outPixelFormat = MTL::PixelFormatR32Float;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RG8_UNORM:
        *outPixelFormat = MTL::PixelFormatRG8Unorm;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_RG8_UNORM_SRGB:
        *outPixelFormat = MTL::PixelFormatRG8Unorm_sRGB;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_RG8_SNORM:
        *outPixelFormat = MTL::PixelFormatRG8Snorm;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_RG8_UINT:
        *outPixelFormat = MTL::PixelFormatRG8Uint;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_RG8_SINT:
        *outPixelFormat = MTL::PixelFormatRG8Sint;
        *outBytesPerPixel = 2;
        return true;
    case MMTL_PIXEL_FORMAT_RG16_UNORM:
        *outPixelFormat = MTL::PixelFormatRG16Unorm;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RG16_SNORM:
        *outPixelFormat = MTL::PixelFormatRG16Snorm;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RG16_UINT:
        *outPixelFormat = MTL::PixelFormatRG16Uint;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RG16_SINT:
        *outPixelFormat = MTL::PixelFormatRG16Sint;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RG16_FLOAT:
        *outPixelFormat = MTL::PixelFormatRG16Float;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RG32_UINT:
        *outPixelFormat = MTL::PixelFormatRG32Uint;
        *outBytesPerPixel = 8;
        return true;
    case MMTL_PIXEL_FORMAT_RG32_SINT:
        *outPixelFormat = MTL::PixelFormatRG32Sint;
        *outBytesPerPixel = 8;
        return true;
    case MMTL_PIXEL_FORMAT_RG32_FLOAT:
        *outPixelFormat = MTL::PixelFormatRG32Float;
        *outBytesPerPixel = 8;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA8_SNORM:
        *outPixelFormat = MTL::PixelFormatRGBA8Snorm;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA8_UINT:
        *outPixelFormat = MTL::PixelFormatRGBA8Uint;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA8_SINT:
        *outPixelFormat = MTL::PixelFormatRGBA8Sint;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA16_UNORM:
        *outPixelFormat = MTL::PixelFormatRGBA16Unorm;
        *outBytesPerPixel = 8;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA16_SNORM:
        *outPixelFormat = MTL::PixelFormatRGBA16Snorm;
        *outBytesPerPixel = 8;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA16_UINT:
        *outPixelFormat = MTL::PixelFormatRGBA16Uint;
        *outBytesPerPixel = 8;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA16_SINT:
        *outPixelFormat = MTL::PixelFormatRGBA16Sint;
        *outBytesPerPixel = 8;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA32_UINT:
        *outPixelFormat = MTL::PixelFormatRGBA32Uint;
        *outBytesPerPixel = 16;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA32_SINT:
        *outPixelFormat = MTL::PixelFormatRGBA32Sint;
        *outBytesPerPixel = 16;
        return true;
    case MMTL_PIXEL_FORMAT_RGB10A2_UNORM:
        *outPixelFormat = MTL::PixelFormatRGB10A2Unorm;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RGB10A2_UINT:
        *outPixelFormat = MTL::PixelFormatRGB10A2Uint;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_BGR10A2_UNORM:
        *outPixelFormat = MTL::PixelFormatBGR10A2Unorm;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RG11B10_FLOAT:
        *outPixelFormat = MTL::PixelFormatRG11B10Float;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RGB9E5_FLOAT:
        *outPixelFormat = MTL::PixelFormatRGB9E5Float;
        *outBytesPerPixel = 4;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA16_FLOAT:
        *outPixelFormat = MTL::PixelFormatRGBA16Float;
        *outBytesPerPixel = 8;
        return true;
    case MMTL_PIXEL_FORMAT_RGBA32_FLOAT:
        *outPixelFormat = MTL::PixelFormatRGBA32Float;
        *outBytesPerPixel = 16;
        return true;
    default:
        return false;
    }
}

static bool getNativeStorageMode(
    MMTLStorageMode storageMode,
    MTL::StorageMode* outStorageMode)
{
    switch (storageMode) {
    case MMTL_STORAGE_MODE_SHARED:
        *outStorageMode = MTL::StorageModeShared;
        return true;
    case MMTL_STORAGE_MODE_PRIVATE:
        *outStorageMode = MTL::StorageModePrivate;
        return true;
    default:
        return false;
    }
}

static bool getNativeSamplerFilter(
    MMTLSamplerFilter filter,
    MTL::SamplerMinMagFilter* outFilter)
{
    switch (filter) {
    case MMTL_SAMPLER_FILTER_NEAREST:
        *outFilter = MTL::SamplerMinMagFilterNearest;
        return true;
    case MMTL_SAMPLER_FILTER_LINEAR:
        *outFilter = MTL::SamplerMinMagFilterLinear;
        return true;
    default:
        return false;
    }
}

static bool getNativeSamplerMipFilter(
    MMTLSamplerMipFilter filter,
    MTL::SamplerMipFilter* outFilter)
{
    switch (filter) {
    case MMTL_SAMPLER_MIP_FILTER_NOT_MIPMAPPED:
        *outFilter = MTL::SamplerMipFilterNotMipmapped;
        return true;
    case MMTL_SAMPLER_MIP_FILTER_NEAREST:
        *outFilter = MTL::SamplerMipFilterNearest;
        return true;
    case MMTL_SAMPLER_MIP_FILTER_LINEAR:
        *outFilter = MTL::SamplerMipFilterLinear;
        return true;
    default:
        return false;
    }
}

static bool getNativeSamplerAddressMode(
    MMTLSamplerAddressMode addressMode,
    MTL::SamplerAddressMode* outAddressMode)
{
    switch (addressMode) {
    case MMTL_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE:
        *outAddressMode = MTL::SamplerAddressModeClampToEdge;
        return true;
    case MMTL_SAMPLER_ADDRESS_MODE_REPEAT:
        *outAddressMode = MTL::SamplerAddressModeRepeat;
        return true;
    case MMTL_SAMPLER_ADDRESS_MODE_MIRROR_REPEAT:
        *outAddressMode = MTL::SamplerAddressModeMirrorRepeat;
        return true;
    default:
        return false;
    }
}

extern "C" {

MMTLResult mmtlCreateBuffer(
    MMTLDevice device,
    const MMTLBufferDescriptor* descriptor,
    MMTLBuffer* outBuffer)
{
    if (device == nullptr || descriptor == nullptr || outBuffer == nullptr ||
        descriptor->length == 0) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outBuffer = nullptr;

    MTL::ResourceOptions options;
    switch (descriptor->storageMode) {
    case MMTL_STORAGE_MODE_SHARED:
        options = MTL::ResourceStorageModeShared;
        break;
    case MMTL_STORAGE_MODE_PRIVATE:
        options = MTL::ResourceStorageModePrivate;
        break;
    default:
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    MTL::Buffer* native = device->native->newBuffer(
        static_cast<NS::UInteger>(descriptor->length),
        options);
    if (native == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* buffer = new (std::nothrow) MMTLBuffer_T{native};
    if (buffer == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outBuffer = buffer;
    return MMTL_SUCCESS;
}

void mmtlDestroyBuffer(MMTLBuffer buffer)
{
    if (buffer == nullptr) {
        return;
    }
    buffer->native->release();
    delete buffer;
}

uint64_t mmtlGetBufferLength(MMTLBuffer buffer)
{
    return buffer == nullptr ? 0 : buffer->native->length();
}

void* mmtlGetBufferContents(MMTLBuffer buffer)
{
    if (buffer == nullptr || buffer->native->storageMode() == MTL::StorageModePrivate) {
        return nullptr;
    }
    return buffer->native->contents();
}

MMTLResult mmtlCreateTexture(
    MMTLDevice device,
    const MMTLTextureDescriptor* descriptor,
    MMTLTexture* outTexture)
{
    if (device == nullptr || descriptor == nullptr || outTexture == nullptr ||
        descriptor->width == 0 || descriptor->height == 0) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outTexture = nullptr;

    constexpr MMTLTextureUsage supportedUsage =
        MMTL_TEXTURE_USAGE_SHADER_READ |
        MMTL_TEXTURE_USAGE_SHADER_WRITE |
        MMTL_TEXTURE_USAGE_COPY_SOURCE |
        MMTL_TEXTURE_USAGE_COPY_DESTINATION;
    if (descriptor->usage == 0 || (descriptor->usage & ~supportedUsage) != 0) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if ((descriptor->pixelFormat == MMTL_PIXEL_FORMAT_R8_UNORM_SRGB ||
         descriptor->pixelFormat == MMTL_PIXEL_FORMAT_RG8_UNORM_SRGB ||
         descriptor->pixelFormat == MMTL_PIXEL_FORMAT_RGBA8_UNORM_SRGB ||
         descriptor->pixelFormat == MMTL_PIXEL_FORMAT_BGRA8_UNORM_SRGB) &&
        (descriptor->usage & MMTL_TEXTURE_USAGE_SHADER_WRITE) != 0) {
        return MMTL_ERROR_UNSUPPORTED;
    }

    MTL::PixelFormat pixelFormat;
    uint32_t bytesPerPixel = 0;
    if (!getNativePixelFormat(
            descriptor->pixelFormat,
            &pixelFormat,
            &bytesPerPixel)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    (void)bytesPerPixel;

    MTL::StorageMode storageMode;
    if (!getNativeStorageMode(descriptor->storageMode, &storageMode)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    NS::UInteger nativeUsage = MTL::TextureUsageUnknown;
    if ((descriptor->usage & MMTL_TEXTURE_USAGE_SHADER_READ) != 0) {
        nativeUsage |= MTL::TextureUsageShaderRead;
    }
    if ((descriptor->usage & MMTL_TEXTURE_USAGE_SHADER_WRITE) != 0) {
        nativeUsage |= MTL::TextureUsageShaderWrite;
    }

    ScopedAutoreleasePool pool;
    auto* nativeDescriptor = MTL::TextureDescriptor::alloc()->init();
    if (nativeDescriptor == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    nativeDescriptor->setTextureType(MTL::TextureType2D);
    nativeDescriptor->setWidth(descriptor->width);
    nativeDescriptor->setHeight(descriptor->height);
    nativeDescriptor->setDepth(1);
    nativeDescriptor->setMipmapLevelCount(1);
    nativeDescriptor->setArrayLength(1);
    nativeDescriptor->setSampleCount(1);
    nativeDescriptor->setPixelFormat(pixelFormat);
    nativeDescriptor->setStorageMode(storageMode);
    nativeDescriptor->setUsage(static_cast<MTL::TextureUsage>(nativeUsage));

    MTL::Texture* native = device->native->newTexture(nativeDescriptor);
    nativeDescriptor->release();
    if (native == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* texture = new (std::nothrow) MMTLTexture_T{native, *descriptor, true};
    if (texture == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outTexture = texture;
    return MMTL_SUCCESS;
}

void mmtlDestroyTexture(MMTLTexture texture)
{
    if (texture == nullptr || !texture->ownsNative) {
        return;
    }
    texture->native->release();
    delete texture;
}

uint32_t mmtlGetTextureWidth(MMTLTexture texture)
{
    return texture == nullptr ? 0 : texture->descriptor.width;
}

uint32_t mmtlGetTextureHeight(MMTLTexture texture)
{
    return texture == nullptr ? 0 : texture->descriptor.height;
}

MMTLPixelFormat mmtlGetTexturePixelFormat(MMTLTexture texture)
{
    return texture == nullptr ? MMTL_PIXEL_FORMAT_UNDEFINED : texture->descriptor.pixelFormat;
}

MMTLTextureUsage mmtlGetTextureUsage(MMTLTexture texture)
{
    return texture == nullptr ? 0 : texture->descriptor.usage;
}

MMTLResult mmtlCreateSampler(
    MMTLDevice device,
    const MMTLSamplerDescriptor* descriptor,
    MMTLSampler* outSampler)
{
    if (device == nullptr || descriptor == nullptr || outSampler == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outSampler = nullptr;

    MTL::SamplerMinMagFilter minFilter;
    MTL::SamplerMinMagFilter magFilter;
    MTL::SamplerMipFilter mipFilter;
    MTL::SamplerAddressMode addressModeU;
    MTL::SamplerAddressMode addressModeV;
    MTL::SamplerAddressMode addressModeW;
    if (!getNativeSamplerFilter(descriptor->minFilter, &minFilter) ||
        !getNativeSamplerFilter(descriptor->magFilter, &magFilter) ||
        !getNativeSamplerMipFilter(descriptor->mipFilter, &mipFilter) ||
        !getNativeSamplerAddressMode(descriptor->addressModeU, &addressModeU) ||
        !getNativeSamplerAddressMode(descriptor->addressModeV, &addressModeV) ||
        !getNativeSamplerAddressMode(descriptor->addressModeW, &addressModeW)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    ScopedAutoreleasePool pool;
    auto* nativeDescriptor = MTL::SamplerDescriptor::alloc()->init();
    if (nativeDescriptor == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    nativeDescriptor->setMinFilter(minFilter);
    nativeDescriptor->setMagFilter(magFilter);
    nativeDescriptor->setMipFilter(mipFilter);
    nativeDescriptor->setSAddressMode(addressModeU);
    nativeDescriptor->setTAddressMode(addressModeV);
    nativeDescriptor->setRAddressMode(addressModeW);
    nativeDescriptor->setNormalizedCoordinates(true);
    nativeDescriptor->setSupportArgumentBuffers(true);

    MTL::SamplerState* native = device->native->newSamplerState(nativeDescriptor);
    nativeDescriptor->release();
    if (native == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* sampler = new (std::nothrow) MMTLSampler_T{native};
    if (sampler == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outSampler = sampler;
    return MMTL_SUCCESS;
}

void mmtlDestroySampler(MMTLSampler sampler)
{
    if (sampler == nullptr) {
        return;
    }
    sampler->native->release();
    delete sampler;
}

} // extern "C"
