#pragma once

#include <QuartzCore/CADefines.h>
#include <Metal/MTLDevice.h>
#include <Metal/MTLDrawable.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CAMetalLayer CAMetalLayer;
typedef MTLDrawable CAMetalDrawable;

CA_C_EXPORT CAMetalLayer* CAMetalLayerCreate(void);
CA_C_EXPORT CAMetalLayer* CAMetalLayerFromNative(void* nativeLayer);
CA_C_EXPORT void* CAMetalLayerGetNative(CAMetalLayer* layer);
CA_C_EXPORT void CAMetalLayerSetDevice(CAMetalLayer* layer, MTLDevice* device);
CA_C_EXPORT void CAMetalLayerSetPixelFormat(CAMetalLayer* layer, MTLPixelFormat format);
CA_C_EXPORT void CAMetalLayerSetFramebufferOnly(CAMetalLayer* layer, bool framebufferOnly);
CA_C_EXPORT void CAMetalLayerSetDrawableSize(CAMetalLayer* layer, double width, double height);
CA_C_EXPORT CAMetalDrawable* CAMetalLayerNextDrawable(CAMetalLayer* layer);
CA_C_EXPORT MTLTexture* CAMetalDrawableGetTexture(CAMetalDrawable* drawable);
#ifdef __cplusplus
}
#endif
