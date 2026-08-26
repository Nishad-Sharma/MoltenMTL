#pragma once

#include <Foundation/NSDefines.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NSAutoreleasePool NSAutoreleasePool;

NS_C_EXPORT NSAutoreleasePool* NSAutoreleasePoolCreate(void);
NS_C_EXPORT void* NSRetain(void* object);
NS_C_EXPORT void NSRelease(void* object);

#ifdef __cplusplus
}
#endif
