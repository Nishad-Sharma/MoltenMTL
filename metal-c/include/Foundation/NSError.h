#pragma once

#include <Foundation/NSDefines.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NSError NSError;

NS_C_EXPORT int64_t NSErrorGetCode(const NSError* error);
NS_C_EXPORT const char* NSErrorGetLocalizedDescription(const NSError* error);

#ifdef __cplusplus
}
#endif
