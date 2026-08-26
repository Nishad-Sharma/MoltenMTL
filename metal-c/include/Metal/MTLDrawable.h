#pragma once
#include <Metal/MTLDefines.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLDrawable MTLDrawable;
METAL_C_EXPORT void MTLDrawablePresent(MTLDrawable* drawable);
#ifdef __cplusplus
}
#endif
