#ifndef METAL_C_MTL4_COMPILER_H
#define METAL_C_MTL4_COMPILER_H
#include <Metal/MTL4ComputePipeline.h>
#include <Metal/MTL4LibraryDescriptor.h>
#include <Metal/MTLComputePipeline.h>
#include <Metal/MTLError.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4Compiler MTL4Compiler;
typedef struct MTL4CompilerDescriptor MTL4CompilerDescriptor;
METAL_C_EXPORT MTL4CompilerDescriptor* MTL4CompilerDescriptorCreate(void);
METAL_C_EXPORT MTLLibrary* MTL4CompilerNewLibrary(MTL4Compiler* compiler, const MTL4LibraryDescriptor* descriptor, MTLError** error);
METAL_C_EXPORT MTLComputePipelineState* MTL4CompilerNewComputePipelineState(MTL4Compiler* compiler, const MTL4ComputePipelineDescriptor* descriptor, MTLError** error);
#ifdef __cplusplus
}
#endif
#endif
