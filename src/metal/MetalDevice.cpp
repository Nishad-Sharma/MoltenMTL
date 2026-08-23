#include "MetalBackendInternal.hpp"

#include <limits>
#include <memory>
#include <new>

MMTLResult ensureResidencySet(MMTLCommandBuffer commandBuffer)
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

void addResidentAllocation(
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

    slang::IGlobalSession* slangGlobalSession = nullptr;
    if (SLANG_FAILED(slang::createGlobalSession(&slangGlobalSession))) {
        compiler->release();
        native->release();
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    auto* device = new (std::nothrow) MMTLDevice_T{
        native,
        compiler,
        slangGlobalSession,
        {},
        {},
    };
    if (device == nullptr) {
        slangGlobalSession->release();
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
    device->slangGlobalSession->release();
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

} // extern "C"
