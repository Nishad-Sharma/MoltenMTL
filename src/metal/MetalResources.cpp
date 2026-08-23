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

} // extern "C"
