#pragma once
#include <Metal/MTLDefines.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4LibraryDescriptor MTL4LibraryDescriptor;
METAL_C_EXPORT MTL4LibraryDescriptor* MTL4LibraryDescriptorCreate(void);
METAL_C_EXPORT void MTL4LibraryDescriptorSetName(MTL4LibraryDescriptor* descriptor, const char* name);
METAL_C_EXPORT void MTL4LibraryDescriptorSetSource(MTL4LibraryDescriptor* descriptor, const char* source);
#ifdef __cplusplus
}
#endif
