#include "MetalBackendInternal.hpp"

#include <limits>
#include <new>

static MMTLResult newAccelerationStructure(
    MMTLDevice device,
    MTL4::AccelerationStructureDescriptor* buildDescriptor,
    MTL::Allocation** retainedAllocations,
    uint32_t retainedAllocationCount,
    AccelerationStructureKind kind,
    MMTLAccelerationStructure* outAccelerationStructure)
{
    const MTL::AccelerationStructureSizes sizes =
        device->native->accelerationStructureSizes(buildDescriptor);
    if (sizes.accelerationStructureSize == 0 || sizes.buildScratchBufferSize == 0) {
        return MMTL_ERROR_INTERNAL;
    }

    MTL::AccelerationStructure* native =
        device->native->newAccelerationStructure(sizes.accelerationStructureSize);
    if (native == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    MTL::Buffer* scratchBuffer = device->native->newBuffer(
        sizes.buildScratchBufferSize,
        MTL::ResourceStorageModePrivate);
    if (scratchBuffer == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* accelerationStructure = new (std::nothrow) MMTLAccelerationStructure_T{
        native,
        buildDescriptor,
        scratchBuffer,
        retainedAllocations,
        retainedAllocationCount,
        kind,
    };
    if (accelerationStructure == nullptr) {
        scratchBuffer->release();
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    buildDescriptor->retain();
    for (uint32_t index = 0; index < retainedAllocationCount; ++index) {
        retainedAllocations[index]->retain();
    }
    *outAccelerationStructure = accelerationStructure;
    return MMTL_SUCCESS;
}

extern "C" {

MMTLResult mmtlCreateTriangleAccelerationStructure(
    MMTLDevice device,
    const MMTLAccelerationStructureTriangleGeometryDescriptor* descriptor,
    MMTLAccelerationStructure* outAccelerationStructure)
{
    if (device == nullptr || descriptor == nullptr || outAccelerationStructure == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outAccelerationStructure = nullptr;
    if (!device->native->supportsRaytracing()) {
        return MMTL_ERROR_UNSUPPORTED;
    }

    if (descriptor->vertexBuffer == nullptr || descriptor->triangleCount == 0 ||
        descriptor->vertexStride < 3 * sizeof(float) ||
        descriptor->vertexStride % sizeof(float) != 0 ||
        descriptor->vertexBufferOffset % sizeof(float) != 0 ||
        descriptor->opaque > 1) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    const uint64_t vertexBufferLength = descriptor->vertexBuffer->native->length();
    if (descriptor->vertexBufferOffset > vertexBufferLength ||
        vertexBufferLength - descriptor->vertexBufferOffset < 3 * sizeof(float)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    MTL::IndexType nativeIndexType = MTL::IndexTypeUInt16;
    uint64_t requiredIndexBytes = 0;
    if (descriptor->indexType == MMTL_INDEX_TYPE_NONE) {
        if (descriptor->indexBuffer != nullptr || descriptor->indexBufferOffset != 0) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }

        const uint64_t vertexCount = static_cast<uint64_t>(descriptor->triangleCount) * 3;
        if (vertexCount - 1 >
            (std::numeric_limits<uint64_t>::max() - 3 * sizeof(float)) /
                descriptor->vertexStride) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        const uint64_t requiredVertexBytes =
            (vertexCount - 1) * descriptor->vertexStride + 3 * sizeof(float);
        if (requiredVertexBytes > vertexBufferLength - descriptor->vertexBufferOffset) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
    } else {
        if (descriptor->indexBuffer == nullptr) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        uint64_t indexSize = 0;
        switch (descriptor->indexType) {
        case MMTL_INDEX_TYPE_UINT16:
            nativeIndexType = MTL::IndexTypeUInt16;
            indexSize = sizeof(uint16_t);
            break;
        case MMTL_INDEX_TYPE_UINT32:
            nativeIndexType = MTL::IndexTypeUInt32;
            indexSize = sizeof(uint32_t);
            break;
        default:
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        if (descriptor->indexBufferOffset % indexSize != 0) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        requiredIndexBytes =
            static_cast<uint64_t>(descriptor->triangleCount) * 3 * indexSize;
        const uint64_t indexBufferLength = descriptor->indexBuffer->native->length();
        if (descriptor->indexBufferOffset > indexBufferLength ||
            requiredIndexBytes > indexBufferLength - descriptor->indexBufferOffset) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
    }

    ScopedAutoreleasePool pool;
    auto* geometryDescriptor =
        MTL4::AccelerationStructureTriangleGeometryDescriptor::alloc()->init();
    auto* nativeDescriptor =
        MTL4::PrimitiveAccelerationStructureDescriptor::alloc()->init();
    if (geometryDescriptor == nullptr || nativeDescriptor == nullptr) {
        if (geometryDescriptor != nullptr) {
            geometryDescriptor->release();
        }
        if (nativeDescriptor != nullptr) {
            nativeDescriptor->release();
        }
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    geometryDescriptor->setVertexBuffer(MTL4::BufferRange(
        descriptor->vertexBuffer->native->gpuAddress() + descriptor->vertexBufferOffset,
        vertexBufferLength - descriptor->vertexBufferOffset));
    geometryDescriptor->setVertexFormat(MTL::AttributeFormatFloat3);
    geometryDescriptor->setVertexStride(descriptor->vertexStride);
    geometryDescriptor->setTriangleCount(descriptor->triangleCount);
    geometryDescriptor->setOpaque(descriptor->opaque != 0);
    if (descriptor->indexType != MMTL_INDEX_TYPE_NONE) {
        geometryDescriptor->setIndexBuffer(MTL4::BufferRange(
            descriptor->indexBuffer->native->gpuAddress() + descriptor->indexBufferOffset,
            requiredIndexBytes));
        geometryDescriptor->setIndexType(nativeIndexType);
    }

    const NS::Object* geometryObjects[] = {geometryDescriptor};
    NS::Array* geometryDescriptors = NS::Array::alloc()->init(geometryObjects, 1);
    if (geometryDescriptors == nullptr) {
        nativeDescriptor->release();
        geometryDescriptor->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    nativeDescriptor->setGeometryDescriptors(geometryDescriptors);
    geometryDescriptors->release();

    const uint32_t retainedAllocationCount =
        descriptor->indexBuffer == nullptr ? 1 : 2;
    auto* retainedAllocations =
        new (std::nothrow) MTL::Allocation*[retainedAllocationCount];
    if (retainedAllocations == nullptr) {
        nativeDescriptor->release();
        geometryDescriptor->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    retainedAllocations[0] = descriptor->vertexBuffer->native;
    if (descriptor->indexBuffer != nullptr) {
        retainedAllocations[1] = descriptor->indexBuffer->native;
    }

    const MMTLResult result = newAccelerationStructure(
        device,
        nativeDescriptor,
        retainedAllocations,
        retainedAllocationCount,
        AccelerationStructureKind::triangle,
        outAccelerationStructure);
    if (result != MMTL_SUCCESS) {
        delete[] retainedAllocations;
    }
    nativeDescriptor->release();
    geometryDescriptor->release();
    return result;
}

MMTLResult mmtlCreateInstanceAccelerationStructure(
    MMTLDevice device,
    const MMTLInstanceAccelerationStructureDescriptor* descriptor,
    MMTLAccelerationStructure* outAccelerationStructure)
{
    if (device == nullptr || descriptor == nullptr || outAccelerationStructure == nullptr ||
        descriptor->instances == nullptr || descriptor->instanceCount == 0 ||
        descriptor->instanceCount == std::numeric_limits<uint32_t>::max()) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outAccelerationStructure = nullptr;
    if (!device->native->supportsRaytracing()) {
        return MMTL_ERROR_UNSUPPORTED;
    }

    const uint32_t supportedOptions =
        MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_DISABLE_TRIANGLE_CULLING |
        MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_TRIANGLE_FRONT_FACING_WINDING_COUNTER_CLOCKWISE |
        MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_OPAQUE |
        MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_NON_OPAQUE;
    for (uint32_t index = 0; index < descriptor->instanceCount; ++index) {
        const MMTLAccelerationStructureInstanceDescriptor& instance =
            descriptor->instances[index];
        if (instance.accelerationStructure == nullptr ||
            instance.accelerationStructure->kind != AccelerationStructureKind::triangle ||
            (instance.options & ~supportedOptions) != 0 ||
            ((instance.options & MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_OPAQUE) != 0 &&
             (instance.options & MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_NON_OPAQUE) != 0)) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
    }

    const uint64_t instanceBufferLength =
        static_cast<uint64_t>(descriptor->instanceCount) *
        sizeof(MTL::IndirectAccelerationStructureInstanceDescriptor);
    MTL::Buffer* instanceBuffer = device->native->newBuffer(
        static_cast<NS::UInteger>(instanceBufferLength),
        MTL::ResourceStorageModeShared);
    if (instanceBuffer == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* nativeInstances = static_cast<MTL::IndirectAccelerationStructureInstanceDescriptor*>(
        instanceBuffer->contents());
    for (uint32_t index = 0; index < descriptor->instanceCount; ++index) {
        const MMTLAccelerationStructureInstanceDescriptor& instance =
            descriptor->instances[index];
        for (uint32_t column = 0; column < 4; ++column) {
            nativeInstances[index].transformationMatrix[column].x =
                instance.transformationMatrix[column];
            nativeInstances[index].transformationMatrix[column].y =
                instance.transformationMatrix[4 + column];
            nativeInstances[index].transformationMatrix[column].z =
                instance.transformationMatrix[8 + column];
        }
        nativeInstances[index].options =
            static_cast<MTL::AccelerationStructureInstanceOptions>(instance.options);
        nativeInstances[index].mask = instance.mask;
        nativeInstances[index].intersectionFunctionTableOffset = 0;
        nativeInstances[index].userID = instance.userID;
        nativeInstances[index].accelerationStructureID =
            instance.accelerationStructure->native->gpuResourceID();
    }

    ScopedAutoreleasePool pool;
    auto* nativeDescriptor =
        MTL4::InstanceAccelerationStructureDescriptor::alloc()->init();
    if (nativeDescriptor == nullptr) {
        instanceBuffer->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    nativeDescriptor->setInstanceCount(descriptor->instanceCount);
    nativeDescriptor->setInstanceDescriptorBuffer(MTL4::BufferRange(
        instanceBuffer->gpuAddress(),
        instanceBufferLength));
    nativeDescriptor->setInstanceDescriptorStride(
        sizeof(MTL::IndirectAccelerationStructureInstanceDescriptor));
    nativeDescriptor->setInstanceDescriptorType(
        MTL::AccelerationStructureInstanceDescriptorTypeIndirect);
    nativeDescriptor->setInstanceTransformationMatrixLayout(MTL::MatrixLayoutColumnMajor);

    const uint32_t retainedAllocationCount = descriptor->instanceCount + 1;
    auto* retainedAllocations =
        new (std::nothrow) MTL::Allocation*[retainedAllocationCount];
    if (retainedAllocations == nullptr) {
        nativeDescriptor->release();
        instanceBuffer->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    retainedAllocations[0] = instanceBuffer;
    for (uint32_t index = 0; index < descriptor->instanceCount; ++index) {
        retainedAllocations[index + 1] =
            descriptor->instances[index].accelerationStructure->native;
    }

    const MMTLResult result = newAccelerationStructure(
        device,
        nativeDescriptor,
        retainedAllocations,
        retainedAllocationCount,
        AccelerationStructureKind::instance,
        outAccelerationStructure);
    if (result != MMTL_SUCCESS) {
        delete[] retainedAllocations;
    }
    nativeDescriptor->release();
    instanceBuffer->release();
    return result;
}

void mmtlDestroyAccelerationStructure(MMTLAccelerationStructure accelerationStructure)
{
    if (accelerationStructure == nullptr) {
        return;
    }
    for (uint32_t index = 0;
         index < accelerationStructure->retainedAllocationCount;
         ++index) {
        accelerationStructure->retainedAllocations[index]->release();
    }
    delete[] accelerationStructure->retainedAllocations;
    accelerationStructure->scratchBuffer->release();
    accelerationStructure->buildDescriptor->release();
    accelerationStructure->native->release();
    delete accelerationStructure;
}

uint64_t mmtlGetAccelerationStructureSize(MMTLAccelerationStructure accelerationStructure)
{
    return accelerationStructure == nullptr ? 0 : accelerationStructure->native->size();
}

MMTLResult mmtlCmdBuildAccelerationStructure(
    MMTLCommandBuffer commandBuffer,
    MMTLAccelerationStructure accelerationStructure)
{
    if (commandBuffer == nullptr || accelerationStructure == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (commandBuffer->state != CommandBufferState::recording) {
        return MMTL_ERROR_INVALID_STATE;
    }

    const MMTLResult residencyResult = ensureResidencySet(commandBuffer);
    if (residencyResult != MMTL_SUCCESS) {
        return residencyResult;
    }
    addResidentAllocation(commandBuffer, accelerationStructure->native);
    addResidentAllocation(commandBuffer, accelerationStructure->scratchBuffer);
    for (uint32_t index = 0;
         index < accelerationStructure->retainedAllocationCount;
         ++index) {
        addResidentAllocation(
            commandBuffer,
            accelerationStructure->retainedAllocations[index]);
    }
    commandBuffer->residencySet->commit();

    ScopedAutoreleasePool pool;
    MTL4::ComputeCommandEncoder* encoder = commandBuffer->native->computeCommandEncoder();
    if (encoder == nullptr) {
        return MMTL_ERROR_INTERNAL;
    }
    encoder->buildAccelerationStructure(
        accelerationStructure->native,
        accelerationStructure->buildDescriptor,
        MTL4::BufferRange(
            accelerationStructure->scratchBuffer->gpuAddress(),
            accelerationStructure->scratchBuffer->length()));
    encoder->barrierAfterStages(
        MTL::StageAccelerationStructure,
        MTL::StageAccelerationStructure | MTL::StageDispatch,
        MTL4::VisibilityOptionDevice);
    encoder->endEncoding();
    return MMTL_SUCCESS;
}

} // extern "C"

