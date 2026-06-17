#ifndef CVULKAN_H
#define CVULKAN_H

// When parsed in C++ module mode (Swift interoperabilityMode(.Cxx)), MSVC's
// modular headers cannot import <stdint.h> inside an extern "C" block.
// Pre-include <cstdint> at C++ file scope (always legal) and define
// VK_NO_STDINT_H so vk_platform.h and vulkan_video_codecs_common.h skip their
// inner "#include <stdint.h>" — the types are already available from <cstdint>.
// This guard has no effect on plain-C compilation (Swift targets without interop).
#ifdef __cplusplus
#  include <cstdint>
#  ifndef VK_NO_STDINT_H
#    define VK_NO_STDINT_H
#  endif
#endif

// Core Vulkan types only — no platform extensions (avoids pulling in windows.h).
#include <vulkan/vulkan_core.h>

// ── Swift-accessible version constants ────────────────────────────────────────
// VK_API_VERSION_* are function-like macros that the Swift importer cannot see.
// Expose equivalent typed constants that Swift can use directly.
static const uint32_t SWIFT_VK_API_VERSION_1_0 = (0u << 29u) | (1u << 22u) | (0u << 12u) | 0u;
static const uint32_t SWIFT_VK_API_VERSION_1_1 = (0u << 29u) | (1u << 22u) | (1u << 12u) | 0u;
static const uint32_t SWIFT_VK_API_VERSION_1_2 = (0u << 29u) | (1u << 22u) | (2u << 12u) | 0u;
static const uint32_t SWIFT_VK_API_VERSION_1_3 = (0u << 29u) | (1u << 22u) | (3u << 12u) | 0u;
static const uint32_t SWIFT_VK_API_VERSION_1_4 = (0u << 29u) | (1u << 22u) | (4u << 12u) | 0u;

// ── Swift-accessible extension name constants ─────────────────────────────────
// The VK_*_EXTENSION_NAME macros expand to string literals, which Swift imports
// as Swift Strings — but ppEnabledExtensionNames needs UnsafePointer<CChar>.
// Expose them as C string pointer constants so Swift gets the right type directly.
static const char* const SWIFT_EXT_DEFERRED_HOST_OPS = VK_KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME;
static const char* const SWIFT_EXT_ACCEL_STRUCTURE   = VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME;
static const char* const SWIFT_EXT_RAY_QUERY         = VK_KHR_RAY_QUERY_EXTENSION_NAME;

// ── Surface / swapchain extension name constants ──────────────────────────────
// Avoid including vulkan_win32.h (pulls in windows.h); use string literals directly.
static const char* const SWIFT_EXT_KHR_SURFACE      = "VK_KHR_surface";
static const char* const SWIFT_EXT_WIN32_SURFACE     = "VK_KHR_win32_surface";
static const char* const SWIFT_EXT_KHR_SWAPCHAIN    = "VK_KHR_swapchain";

#include "CAccelStruct.h"
#include "CSwapchain.h"

#endif // CVULKAN_H
