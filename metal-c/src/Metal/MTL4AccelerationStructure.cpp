#include "MetalInternal.hpp"

static_assert(sizeof(MTLPackedFloat4x3) == sizeof(MTL::PackedFloat4x3));
static_assert(sizeof(MTLAccelerationStructureInstanceDescriptor) == sizeof(MTL::AccelerationStructureInstanceDescriptor));
static_assert(sizeof(MTLAccelerationStructureUserIDInstanceDescriptor) == sizeof(MTL::AccelerationStructureUserIDInstanceDescriptor));
static_assert(sizeof(MTLIndirectAccelerationStructureInstanceDescriptor) == sizeof(MTL::IndirectAccelerationStructureInstanceDescriptor));

extern "C" {
MTL4AccelerationStructureTriangleGeometryDescriptor* MTL4AccelerationStructureTriangleGeometryDescriptorCreate(void) { return cobject<MTL4AccelerationStructureTriangleGeometryDescriptor>(MTL4::AccelerationStructureTriangleGeometryDescriptor::alloc()->init()); }
void MTL4AccelerationStructureTriangleGeometryDescriptorSetVertexBuffer(MTL4AccelerationStructureTriangleGeometryDescriptor* d, MTL4BufferRange v) { if (d) native<MTL4::AccelerationStructureTriangleGeometryDescriptor>(d)->setVertexBuffer(nativeRange(v)); }
void MTL4AccelerationStructureTriangleGeometryDescriptorSetVertexFormat(MTL4AccelerationStructureTriangleGeometryDescriptor* d, MTLAttributeFormat v) { if (d) native<MTL4::AccelerationStructureTriangleGeometryDescriptor>(d)->setVertexFormat(static_cast<MTL::AttributeFormat>(v)); }
void MTL4AccelerationStructureTriangleGeometryDescriptorSetVertexStride(MTL4AccelerationStructureTriangleGeometryDescriptor* d, size_t v) { if (d) native<MTL4::AccelerationStructureTriangleGeometryDescriptor>(d)->setVertexStride(v); }
void MTL4AccelerationStructureTriangleGeometryDescriptorSetIndexBuffer(MTL4AccelerationStructureTriangleGeometryDescriptor* d, MTL4BufferRange v) { if (d) native<MTL4::AccelerationStructureTriangleGeometryDescriptor>(d)->setIndexBuffer(nativeRange(v)); }
void MTL4AccelerationStructureTriangleGeometryDescriptorSetIndexType(MTL4AccelerationStructureTriangleGeometryDescriptor* d, MTLIndexType v) { if (d) native<MTL4::AccelerationStructureTriangleGeometryDescriptor>(d)->setIndexType(static_cast<MTL::IndexType>(v)); }
void MTL4AccelerationStructureTriangleGeometryDescriptorSetTriangleCount(MTL4AccelerationStructureTriangleGeometryDescriptor* d, size_t v) { if (d) native<MTL4::AccelerationStructureTriangleGeometryDescriptor>(d)->setTriangleCount(v); }
void MTL4AccelerationStructureTriangleGeometryDescriptorSetOpaque(MTL4AccelerationStructureTriangleGeometryDescriptor* d, bool v) { if (d) native<MTL4::AccelerationStructureTriangleGeometryDescriptor>(d)->setOpaque(v); }
MTL4PrimitiveAccelerationStructureDescriptor* MTL4PrimitiveAccelerationStructureDescriptorCreate(void) { return cobject<MTL4PrimitiveAccelerationStructureDescriptor>(MTL4::PrimitiveAccelerationStructureDescriptor::alloc()->init()); }
void MTL4PrimitiveAccelerationStructureDescriptorSetGeometryDescriptors(MTL4PrimitiveAccelerationStructureDescriptor* d, MTL4AccelerationStructureTriangleGeometryDescriptor* const* values, size_t count)
{
    if (!d || (!values && count)) return;
    auto* array = NS::Array::array(reinterpret_cast<const NS::Object* const*>(values), count);
    native<MTL4::PrimitiveAccelerationStructureDescriptor>(d)->setGeometryDescriptors(array);
}
void MTL4PrimitiveAccelerationStructureDescriptorSetUsage(MTL4PrimitiveAccelerationStructureDescriptor* d, MTLAccelerationStructureUsage v) { if (d) native<MTL4::PrimitiveAccelerationStructureDescriptor>(d)->setUsage(static_cast<MTL::AccelerationStructureUsage>(v)); }
MTL4InstanceAccelerationStructureDescriptor* MTL4InstanceAccelerationStructureDescriptorCreate(void) { return cobject<MTL4InstanceAccelerationStructureDescriptor>(MTL4::InstanceAccelerationStructureDescriptor::alloc()->init()); }
void MTL4InstanceAccelerationStructureDescriptorSetInstanceDescriptorBuffer(MTL4InstanceAccelerationStructureDescriptor* d, MTL4BufferRange v) { if (d) native<MTL4::InstanceAccelerationStructureDescriptor>(d)->setInstanceDescriptorBuffer(nativeRange(v)); }
void MTL4InstanceAccelerationStructureDescriptorSetInstanceDescriptorStride(MTL4InstanceAccelerationStructureDescriptor* d, size_t v) { if (d) native<MTL4::InstanceAccelerationStructureDescriptor>(d)->setInstanceDescriptorStride(v); }
void MTL4InstanceAccelerationStructureDescriptorSetInstanceDescriptorType(MTL4InstanceAccelerationStructureDescriptor* d, MTLAccelerationStructureInstanceDescriptorType v) { if (d) native<MTL4::InstanceAccelerationStructureDescriptor>(d)->setInstanceDescriptorType(static_cast<MTL::AccelerationStructureInstanceDescriptorType>(v)); }
void MTL4InstanceAccelerationStructureDescriptorSetInstanceCount(MTL4InstanceAccelerationStructureDescriptor* d, size_t v) { if (d) native<MTL4::InstanceAccelerationStructureDescriptor>(d)->setInstanceCount(v); }
void MTL4InstanceAccelerationStructureDescriptorSetUsage(MTL4InstanceAccelerationStructureDescriptor* d, MTLAccelerationStructureUsage v) { if (d) native<MTL4::InstanceAccelerationStructureDescriptor>(d)->setUsage(static_cast<MTL::AccelerationStructureUsage>(v)); }
}
