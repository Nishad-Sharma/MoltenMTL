#ifndef METAL_C_MTL_PIXEL_FORMAT_H
#define METAL_C_MTL_PIXEL_FORMAT_H

typedef enum MTLPixelFormat {
    MTLPixelFormatInvalid = 0,
    MTLPixelFormatR8Unorm = 10,
    MTLPixelFormatR16Float = 25,
    MTLPixelFormatRG8Unorm = 30,
    MTLPixelFormatRG16Float = 65,
    MTLPixelFormatRGBA8Unorm = 70,
    MTLPixelFormatRGBA8Unorm_sRGB = 71,
    MTLPixelFormatBGRA8Unorm = 80,
    MTLPixelFormatBGRA8Unorm_sRGB = 81,
    MTLPixelFormatRGBA16Float = 115,
    MTLPixelFormatR32Float = 55,
    MTLPixelFormatRG32Float = 105,
    MTLPixelFormatRGBA32Float = 125
} MTLPixelFormat;

#endif
