#ifndef METAL_C_MTL_ERROR_H
#define METAL_C_MTL_ERROR_H

#include <Metal/MTLDefines.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MTLError MTLError;

METAL_C_EXPORT int64_t MTLErrorGetCode(const MTLError* error);
METAL_C_EXPORT const char* MTLErrorGetLocalizedDescription(const MTLError* error);

#ifdef __cplusplus
}
#endif

#endif
