#ifndef METAL_C_MTL_DRAWABLE_H
#define METAL_C_MTL_DRAWABLE_H
#include <Metal/MTLDefines.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLDrawable MTLDrawable;
METAL_C_EXPORT void MTLDrawablePresent(MTLDrawable* drawable);
#ifdef __cplusplus
}
#endif
#endif
