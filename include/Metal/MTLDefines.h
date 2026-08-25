#ifndef METAL_C_MTL_DEFINES_H
#define METAL_C_MTL_DEFINES_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if !defined(__APPLE__)
#error "metal-c supports Apple platforms only"
#endif

#define METAL_C_EXPORT __attribute__((visibility("default")))

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MTLAutoreleasePool MTLAutoreleasePool;
typedef struct MTLError MTLError;

METAL_C_EXPORT MTLAutoreleasePool* MTLAutoreleasePoolCreate(void);
METAL_C_EXPORT void* MTLRetain(void* object);
METAL_C_EXPORT void MTLRelease(void* object);
METAL_C_EXPORT int64_t MTLErrorGetCode(const MTLError* error);
METAL_C_EXPORT const char* MTLErrorGetLocalizedDescription(const MTLError* error);

#ifdef __cplusplus
}
#endif

#endif
