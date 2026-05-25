#include "CAccelStruct.h"
#include <stddef.h>
#include <assert.h>

// Verify layout matches VkAccelerationStructureInstanceKHR (64 bytes).
_Static_assert(sizeof(CVkInstanceData) == 64,
               "CVkInstanceData layout mismatch with VkAccelerationStructureInstanceKHR");

// ── Function pointer typedefs ─────────────────────────────────────────────────

typedef void (VKAPI_PTR *PFN_getBuildSizes_t)(
    VkDevice,
    VkAccelerationStructureBuildTypeKHR,
    const VkAccelerationStructureBuildGeometryInfoKHR *,
    const uint32_t *,
    VkAccelerationStructureBuildSizesInfoKHR *);

typedef VkResult (VKAPI_PTR *PFN_createAS_t)(
    VkDevice,
    const VkAccelerationStructureCreateInfoKHR *,
    const VkAllocationCallbacks *,
    VkAccelerationStructureKHR *);

typedef void (VKAPI_PTR *PFN_destroyAS_t)(
    VkDevice,
    VkAccelerationStructureKHR,
    const VkAllocationCallbacks *);

typedef VkDeviceAddress (VKAPI_PTR *PFN_getASAddr_t)(
    VkDevice,
    const VkAccelerationStructureDeviceAddressInfoKHR *);

typedef void (VKAPI_PTR *PFN_cmdBuild_t)(
    VkCommandBuffer,
    uint32_t,
    const VkAccelerationStructureBuildGeometryInfoKHR *,
    const VkAccelerationStructureBuildRangeInfoKHR * const *);

typedef VkDeviceAddress (VKAPI_PTR *PFN_getBufAddr_t)(
    VkDevice,
    const VkBufferDeviceAddressInfo *);

// ── Static function pointers ──────────────────────────────────────────────────

static PFN_getBuildSizes_t s_getBuildSizes  = NULL;
static PFN_createAS_t      s_createAS       = NULL;
static PFN_destroyAS_t     s_destroyAS      = NULL;
static PFN_getASAddr_t     s_getASAddr      = NULL;
static PFN_cmdBuild_t      s_cmdBuild       = NULL;
static PFN_getBufAddr_t    s_getBufAddr     = NULL;

// ── Initialiser ───────────────────────────────────────────────────────────────

void CVKAS_init(VkDevice device) {
    s_getBuildSizes = (PFN_getBuildSizes_t)
        vkGetDeviceProcAddr(device, "vkGetAccelerationStructureBuildSizesKHR");
    s_createAS = (PFN_createAS_t)
        vkGetDeviceProcAddr(device, "vkCreateAccelerationStructureKHR");
    s_destroyAS = (PFN_destroyAS_t)
        vkGetDeviceProcAddr(device, "vkDestroyAccelerationStructureKHR");
    s_getASAddr = (PFN_getASAddr_t)
        vkGetDeviceProcAddr(device, "vkGetAccelerationStructureDeviceAddressKHR");
    s_cmdBuild = (PFN_cmdBuild_t)
        vkGetDeviceProcAddr(device, "vkCmdBuildAccelerationStructuresKHR");
    s_getBufAddr = (PFN_getBufAddr_t)
        vkGetDeviceProcAddr(device, "vkGetBufferDeviceAddress");
}

// ── Wrappers ──────────────────────────────────────────────────────────────────

void CVKAS_getAccelerationStructureBuildSizes(
    VkDevice                                             device,
    VkAccelerationStructureBuildTypeKHR                  buildType,
    const VkAccelerationStructureBuildGeometryInfoKHR *  pBuildInfo,
    const uint32_t *                                     pMaxPrimitiveCounts,
    VkAccelerationStructureBuildSizesInfoKHR *           pSizeInfo)
{
    if (s_getBuildSizes)
        s_getBuildSizes(device, buildType, pBuildInfo, pMaxPrimitiveCounts, pSizeInfo);
}

VkResult CVKAS_createAccelerationStructure(
    VkDevice                                     device,
    const VkAccelerationStructureCreateInfoKHR * pCreateInfo,
    VkAccelerationStructureKHR *                 pAccelerationStructure)
{
    if (s_createAS)
        return s_createAS(device, pCreateInfo, NULL, pAccelerationStructure);
    return VK_ERROR_EXTENSION_NOT_PRESENT;
}

void CVKAS_destroyAccelerationStructure(
    VkDevice                   device,
    VkAccelerationStructureKHR accelerationStructure)
{
    if (s_destroyAS && accelerationStructure != VK_NULL_HANDLE)
        s_destroyAS(device, accelerationStructure, NULL);
}

VkDeviceAddress CVKAS_getAccelerationStructureDeviceAddress(
    VkDevice                   device,
    VkAccelerationStructureKHR accelerationStructure)
{
    if (!s_getASAddr) return 0;
    VkAccelerationStructureDeviceAddressInfoKHR info;
    info.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_DEVICE_ADDRESS_INFO_KHR;
    info.pNext = NULL;
    info.accelerationStructure = accelerationStructure;
    return s_getASAddr(device, &info);
}

void CVKAS_cmdBuildAccelerationStructures(
    VkCommandBuffer                                     commandBuffer,
    const VkAccelerationStructureBuildGeometryInfoKHR * pInfo,
    const VkAccelerationStructureBuildRangeInfoKHR *    pRanges)
{
    if (!s_cmdBuild) return;
    // Wrap the single range pointer in a pointer-to-pointer as the API requires.
    const VkAccelerationStructureBuildRangeInfoKHR * const ranges[1] = { pRanges };
    s_cmdBuild(commandBuffer, 1, pInfo, ranges);
}

VkDeviceAddress CVKAS_getBufferDeviceAddress(VkDevice device, VkBuffer buffer)
{
    if (!s_getBufAddr) return 0;
    VkBufferDeviceAddressInfo info;
    info.sType  = VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO;
    info.pNext  = NULL;
    info.buffer = buffer;
    return s_getBufAddr(device, &info);
}
