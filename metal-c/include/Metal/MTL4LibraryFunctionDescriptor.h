#pragma once
#include <Metal/MTLLibrary.h>
#include <Metal/MTLDefines.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4LibraryFunctionDescriptor MTL4LibraryFunctionDescriptor;
METAL_C_EXPORT MTL4LibraryFunctionDescriptor* MTL4LibraryFunctionDescriptorCreate(void);
METAL_C_EXPORT void MTL4LibraryFunctionDescriptorSetLibrary(MTL4LibraryFunctionDescriptor* descriptor, const MTLLibrary* library);
METAL_C_EXPORT void MTL4LibraryFunctionDescriptorSetName(MTL4LibraryFunctionDescriptor* descriptor, const char* name);
#ifdef __cplusplus
}
#endif
