#pragma once
#include <Metal/MTL4ComputePipeline.h>
#include <Metal/MTL4LibraryDescriptor.h>
#include <Metal/MTLComputePipeline.h>
#include <Foundation/NSError.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4Compiler MTL4Compiler;
typedef struct MTL4CompilerDescriptor MTL4CompilerDescriptor;
METAL_C_EXPORT MTL4CompilerDescriptor* MTL4CompilerDescriptorCreate(void);
METAL_C_EXPORT MTLLibrary* MTL4CompilerCreateLibrary(MTL4Compiler* compiler, const MTL4LibraryDescriptor* descriptor, NSError** error);
METAL_C_EXPORT MTLComputePipelineState* MTL4CompilerCreateComputePipelineState(MTL4Compiler* compiler, const MTL4ComputePipelineDescriptor* descriptor, NSError** error);
#ifdef __cplusplus
}
#endif
