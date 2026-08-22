#define NS_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION
#define METALCPP_SYMBOL_VISIBILITY_HIDDEN

#include <Metal/Metal.hpp>
#include <Metal/MTL4AccelerationStructure.hpp>

#include <MoltenMTL/MoltenMTL.h>

#include <limits>
#include <memory>
#include <new>

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

struct MMTLLibrary_T {
    MTL::Library* native;
};

struct MMTLComputePipelineState_T {
    MTL::ComputePipelineState* native;
};

struct MMTLArgumentTable_T {
    MTL4::ArgumentTable* native;
    MTL::Allocation** resourceBindings;
    uint32_t maxBufferBindCount;
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

static bool isValidSize(MMTLSize size)
{
    return size.width > 0 && size.height > 0 && size.depth > 0;
}

static MTL::Size nativeSize(MMTLSize size)
{
    return MTL::Size(size.width, size.height, size.depth);
}

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

static MMTLResult ensureResidencySet(MMTLCommandBuffer commandBuffer)
{
    if (commandBuffer->residencySet != nullptr) {
        return MMTL_SUCCESS;
    }

    ScopedAutoreleasePool pool;
    auto* descriptor = MTL::ResidencySetDescriptor::alloc()->init();
    if (descriptor == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    descriptor->setInitialCapacity(16);

    NS::Error* error = nullptr;
    MTL::ResidencySet* residencySet =
        commandBuffer->native->device()->newResidencySet(descriptor, &error);
    descriptor->release();
    if (residencySet == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    commandBuffer->native->useResidencySet(residencySet);
    commandBuffer->residencySet = residencySet;
    return MMTL_SUCCESS;
}

static void addResidentAllocation(
    MMTLCommandBuffer commandBuffer,
    const MTL::Allocation* allocation)
{
    if (!commandBuffer->residencySet->containsAllocation(allocation)) {
        commandBuffer->residencySet->addAllocation(allocation);
    }
}

extern "C" {

MMTLResult mmtlCreateDevice(MMTLDevice* outDevice)
{
    if (outDevice == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outDevice = nullptr;

    MTL::Device* native = MTL::CreateSystemDefaultDevice();
    if (native == nullptr) {
        return MMTL_ERROR_NO_DEVICE;
    }
    if (!native->supportsFamily(MTL::GPUFamilyMetal4)) {
        native->release();
        return MMTL_ERROR_UNSUPPORTED;
    }

    ScopedAutoreleasePool pool;
    auto* compilerDescriptor = MTL4::CompilerDescriptor::alloc()->init();
    if (compilerDescriptor == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    NS::Error* error = nullptr;
    MTL4::Compiler* compiler = native->newCompiler(compilerDescriptor, &error);
    compilerDescriptor->release();
    if (compiler == nullptr) {
        native->release();
        return MMTL_ERROR_UNSUPPORTED;
    }

    auto* device = new (std::nothrow) MMTLDevice_T{native, compiler};
    if (device == nullptr) {
        compiler->release();
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outDevice = device;
    return MMTL_SUCCESS;
}

void mmtlDestroyDevice(MMTLDevice device)
{
    if (device == nullptr) {
        return;
    }
    device->compiler->release();
    device->native->release();
    delete device;
}

MMTLResult mmtlCreateCommandQueue(
    MMTLDevice device,
    MMTLCommandQueue* outQueue)
{
    if (device == nullptr || outQueue == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outQueue = nullptr;

    MTL4::CommandQueue* native = device->native->newMTL4CommandQueue();
    if (native == nullptr) {
        return MMTL_ERROR_INTERNAL;
    }

    MTL::SharedEvent* completionEvent = device->native->newSharedEvent();
    if (completionEvent == nullptr) {
        native->release();
        return MMTL_ERROR_INTERNAL;
    }

    auto* queue = new (std::nothrow) MMTLCommandQueue_T{native, completionEvent, 0};
    if (queue == nullptr) {
        completionEvent->release();
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outQueue = queue;
    return MMTL_SUCCESS;
}

void mmtlDestroyCommandQueue(MMTLCommandQueue queue)
{
    if (queue == nullptr) {
        return;
    }
    queue->completionEvent->release();
    queue->native->release();
    delete queue;
}

MMTLResult mmtlQueueWaitIdle(MMTLCommandQueue queue)
{
    if (queue == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (queue->submittedValue == 0) {
        return MMTL_SUCCESS;
    }

    const bool completed = queue->completionEvent->waitUntilSignaledValue(
        queue->submittedValue,
        std::numeric_limits<uint64_t>::max());
    return completed ? MMTL_SUCCESS : MMTL_ERROR_TIMEOUT;
}

MMTLResult mmtlQueueSubmit(
    MMTLCommandQueue queue,
    const MMTLCommandBuffer* commandBuffers,
    uint32_t commandBufferCount)
{
    if (queue == nullptr || commandBuffers == nullptr || commandBufferCount == 0) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    std::unique_ptr<const MTL4::CommandBuffer*[]> nativeBuffers(
        new (std::nothrow) const MTL4::CommandBuffer*[commandBufferCount]);
    if (!nativeBuffers) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    for (uint32_t index = 0; index < commandBufferCount; ++index) {
        const MMTLCommandBuffer commandBuffer = commandBuffers[index];
        if (commandBuffer == nullptr) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        if (commandBuffer->state != CommandBufferState::executable) {
            return MMTL_ERROR_INVALID_STATE;
        }
        nativeBuffers[index] = commandBuffer->native;
    }

    if (queue->submittedValue == std::numeric_limits<uint64_t>::max()) {
        return MMTL_ERROR_INTERNAL;
    }

    queue->native->commit(nativeBuffers.get(), commandBufferCount);
    ++queue->submittedValue;
    queue->native->signalEvent(queue->completionEvent, queue->submittedValue);
    return MMTL_SUCCESS;
}

MMTLResult mmtlCreateCommandAllocator(
    MMTLDevice device,
    MMTLCommandAllocator* outAllocator)
{
    if (device == nullptr || outAllocator == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outAllocator = nullptr;

    MTL4::CommandAllocator* native = device->native->newCommandAllocator();
    if (native == nullptr) {
        return MMTL_ERROR_INTERNAL;
    }

    auto* allocator = new (std::nothrow) MMTLCommandAllocator_T{native};
    if (allocator == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outAllocator = allocator;
    return MMTL_SUCCESS;
}

void mmtlDestroyCommandAllocator(MMTLCommandAllocator allocator)
{
    if (allocator == nullptr) {
        return;
    }
    allocator->native->release();
    delete allocator;
}

MMTLResult mmtlResetCommandAllocator(MMTLCommandAllocator allocator)
{
    if (allocator == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    allocator->native->reset();
    return MMTL_SUCCESS;
}

uint64_t mmtlGetCommandAllocatorAllocatedSize(MMTLCommandAllocator allocator)
{
    return allocator == nullptr ? 0 : allocator->native->allocatedSize();
}

MMTLResult mmtlCreateCommandBuffer(
    MMTLDevice device,
    MMTLCommandBuffer* outCommandBuffer)
{
    if (device == nullptr || outCommandBuffer == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outCommandBuffer = nullptr;

    MTL4::CommandBuffer* native = device->native->newCommandBuffer();
    if (native == nullptr) {
        return MMTL_ERROR_INTERNAL;
    }

    auto* commandBuffer = new (std::nothrow) MMTLCommandBuffer_T{
        native,
        nullptr,
        CommandBufferState::initial,
    };
    if (commandBuffer == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outCommandBuffer = commandBuffer;
    return MMTL_SUCCESS;
}

void mmtlDestroyCommandBuffer(MMTLCommandBuffer commandBuffer)
{
    if (commandBuffer == nullptr) {
        return;
    }
    if (commandBuffer->residencySet != nullptr) {
        commandBuffer->residencySet->release();
    }
    commandBuffer->native->release();
    delete commandBuffer;
}

MMTLResult mmtlBeginCommandBuffer(
    MMTLCommandBuffer commandBuffer,
    MMTLCommandAllocator allocator)
{
    if (commandBuffer == nullptr || allocator == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (commandBuffer->state == CommandBufferState::recording) {
        return MMTL_ERROR_INVALID_STATE;
    }

    if (commandBuffer->residencySet != nullptr) {
        commandBuffer->residencySet->release();
        commandBuffer->residencySet = nullptr;
    }

    commandBuffer->native->beginCommandBuffer(allocator->native);
    commandBuffer->state = CommandBufferState::recording;
    return MMTL_SUCCESS;
}

MMTLResult mmtlEndCommandBuffer(MMTLCommandBuffer commandBuffer)
{
    if (commandBuffer == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (commandBuffer->state != CommandBufferState::recording) {
        return MMTL_ERROR_INVALID_STATE;
    }

    commandBuffer->native->endCommandBuffer();
    commandBuffer->state = CommandBufferState::executable;
    return MMTL_SUCCESS;
}

MMTLResult mmtlCreateBuffer(
    MMTLDevice device,
    const MMTLBufferDescriptor* descriptor,
    MMTLBuffer* outBuffer)
{
    if (device == nullptr || descriptor == nullptr || outBuffer == nullptr ||
        descriptor->length == 0) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outBuffer = nullptr;

    MTL::ResourceOptions options;
    switch (descriptor->storageMode) {
    case MMTL_STORAGE_MODE_SHARED:
        options = MTL::ResourceStorageModeShared;
        break;
    case MMTL_STORAGE_MODE_PRIVATE:
        options = MTL::ResourceStorageModePrivate;
        break;
    default:
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    MTL::Buffer* native = device->native->newBuffer(
        static_cast<NS::UInteger>(descriptor->length),
        options);
    if (native == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* buffer = new (std::nothrow) MMTLBuffer_T{native};
    if (buffer == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outBuffer = buffer;
    return MMTL_SUCCESS;
}

void mmtlDestroyBuffer(MMTLBuffer buffer)
{
    if (buffer == nullptr) {
        return;
    }
    buffer->native->release();
    delete buffer;
}

uint64_t mmtlGetBufferLength(MMTLBuffer buffer)
{
    return buffer == nullptr ? 0 : buffer->native->length();
}

void* mmtlGetBufferContents(MMTLBuffer buffer)
{
    if (buffer == nullptr || buffer->native->storageMode() == MTL::StorageModePrivate) {
        return nullptr;
    }
    return buffer->native->contents();
}

MMTLResult mmtlCreateLibraryWithSource(
    MMTLDevice device,
    const char* source,
    MMTLLibrary* outLibrary)
{
    if (device == nullptr || source == nullptr || source[0] == '\0' || outLibrary == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outLibrary = nullptr;

    ScopedAutoreleasePool pool;
    auto* sourceString = NS::String::string(source, NS::UTF8StringEncoding);
    auto* descriptor = MTL4::LibraryDescriptor::alloc()->init();
    if (sourceString == nullptr || descriptor == nullptr) {
        if (descriptor != nullptr) {
            descriptor->release();
        }
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    descriptor->setSource(sourceString);

    NS::Error* error = nullptr;
    MTL::Library* native = device->compiler->newLibrary(descriptor, &error);
    descriptor->release();
    if (native == nullptr) {
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    auto* library = new (std::nothrow) MMTLLibrary_T{native};
    if (library == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outLibrary = library;
    return MMTL_SUCCESS;
}

void mmtlDestroyLibrary(MMTLLibrary library)
{
    if (library == nullptr) {
        return;
    }
    library->native->release();
    delete library;
}

MMTLResult mmtlCreateComputePipelineState(
    MMTLDevice device,
    MMTLLibrary library,
    const char* functionName,
    MMTLComputePipelineState* outPipelineState)
{
    if (device == nullptr || library == nullptr || functionName == nullptr ||
        functionName[0] == '\0' || outPipelineState == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outPipelineState = nullptr;

    ScopedAutoreleasePool pool;
    auto* name = NS::String::string(functionName, NS::UTF8StringEncoding);
    auto* functionDescriptor = MTL4::LibraryFunctionDescriptor::alloc()->init();
    auto* pipelineDescriptor = MTL4::ComputePipelineDescriptor::alloc()->init();
    if (name == nullptr || functionDescriptor == nullptr || pipelineDescriptor == nullptr) {
        if (functionDescriptor != nullptr) {
            functionDescriptor->release();
        }
        if (pipelineDescriptor != nullptr) {
            pipelineDescriptor->release();
        }
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    functionDescriptor->setLibrary(library->native);
    functionDescriptor->setName(name);
    pipelineDescriptor->setComputeFunctionDescriptor(functionDescriptor);
    functionDescriptor->release();

    NS::Error* error = nullptr;
    MTL::ComputePipelineState* native =
        device->compiler->newComputePipelineState(pipelineDescriptor, nullptr, &error);
    pipelineDescriptor->release();
    if (native == nullptr) {
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    auto* pipelineState = new (std::nothrow) MMTLComputePipelineState_T{native};
    if (pipelineState == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outPipelineState = pipelineState;
    return MMTL_SUCCESS;
}

void mmtlDestroyComputePipelineState(MMTLComputePipelineState pipelineState)
{
    if (pipelineState == nullptr) {
        return;
    }
    pipelineState->native->release();
    delete pipelineState;
}

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

MMTLResult mmtlCreateArgumentTable(
    MMTLDevice device,
    const MMTLArgumentTableDescriptor* descriptor,
    MMTLArgumentTable* outArgumentTable)
{
    if (device == nullptr || descriptor == nullptr || outArgumentTable == nullptr ||
        descriptor->maxBufferBindCount == 0) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outArgumentTable = nullptr;

    ScopedAutoreleasePool pool;
    auto* nativeDescriptor = MTL4::ArgumentTableDescriptor::alloc()->init();
    if (nativeDescriptor == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    nativeDescriptor->setMaxBufferBindCount(descriptor->maxBufferBindCount);
    nativeDescriptor->setInitializeBindings(true);

    NS::Error* error = nullptr;
    MTL4::ArgumentTable* native = device->native->newArgumentTable(nativeDescriptor, &error);
    nativeDescriptor->release();
    if (native == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* resourceBindings =
        new (std::nothrow) MTL::Allocation*[descriptor->maxBufferBindCount]();
    if (resourceBindings == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* argumentTable = new (std::nothrow) MMTLArgumentTable_T{
        native,
        resourceBindings,
        descriptor->maxBufferBindCount,
    };
    if (argumentTable == nullptr) {
        delete[] resourceBindings;
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outArgumentTable = argumentTable;
    return MMTL_SUCCESS;
}

void mmtlDestroyArgumentTable(MMTLArgumentTable argumentTable)
{
    if (argumentTable == nullptr) {
        return;
    }

    for (uint32_t index = 0; index < argumentTable->maxBufferBindCount; ++index) {
        if (argumentTable->resourceBindings[index] != nullptr) {
            argumentTable->resourceBindings[index]->release();
        }
    }
    delete[] argumentTable->resourceBindings;
    argumentTable->native->release();
    delete argumentTable;
}

MMTLResult mmtlSetArgumentTableBuffer(
    MMTLArgumentTable argumentTable,
    uint32_t bindingIndex,
    MMTLBuffer buffer,
    uint64_t offset)
{
    if (argumentTable == nullptr || bindingIndex >= argumentTable->maxBufferBindCount) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (buffer == nullptr) {
        if (offset != 0) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        argumentTable->native->setAddress(0, bindingIndex);
    } else {
        if (offset >= buffer->native->length()) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        buffer->native->retain();
        argumentTable->native->setAddress(buffer->native->gpuAddress() + offset, bindingIndex);
    }

    if (argumentTable->resourceBindings[bindingIndex] != nullptr) {
        argumentTable->resourceBindings[bindingIndex]->release();
    }
    argumentTable->resourceBindings[bindingIndex] =
        buffer == nullptr ? nullptr : buffer->native;
    return MMTL_SUCCESS;
}

MMTLResult mmtlSetArgumentTableAccelerationStructure(
    MMTLArgumentTable argumentTable,
    uint32_t bindingIndex,
    MMTLAccelerationStructure accelerationStructure)
{
    if (argumentTable == nullptr || bindingIndex >= argumentTable->maxBufferBindCount) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    if (accelerationStructure == nullptr) {
        argumentTable->native->setResource(MTL::ResourceID{}, bindingIndex);
    } else {
        accelerationStructure->native->retain();
        argumentTable->native->setResource(
            accelerationStructure->native->gpuResourceID(),
            bindingIndex);
    }

    if (argumentTable->resourceBindings[bindingIndex] != nullptr) {
        argumentTable->resourceBindings[bindingIndex]->release();
    }
    argumentTable->resourceBindings[bindingIndex] =
        accelerationStructure == nullptr ? nullptr : accelerationStructure->native;
    return MMTL_SUCCESS;
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

MMTLResult mmtlCmdDispatchThreads(
    MMTLCommandBuffer commandBuffer,
    MMTLComputePipelineState pipelineState,
    MMTLArgumentTable argumentTable,
    MMTLSize threadsPerGrid,
    MMTLSize threadsPerThreadgroup)
{
    if (commandBuffer == nullptr || pipelineState == nullptr ||
        !isValidSize(threadsPerGrid) || !isValidSize(threadsPerThreadgroup)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (commandBuffer->state != CommandBufferState::recording) {
        return MMTL_ERROR_INVALID_STATE;
    }

    const MMTLResult residencyResult = ensureResidencySet(commandBuffer);
    if (residencyResult != MMTL_SUCCESS) {
        return residencyResult;
    }
    addResidentAllocation(commandBuffer, pipelineState->native);
    if (argumentTable != nullptr) {
        for (uint32_t index = 0; index < argumentTable->maxBufferBindCount; ++index) {
            MTL::Allocation* resource = argumentTable->resourceBindings[index];
            if (resource != nullptr) {
                addResidentAllocation(commandBuffer, resource);
            }
        }
    }
    commandBuffer->residencySet->commit();

    ScopedAutoreleasePool pool;
    MTL4::ComputeCommandEncoder* encoder = commandBuffer->native->computeCommandEncoder();
    if (encoder == nullptr) {
        return MMTL_ERROR_INTERNAL;
    }
    encoder->setComputePipelineState(pipelineState->native);
    encoder->setArgumentTable(argumentTable == nullptr ? nullptr : argumentTable->native);
    encoder->dispatchThreads(nativeSize(threadsPerGrid), nativeSize(threadsPerThreadgroup));
    encoder->endEncoding();
    return MMTL_SUCCESS;
}

} // extern "C"
