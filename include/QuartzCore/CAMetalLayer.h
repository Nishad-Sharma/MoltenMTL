#ifndef METAL_C_CA_METAL_LAYER_H
#define METAL_C_CA_METAL_LAYER_H
#include <Metal/MTLDevice.h>
#include <Metal/MTLDrawable.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct CAMetalLayer CAMetalLayer;
typedef MTLDrawable CAMetalDrawable;
METAL_C_EXPORT CAMetalLayer* CAMetalLayerCreate(void);
METAL_C_EXPORT CAMetalLayer* CAMetalLayerFromNative(void* nativeLayer);
METAL_C_EXPORT void* CAMetalLayerGetNative(CAMetalLayer* layer);
METAL_C_EXPORT void CAMetalLayerSetDevice(CAMetalLayer* layer, MTLDevice* device);
METAL_C_EXPORT void CAMetalLayerSetPixelFormat(CAMetalLayer* layer, MTLPixelFormat format);
METAL_C_EXPORT void CAMetalLayerSetFramebufferOnly(CAMetalLayer* layer, bool framebufferOnly);
METAL_C_EXPORT void CAMetalLayerSetDrawableSize(CAMetalLayer* layer, double width, double height);
METAL_C_EXPORT CAMetalDrawable* CAMetalLayerNextDrawable(CAMetalLayer* layer);
METAL_C_EXPORT MTLTexture* CAMetalDrawableGetTexture(CAMetalDrawable* drawable);
#ifdef __cplusplus
}
#endif
#endif
