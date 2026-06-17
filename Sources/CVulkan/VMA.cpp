// Compile VMA exactly once.
// STATIC=0 / DYNAMIC=1: VMA loads all vk function pointers at runtime via
// vkGetInstanceProcAddr / vkGetDeviceProcAddr — no extra link-time symbols needed.
// VMA_IMPLEMENTATION, NOMINMAX, WIN32_LEAN_AND_MEAN are provided via cxxSettings in Package.swift.
#define VMA_STATIC_VULKAN_FUNCTIONS  0
#define VMA_DYNAMIC_VULKAN_FUNCTIONS 1
#include <vulkan/vulkan_core.h>
#include <vma/vk_mem_alloc.h>

// All wrapper functions use extern "C" so Swift can call them via CVMA.h.
extern "C" {

// ── Allocator ─────────────────────────────────────────────────────────────────

VkResult CVMA_createAllocator(VkInstance       instance,
                               VkPhysicalDevice physicalDevice,
                               VkDevice         device,
                               uint32_t         apiVersion,
                               VmaAllocator*    pAllocator)
{
    VmaVulkanFunctions vkFns{};
    vkFns.vkGetInstanceProcAddr = vkGetInstanceProcAddr;
    vkFns.vkGetDeviceProcAddr   = vkGetDeviceProcAddr;

    VmaAllocatorCreateInfo ai{};
    ai.flags            = VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT;
    ai.vulkanApiVersion = apiVersion;
    ai.instance         = instance;
    ai.physicalDevice   = physicalDevice;
    ai.device           = device;
    ai.pVulkanFunctions = &vkFns;

    return vmaCreateAllocator(&ai, pAllocator);
}

void CVMA_destroyAllocator(VmaAllocator allocator)
{
    vmaDestroyAllocator(allocator);
}

// ── Buffer ────────────────────────────────────────────────────────────────────

VkResult CVMA_createBuffer(VmaAllocator       allocator,
                            VkDeviceSize       size,
                            VkBufferUsageFlags usage,
                            int                storageMode,
                            VkBuffer*          pBuffer,
                            VmaAllocation*     pAllocation,
                            void**             ppMappedData)
{
    VkBufferCreateInfo bufCI{};
    bufCI.sType       = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufCI.size        = size;
    bufCI.usage       = usage;
    bufCI.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    VmaAllocationCreateInfo allocCI{};
    if (storageMode == 1) {
        // Private — fastest GPU memory, no CPU access
        allocCI.usage = VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE;
    } else {
        // Shared — CPU+GPU; prefer ReBAR (DEVICE_LOCAL|HOST_VISIBLE) if available,
        // otherwise fall back to host-visible system RAM. Persistently mapped.
        allocCI.usage          = VMA_MEMORY_USAGE_AUTO;
        allocCI.flags          = VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT
                               | VMA_ALLOCATION_CREATE_MAPPED_BIT;
        allocCI.preferredFlags = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
    }

    VmaAllocationInfo allocInfo{};
    VkResult result = vmaCreateBuffer(allocator, &bufCI, &allocCI,
                                      pBuffer, pAllocation, &allocInfo);
    if (result == VK_SUCCESS && ppMappedData)
        *ppMappedData = (storageMode == 0) ? allocInfo.pMappedData : nullptr;

    return result;
}

void CVMA_destroyBuffer(VmaAllocator  allocator,
                        VkBuffer      buffer,
                        VmaAllocation allocation)
{
    vmaDestroyBuffer(allocator, buffer, allocation);
}

// ── Image ─────────────────────────────────────────────────────────────────────

VkResult CVMA_createImage(VmaAllocator      allocator,
                           uint32_t          width,
                           uint32_t          height,
                           VkFormat          format,
                           VkImageUsageFlags usage,
                           uint32_t          mipLevels,
                           VkImage*          pImage,
                           VmaAllocation*    pAllocation)
{
    VkImageCreateInfo imageCI{};
    imageCI.sType         = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imageCI.imageType     = VK_IMAGE_TYPE_2D;
    imageCI.format        = format;
    imageCI.extent        = { width, height, 1 };
    imageCI.mipLevels     = (mipLevels > 0) ? mipLevels : 1;
    imageCI.arrayLayers   = 1;
    imageCI.samples       = VK_SAMPLE_COUNT_1_BIT;
    imageCI.tiling        = VK_IMAGE_TILING_OPTIMAL;
    imageCI.usage         = usage;
    imageCI.sharingMode   = VK_SHARING_MODE_EXCLUSIVE;
    imageCI.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    // GPU-only memory — no CPU mapping needed for images (use staging buffers).
    VmaAllocationCreateInfo allocCI{};
    allocCI.usage = VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE;

    return vmaCreateImage(allocator, &imageCI, &allocCI,
                          pImage, pAllocation, nullptr);
}

void CVMA_destroyImage(VmaAllocator  allocator,
                       VkImage       image,
                       VmaAllocation allocation)
{
    vmaDestroyImage(allocator, image, allocation);
}

// ── Pool ──────────────────────────────────────────────────────────────────────

VkResult CVMA_createPool(VmaAllocator allocator,
                          VkDeviceSize size,
                          int          storageMode,
                          VmaPool*     pPool)
{
    // Query the memory type index that VMA would pick for a typical buffer.
    // Using a dummy buffer create info so the pool gets the same memory type
    // as buffers created outside a pool with the same storage mode.
    VkBufferCreateInfo bufCI{};
    bufCI.sType       = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufCI.size        = 1;   // dummy — only usage flags matter for type selection
    bufCI.usage       = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT
                      | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT
                      | VK_BUFFER_USAGE_TRANSFER_SRC_BIT
                      | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    bufCI.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    VmaAllocationCreateInfo allocCI{};
    if (storageMode == 1) {
        allocCI.usage = VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE;
    } else {
        allocCI.usage          = VMA_MEMORY_USAGE_AUTO;
        allocCI.flags          = VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT
                               | VMA_ALLOCATION_CREATE_MAPPED_BIT;
        allocCI.preferredFlags = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
    }

    uint32_t memTypeIndex = 0;
    VkResult r = vmaFindMemoryTypeIndexForBufferInfo(allocator, &bufCI, &allocCI, &memTypeIndex);
    if (r != VK_SUCCESS) return r;

    VmaPoolCreateInfo poolCI{};
    poolCI.memoryTypeIndex = memTypeIndex;
    poolCI.blockSize       = size;
    poolCI.minBlockCount   = 1;   // pre-allocate immediately
    poolCI.maxBlockCount   = 1;   // single fixed-size block, like Metal heaps

    return vmaCreatePool(allocator, &poolCI, pPool);
}

void CVMA_destroyPool(VmaAllocator allocator, VmaPool pool)
{
    vmaDestroyPool(allocator, pool);
}

void CVMA_getPoolStats(VmaAllocator  allocator,
                       VmaPool       pool,
                       VkDeviceSize* pBlockBytes,
                       VkDeviceSize* pUsedBytes)
{
    VmaStatistics stats{};
    vmaGetPoolStatistics(allocator, pool, &stats);
    if (pBlockBytes) *pBlockBytes = stats.blockBytes;
    if (pUsedBytes)  *pUsedBytes  = stats.allocationBytes;
}

VkResult CVMA_createBufferInPool(VmaAllocator       allocator,
                                  VmaPool            pool,
                                  VkDeviceSize       size,
                                  VkBufferUsageFlags usage,
                                  int                storageMode,
                                  VkBuffer*          pBuffer,
                                  VmaAllocation*     pAllocation,
                                  void**             ppMappedData)
{
    VkBufferCreateInfo bufCI{};
    bufCI.sType       = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufCI.size        = size;
    bufCI.usage       = usage;
    bufCI.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    VmaAllocationCreateInfo allocCI{};
    allocCI.pool = pool;
    if (storageMode == 0)
        allocCI.flags = VMA_ALLOCATION_CREATE_MAPPED_BIT;

    VmaAllocationInfo allocInfo{};
    VkResult result = vmaCreateBuffer(allocator, &bufCI, &allocCI,
                                      pBuffer, pAllocation, &allocInfo);
    if (result == VK_SUCCESS && ppMappedData)
        *ppMappedData = (storageMode == 0) ? allocInfo.pMappedData : nullptr;

    return result;
}

VkResult CVMA_createImageInPool(VmaAllocator      allocator,
                                 VmaPool           pool,
                                 uint32_t          width,
                                 uint32_t          height,
                                 VkFormat          format,
                                 VkImageUsageFlags usage,
                                 uint32_t          mipLevels,
                                 VkImage*          pImage,
                                 VmaAllocation*    pAllocation)
{
    VkImageCreateInfo imageCI{};
    imageCI.sType         = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imageCI.imageType     = VK_IMAGE_TYPE_2D;
    imageCI.format        = format;
    imageCI.extent        = { width, height, 1 };
    imageCI.mipLevels     = (mipLevels > 0) ? mipLevels : 1;
    imageCI.arrayLayers   = 1;
    imageCI.samples       = VK_SAMPLE_COUNT_1_BIT;
    imageCI.tiling        = VK_IMAGE_TILING_OPTIMAL;
    imageCI.usage         = usage;
    imageCI.sharingMode   = VK_SHARING_MODE_EXCLUSIVE;
    imageCI.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    VmaAllocationCreateInfo allocCI{};
    allocCI.pool = pool;

    return vmaCreateImage(allocator, &imageCI, &allocCI,
                          pImage, pAllocation, nullptr);
}

} // extern "C"
