#pragma once
#include <Metal/MTLDefines.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTLSharedEvent MTLSharedEvent;
METAL_C_EXPORT uint64_t MTLSharedEventGetSignaledValue(const MTLSharedEvent* event);
METAL_C_EXPORT bool MTLSharedEventWaitUntilSignaledValue(MTLSharedEvent* event, uint64_t value, uint64_t timeoutMS);
#ifdef __cplusplus
}
#endif
