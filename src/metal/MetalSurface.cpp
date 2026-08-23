#include "MetalBackendInternal.hpp"

#include <QuartzCore/QuartzCore.hpp>

#include <limits>
#include <new>

static void releaseAcquiredSurfaceImage(MMTLSurface surface)
{
    delete surface->acquiredTexture;
    surface->acquiredTexture = nullptr;
    surface->acquiredDrawable->release();
    surface->acquiredDrawable = nullptr;
    surface->acquiredQueue = nullptr;
}

extern "C" {

MMTLResult mmtlCreateSurfaceFromMetalLayer(
    MMTLDevice device,
    void* metalLayer,
    MMTLSurface* outSurface)
{
    if (device == nullptr || metalLayer == nullptr || outSurface == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outSurface = nullptr;

    auto* native = reinterpret_cast<CA::MetalLayer*>(metalLayer);
    native->retain();
    auto* surface = new (std::nothrow) MMTLSurface_T{
        native,
        device->native,
        {},
        nullptr,
        nullptr,
        nullptr,
        0,
        false,
    };
    if (surface == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outSurface = surface;
    return MMTL_SUCCESS;
}

void mmtlDestroySurface(MMTLSurface surface)
{
    if (surface == nullptr) {
        return;
    }
    if (surface->acquiredDrawable != nullptr) {
        releaseAcquiredSurfaceImage(surface);
    }
    surface->native->release();
    delete surface;
}

MMTLResult mmtlConfigureSurface(
    MMTLSurface surface,
    const MMTLSurfaceConfiguration* configuration)
{
    if (surface == nullptr || configuration == nullptr ||
        configuration->width == 0 || configuration->height == 0 ||
        (configuration->imageCount != 2 && configuration->imageCount != 3)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (surface->acquiredDrawable != nullptr) {
        return MMTL_ERROR_INVALID_STATE;
    }
    if (configuration->presentMode != MMTL_PRESENT_MODE_FIFO &&
        configuration->presentMode != MMTL_PRESENT_MODE_IMMEDIATE) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (configuration->pixelFormat != MMTL_PIXEL_FORMAT_BGRA8_UNORM &&
        configuration->pixelFormat != MMTL_PIXEL_FORMAT_RGBA16_FLOAT) {
        return MMTL_ERROR_UNSUPPORTED;
    }

    MTL::PixelFormat pixelFormat;
    uint32_t bytesPerPixel = 0;
    if (!getNativePixelFormat(
            configuration->pixelFormat,
            &pixelFormat,
            &bytesPerPixel)) {
        return MMTL_ERROR_UNSUPPORTED;
    }
    (void)bytesPerPixel;

    surface->native->setDevice(surface->device);
    surface->native->setPixelFormat(pixelFormat);
    surface->native->setFramebufferOnly(false);
    surface->native->setDrawableSize(CGSizeMake(
        static_cast<CGFloat>(configuration->width),
        static_cast<CGFloat>(configuration->height)));
    surface->native->setMaximumDrawableCount(configuration->imageCount);
    surface->native->setDisplaySyncEnabled(
        configuration->presentMode == MMTL_PRESENT_MODE_FIFO);
    surface->native->setAllowsNextDrawableTimeout(true);
    surface->configuration = *configuration;
    surface->configured = true;
    return MMTL_SUCCESS;
}

MMTLResult mmtlAcquireNextSurfaceImage(
    MMTLSurface surface,
    MMTLCommandQueue queue,
    MMTLSurfaceImage* outSurfaceImage)
{
    if (surface == nullptr || queue == nullptr || outSurfaceImage == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outSurfaceImage = {};
    if (!surface->configured || surface->acquiredDrawable != nullptr) {
        return MMTL_ERROR_INVALID_STATE;
    }
    if (surface->imageToken == std::numeric_limits<uint64_t>::max()) {
        return MMTL_ERROR_INTERNAL;
    }

    ScopedAutoreleasePool pool;
    CA::MetalDrawable* drawable = surface->native->nextDrawable();
    if (drawable == nullptr) {
        return MMTL_NOT_READY;
    }
    drawable->retain();

    MTL::Texture* nativeTexture = drawable->texture();
    const MMTLTextureDescriptor descriptor = {
        static_cast<uint32_t>(nativeTexture->width()),
        static_cast<uint32_t>(nativeTexture->height()),
        surface->configuration.pixelFormat,
        MMTL_TEXTURE_USAGE_SHADER_WRITE |
            MMTL_TEXTURE_USAGE_COPY_SOURCE |
            MMTL_TEXTURE_USAGE_COPY_DESTINATION,
        MMTL_STORAGE_MODE_PRIVATE,
    };
    auto* texture = new (std::nothrow) MMTLTexture_T{
        nativeTexture,
        descriptor,
        false,
    };
    if (texture == nullptr) {
        drawable->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    queue->native->wait(drawable);
    ++surface->imageToken;
    surface->acquiredDrawable = drawable;
    surface->acquiredTexture = texture;
    surface->acquiredQueue = queue;
    outSurfaceImage->texture = texture;
    outSurfaceImage->imageToken = surface->imageToken;
    return MMTL_SUCCESS;
}

MMTLResult mmtlQueuePresent(
    MMTLCommandQueue queue,
    MMTLSurface surface,
    uint64_t imageToken)
{
    if (queue == nullptr || surface == nullptr || imageToken == 0) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (surface->acquiredDrawable == nullptr ||
        surface->acquiredQueue != queue ||
        surface->imageToken != imageToken) {
        return MMTL_ERROR_INVALID_STATE;
    }
    if (queue->submittedValue == std::numeric_limits<uint64_t>::max()) {
        return MMTL_ERROR_INTERNAL;
    }

    queue->native->signalDrawable(surface->acquiredDrawable);
    surface->acquiredDrawable->present();
    ++queue->submittedValue;
    queue->native->signalEvent(queue->completionEvent, queue->submittedValue);
    releaseAcquiredSurfaceImage(surface);
    return MMTL_SUCCESS;
}

} // extern "C"
