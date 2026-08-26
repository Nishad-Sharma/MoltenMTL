#include "MetalInternal.hpp"

extern "C" {
MTLResidencySetDescriptor* MTLResidencySetDescriptorCreate(void) { return cobject<MTLResidencySetDescriptor>(MTL::ResidencySetDescriptor::alloc()->init()); }
void MTLResidencySetDescriptorSetInitialCapacity(MTLResidencySetDescriptor* d, size_t capacity) { if (d) native<MTL::ResidencySetDescriptor>(d)->setInitialCapacity(capacity); }
void MTLResidencySetAddAllocation(MTLResidencySet* s, const MTLAllocation* a) { if (s && a) native<MTL::ResidencySet>(s)->addAllocation(native<MTL::Allocation>(a)); }
void MTLResidencySetRemoveAllocation(MTLResidencySet* s, const MTLAllocation* a) { if (s && a) native<MTL::ResidencySet>(s)->removeAllocation(native<MTL::Allocation>(a)); }
void MTLResidencySetAddBuffer(MTLResidencySet* s, const MTLBuffer* b) { if (s && b) native<MTL::ResidencySet>(s)->addAllocation(native<MTL::Buffer>(b)); }
void MTLResidencySetAddTexture(MTLResidencySet* s, const MTLTexture* t) { if (s && t) native<MTL::ResidencySet>(s)->addAllocation(native<MTL::Texture>(t)); }
void MTLResidencySetAddAccelerationStructure(MTLResidencySet* s, const MTLAccelerationStructure* a) { if (s && a) native<MTL::ResidencySet>(s)->addAllocation(native<MTL::AccelerationStructure>(a)); }
void MTLResidencySetCommit(MTLResidencySet* s) { if (s) native<MTL::ResidencySet>(s)->commit(); }
}
