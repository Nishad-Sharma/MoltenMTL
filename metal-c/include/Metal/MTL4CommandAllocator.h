#ifndef METAL_C_MTL4_COMMAND_ALLOCATOR_H
#define METAL_C_MTL4_COMMAND_ALLOCATOR_H
#include <Metal/MTLDefines.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4CommandAllocator MTL4CommandAllocator;
METAL_C_EXPORT void MTL4CommandAllocatorReset(MTL4CommandAllocator* allocator);
METAL_C_EXPORT uint64_t MTL4CommandAllocatorGetAllocatedSize(MTL4CommandAllocator* allocator);
#ifdef __cplusplus
}
#endif
#endif
