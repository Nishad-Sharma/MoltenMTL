#include "MetalInternal.hpp"

extern "C" {
MTL4CompilerDescriptor* MTL4CompilerDescriptorCreate(void) { return cobject<MTL4CompilerDescriptor>(MTL4::CompilerDescriptor::alloc()->init()); }
MTL4LibraryDescriptor* MTL4LibraryDescriptorCreate(void) { return cobject<MTL4LibraryDescriptor>(MTL4::LibraryDescriptor::alloc()->init()); }
void MTL4LibraryDescriptorSetName(MTL4LibraryDescriptor* d, const char* v) { if (d) native<MTL4::LibraryDescriptor>(d)->setName(nsString(v)); }
void MTL4LibraryDescriptorSetSource(MTL4LibraryDescriptor* d, const char* v) { if (d) native<MTL4::LibraryDescriptor>(d)->setSource(nsString(v)); }
MTL4LibraryFunctionDescriptor* MTL4LibraryFunctionDescriptorCreate(void) { return cobject<MTL4LibraryFunctionDescriptor>(MTL4::LibraryFunctionDescriptor::alloc()->init()); }
void MTL4LibraryFunctionDescriptorSetLibrary(MTL4LibraryFunctionDescriptor* d, const MTLLibrary* v) { if (d) native<MTL4::LibraryFunctionDescriptor>(d)->setLibrary(native<MTL::Library>(v)); }
void MTL4LibraryFunctionDescriptorSetName(MTL4LibraryFunctionDescriptor* d, const char* v) { if (d) native<MTL4::LibraryFunctionDescriptor>(d)->setName(nsString(v)); }
MTL4ComputePipelineDescriptor* MTL4ComputePipelineDescriptorCreate(void) { return cobject<MTL4ComputePipelineDescriptor>(MTL4::ComputePipelineDescriptor::alloc()->init()); }
void MTL4ComputePipelineDescriptorSetComputeFunctionDescriptor(MTL4ComputePipelineDescriptor* d, const MTL4LibraryFunctionDescriptor* f) { if (d) native<MTL4::ComputePipelineDescriptor>(d)->setComputeFunctionDescriptor(native<MTL4::LibraryFunctionDescriptor>(f)); }
void MTL4ComputePipelineDescriptorSetMaxTotalThreadsPerThreadgroup(MTL4ComputePipelineDescriptor* d, size_t v) { if (d) native<MTL4::ComputePipelineDescriptor>(d)->setMaxTotalThreadsPerThreadgroup(v); }

MTLLibrary* MTL4CompilerCreateLibrary(MTL4Compiler* c, const MTL4LibraryDescriptor* d, NSError** error)
{
    if (error) *error = nullptr;
    if (!c || !d) return nullptr;
    NS::Error* e = nullptr;
    auto* library = native<MTL4::Compiler>(c)->newLibrary(native<MTL4::LibraryDescriptor>(d), &e);
    if (!library) returnError(e, error);
    return cobject<MTLLibrary>(library);
}
MTLComputePipelineState* MTL4CompilerCreateComputePipelineState(MTL4Compiler* c, const MTL4ComputePipelineDescriptor* d, NSError** error)
{
    if (error) *error = nullptr;
    if (!c || !d) return nullptr;
    NS::Error* e = nullptr;
    auto* state = native<MTL4::Compiler>(c)->newComputePipelineState(native<MTL4::ComputePipelineDescriptor>(d), nullptr, &e);
    if (!state) returnError(e, error);
    return cobject<MTLComputePipelineState>(state);
}
}
