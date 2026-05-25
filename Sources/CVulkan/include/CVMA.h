#ifndef CVMA_H
#define CVMA_H

// Pure C interface to Vulkan Memory Allocator for Swift consumption.
// The VMA implementation is compiled once in VMA.cpp (C++).
// Swift imports this header via the CVulkan module map.

#include <vulkan/vulkan_core.h>

// ── Opaque VMA handles ────────────────────────────────────────────────────────
// Full struct definitions live in vk_mem_alloc.h (compiled in VMA.cpp only).
typedef struct VmaAllocator_T*  VmaAllocator;
typedef struct VmaAllocation_T* VmaAllocation;

// ── Allocator lifecycle ───────────────────────────────────────────────────────

/// Create a VmaAllocator. Call once after vkCreateDevice.
/// Automatically enables BUFFER_DEVICE_ADDRESS and dynamic function loading.
VkResult CVMA_createAllocator(VkInstance       instance,
                               VkPhysicalDevice physicalDevice,
                               VkDevice         device,
                               uint32_t         apiVersion,
                               VmaAllocator*    pAllocator);

void CVMA_destroyAllocator(VmaAllocator allocator);

// ── Buffer lifecycle ──────────────────────────────────────────────────────────

/// Allocate a VkBuffer via VMA.
/// storageMode: 0 = shared (CPU+GPU, persistently mapped, prefers ReBAR)
///              1 = private (GPU-only, DEVICE_LOCAL)
/// ppMappedData: filled with the persistent CPU pointer for shared buffers,
///               set to NULL for private buffers.
VkResult CVMA_createBuffer(VmaAllocator       allocator,
                            VkDeviceSize       size,
                            VkBufferUsageFlags usage,
                            int                storageMode,
                            VkBuffer*          pBuffer,
                            VmaAllocation*     pAllocation,
                            void**             ppMappedData);

void CVMA_destroyBuffer(VmaAllocator  allocator,
                        VkBuffer      buffer,
                        VmaAllocation allocation);

// ── Image lifecycle ───────────────────────────────────────────────────────────

/// Allocate a 2-D VkImage via VMA (GPU-only, optimal tiling).
/// The image is created in VK_IMAGE_LAYOUT_UNDEFINED — callers must record
/// a layout transition before using the image in shaders or copies.
VkResult CVMA_createImage(VmaAllocator      allocator,
                           uint32_t          width,
                           uint32_t          height,
                           VkFormat          format,
                           VkImageUsageFlags usage,
                           uint32_t          mipLevels,
                           VkImage*          pImage,
                           VmaAllocation*    pAllocation);

void CVMA_destroyImage(VmaAllocator  allocator,
                       VkImage       image,
                       VmaAllocation allocation);

// ── Pool (Heap) ───────────────────────────────────────────────────────────────

typedef struct VmaPool_T* VmaPool;

/// Create a VMA memory pool that backs an MTLHeap.
/// storageMode: 0 = shared (CPU+GPU), 1 = private (GPU-only)
/// size: total bytes to pre-allocate as the pool's single memory block
VkResult CVMA_createPool(VmaAllocator allocator,
                          VkDeviceSize size,
                          int          storageMode,
                          VmaPool*     pPool);

void CVMA_destroyPool(VmaAllocator allocator, VmaPool pool);

/// Return pool statistics.
/// pBlockBytes: total bytes in the pool block; pUsedBytes: bytes currently sub-allocated.
/// Either pointer may be NULL.
void CVMA_getPoolStats(VmaAllocator  allocator,
                       VmaPool       pool,
                       VkDeviceSize* pBlockBytes,
                       VkDeviceSize* pUsedBytes);

/// Allocate a VkBuffer from a VMA pool (sub-allocate from an MTLHeap).
/// storageMode: 0 = shared (persistent CPU map), 1 = private (no CPU map).
VkResult CVMA_createBufferInPool(VmaAllocator       allocator,
                                  VmaPool            pool,
                                  VkDeviceSize       size,
                                  VkBufferUsageFlags usage,
                                  int                storageMode,
                                  VkBuffer*          pBuffer,
                                  VmaAllocation*     pAllocation,
                                  void**             ppMappedData);

/// Allocate a 2-D VkImage from a VMA pool (GPU-only, optimal tiling).
VkResult CVMA_createImageInPool(VmaAllocator      allocator,
                                 VmaPool           pool,
                                 uint32_t          width,
                                 uint32_t          height,
                                 VkFormat          format,
                                 VkImageUsageFlags usage,
                                 uint32_t          mipLevels,
                                 VkImage*          pImage,
                                 VmaAllocation*    pAllocation);

#endif // CVMA_H
