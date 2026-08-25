#ifndef METAL_C_MTL4_COMMAND_QUEUE_H
#define METAL_C_MTL4_COMMAND_QUEUE_H
#include <Metal/MTL4CommandBuffer.h>
#include <Metal/MTLDrawable.h>
#include <Metal/MTLEvent.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4CommandQueue MTL4CommandQueue;
METAL_C_EXPORT void MTL4CommandQueueCommit(MTL4CommandQueue* queue, MTL4CommandBuffer* const* commandBuffers, size_t count);
METAL_C_EXPORT void MTL4CommandQueueSignalEvent(MTL4CommandQueue* queue, MTLSharedEvent* event, uint64_t value);
METAL_C_EXPORT void MTL4CommandQueueWaitForEvent(MTL4CommandQueue* queue, MTLSharedEvent* event, uint64_t value);
METAL_C_EXPORT void MTL4CommandQueueWaitForDrawable(MTL4CommandQueue* queue, MTLDrawable* drawable);
METAL_C_EXPORT void MTL4CommandQueueSignalDrawable(MTL4CommandQueue* queue, MTLDrawable* drawable);
#ifdef __cplusplus
}
#endif
#endif
