#include "MetalInternal.hpp"

extern "C" {
void MTL4CommandAllocatorReset(MTL4CommandAllocator* a) { if (a) native<MTL4::CommandAllocator>(a)->reset(); }
uint64_t MTL4CommandAllocatorGetAllocatedSize(MTL4CommandAllocator* a) { return a ? native<MTL4::CommandAllocator>(a)->allocatedSize() : 0; }
void MTL4CommandBufferBegin(MTL4CommandBuffer* b, const MTL4CommandAllocator* a) { if (b && a) native<MTL4::CommandBuffer>(b)->beginCommandBuffer(native<MTL4::CommandAllocator>(a)); }
MTL4ComputeCommandEncoder* MTL4CommandBufferGetComputeCommandEncoder(MTL4CommandBuffer* b)
{
    if (!b) return nullptr;
    auto* encoder = native<MTL4::CommandBuffer>(b)->computeCommandEncoder();
    if (encoder) encoder->retain();
    return cobject<MTL4ComputeCommandEncoder>(encoder);
}
void MTL4CommandBufferUseResidencySet(MTL4CommandBuffer* b, const MTLResidencySet* s) { if (b && s) native<MTL4::CommandBuffer>(b)->useResidencySet(native<MTL::ResidencySet>(s)); }
void MTL4CommandBufferEnd(MTL4CommandBuffer* b) { if (b) native<MTL4::CommandBuffer>(b)->endCommandBuffer(); }
void MTL4CommandEncoderBarrierAfterEncoderStages(MTL4CommandEncoder* e, MTLStages after, MTLStages before, MTL4VisibilityOptions v) { if (e) native<MTL4::CommandEncoder>(e)->barrierAfterEncoderStages(static_cast<MTL::Stages>(after), static_cast<MTL::Stages>(before), static_cast<MTL4::VisibilityOptions>(v)); }
void MTL4CommandEncoderEndEncoding(MTL4CommandEncoder* e) { if (e) native<MTL4::CommandEncoder>(e)->endEncoding(); }
void MTL4CommandQueueCommit(MTL4CommandQueue* q, MTL4CommandBuffer* const* buffers, size_t count) { if (q && buffers && count) native<MTL4::CommandQueue>(q)->commit(reinterpret_cast<const MTL4::CommandBuffer* const*>(buffers), count); }
void MTL4CommandQueueSignalEvent(MTL4CommandQueue* q, MTLSharedEvent* e, uint64_t v) { if (q && e) native<MTL4::CommandQueue>(q)->signalEvent(native<MTL::SharedEvent>(e), v); }
void MTL4CommandQueueWaitForEvent(MTL4CommandQueue* q, MTLSharedEvent* e, uint64_t v) { if (q && e) native<MTL4::CommandQueue>(q)->wait(native<MTL::SharedEvent>(e), v); }
void MTL4CommandQueueWaitForDrawable(MTL4CommandQueue* q, MTLDrawable* d) { if (q && d) native<MTL4::CommandQueue>(q)->wait(native<MTL::Drawable>(d)); }
void MTL4CommandQueueSignalDrawable(MTL4CommandQueue* q, MTLDrawable* d) { if (q && d) native<MTL4::CommandQueue>(q)->signalDrawable(native<MTL::Drawable>(d)); }
}
