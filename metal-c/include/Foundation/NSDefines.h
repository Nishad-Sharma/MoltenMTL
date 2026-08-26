#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if !defined(__APPLE__)
#error "metal-c supports Apple platforms only"
#endif

#define NS_C_EXPORT __attribute__((visibility("default")))

#define NS_INLINE inline __attribute__((always_inline))

#define NS_C_ENUM(type, name) typedef type name; enum
#define NS_C_OPTIONS(type, name) typedef type name; enum
