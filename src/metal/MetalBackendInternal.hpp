#ifndef MOLTENMTL_METAL_BACKEND_INTERNAL_HPP
#define MOLTENMTL_METAL_BACKEND_INTERNAL_HPP

#define METALCPP_SYMBOL_VISIBILITY_HIDDEN

#include <Metal/Metal.hpp>
#include <Metal/MTL4AccelerationStructure.hpp>

#include <MoltenMTL/MoltenMTL.h>

struct MMTLDevice_T {
    MTL::Device* native;
    MTL4::Compiler* compiler;
};

struct MMTLCommandQueue_T {
    MTL4::CommandQueue* native;
    MTL::SharedEvent* completionEvent;
    uint64_t submittedValue;
};

struct MMTLCommandAllocator_T {
    MTL4::CommandAllocator* native;
};

enum class CommandBufferState {
    initial,
    recording,
    executable,
};

struct MMTLCommandBuffer_T {
    MTL4::CommandBuffer* native;
    MTL::ResidencySet* residencySet;
    CommandBufferState state;
};

struct MMTLBuffer_T {
    MTL::Buffer* native;
};

struct MMTLTexture_T {
    MTL::Texture* native;
    MMTLTextureDescriptor descriptor;
};

struct MMTLLibrary_T {
    MTL::Library* native;
};

struct MMTLComputePipelineState_T {
    MTL::ComputePipelineState* native;
};

struct MMTLArgumentTable_T {
    MTL4::ArgumentTable* native;
    MTL::Allocation** bufferBindings;
    MTL::Allocation** textureBindings;
    uint32_t maxBufferBindCount;
    uint32_t maxTextureBindCount;
};

enum class AccelerationStructureKind {
    triangle,
    instance,
};

struct MMTLAccelerationStructure_T {
    MTL::AccelerationStructure* native;
    MTL4::AccelerationStructureDescriptor* buildDescriptor;
    MTL::Buffer* scratchBuffer;
    MTL::Allocation** retainedAllocations;
    uint32_t retainedAllocationCount;
    AccelerationStructureKind kind;
};

class ScopedAutoreleasePool {
public:
    ScopedAutoreleasePool()
        : native(NS::AutoreleasePool::alloc()->init())
    {
    }

    ~ScopedAutoreleasePool()
    {
        native->release();
    }

private:
    NS::AutoreleasePool* native;
};

MMTLResult ensureResidencySet(MMTLCommandBuffer commandBuffer);

void addResidentAllocation(
    MMTLCommandBuffer commandBuffer,
    const MTL::Allocation* allocation);

bool getNativePixelFormat(
    MMTLPixelFormat pixelFormat,
    MTL::PixelFormat* outPixelFormat,
    uint32_t* outBytesPerPixel);

#endif

