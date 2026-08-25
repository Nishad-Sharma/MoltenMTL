#ifndef METAL_C_MTL_DEFINES_H
#define METAL_C_MTL_DEFINES_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if !defined(__APPLE__)
#error "metal-c supports Apple platforms only"
#endif

#define METAL_C_EXPORT __attribute__((visibility("default")))

#define MTL_C_ENUM(type, name) typedef type name; enum
#define MTL_C_OPTIONS(type, name) typedef type name; enum

#endif
