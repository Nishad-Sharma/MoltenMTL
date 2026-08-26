#include "../Metal/MetalInternal.hpp"

#include <QuartzCore/QuartzCore.hpp>
#include <QuartzCore/CAMetalLayer.h>

extern "C" {
CAMetalLayer* CAMetalLayerCreate(void)
{
    auto* layer = CA::MetalLayer::layer();
    if (layer) layer->retain();
    return cobject<CAMetalLayer>(layer);
}
CAMetalLayer* CAMetalLayerFromNative(void* pointer)
{
    auto* layer = reinterpret_cast<CA::MetalLayer*>(pointer);
    if (layer) layer->retain();
    return cobject<CAMetalLayer>(layer);
}
void* CAMetalLayerGetNative(CAMetalLayer* layer) { return layer; }
void CAMetalLayerSetDevice(CAMetalLayer* layer, MTLDevice* device) { if (layer) native<CA::MetalLayer>(layer)->setDevice(native<MTL::Device>(device)); }
void CAMetalLayerSetPixelFormat(CAMetalLayer* layer, MTLPixelFormat format) { if (layer) native<CA::MetalLayer>(layer)->setPixelFormat(static_cast<MTL::PixelFormat>(format)); }
void CAMetalLayerSetFramebufferOnly(CAMetalLayer* layer, bool value) { if (layer) native<CA::MetalLayer>(layer)->setFramebufferOnly(value); }
void CAMetalLayerSetDrawableSize(CAMetalLayer* layer, double width, double height) { if (layer) native<CA::MetalLayer>(layer)->setDrawableSize(CGSizeMake(width, height)); }
CAMetalDrawable* CAMetalLayerNextDrawable(CAMetalLayer* layer)
{
    if (!layer) return nullptr;
    auto* drawable = native<CA::MetalLayer>(layer)->nextDrawable();
    if (drawable) drawable->retain();
    return cobject<CAMetalDrawable>(drawable);
}
MTLTexture* CAMetalDrawableGetTexture(CAMetalDrawable* drawable)
{
    if (!drawable) return nullptr;
    auto* texture = native<CA::MetalDrawable>(drawable)->texture();
    if (texture) texture->retain();
    return cobject<MTLTexture>(texture);
}
}
