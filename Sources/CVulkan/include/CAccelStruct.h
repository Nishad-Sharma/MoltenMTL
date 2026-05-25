#ifndef CACCELSTRUCT_H
#define CACCELSTRUCT_H

#include <vulkan/vulkan_core.h>
#include <stdint.h>

// ── Instance data layout ──────────────────────────────────────────────────────
// Binary-compatible with VkAccelerationStructureInstanceKHR but uses plain
// integer fields instead of bitfields so Swift can write instances directly.
typedef struct CVkInstanceData {
    float    transform[3][4];   // row-major 3x4 affine matrix (VkTransformMatrixKHR)
    uint32_t customIndexAndMask; // bits[23:0]=instanceCustomIndex, bits[31:24]=mask
    uint32_t sbtOffsetAndFlags;  // bits[23:0]=sbtRecordOffset,   bits[31:24]=instanceFlags
    uint64_t blasAddress;        // VkDeviceAddress of the bottom-level AS
} CVkInstanceData;

// ── Function pointer initialiser ──────────────────────────────────────────────
// Must be called once immediately after vkCreateDevice.
void CVKAS_init(VkDevice device);

// ── Extension function wrappers ───────────────────────────────────────────────

void CVKAS_getAccelerationStructureBuildSizes(
    VkDevice                                             device,
    VkAccelerationStructureBuildTypeKHR                  buildType,
    const VkAccelerationStructureBuildGeometryInfoKHR *  pBuildInfo,
    const uint32_t *                                     pMaxPrimitiveCounts,
    VkAccelerationStructureBuildSizesInfoKHR *           pSizeInfo);

VkResult CVKAS_createAccelerationStructure(
    VkDevice                                     device,
    const VkAccelerationStructureCreateInfoKHR * pCreateInfo,
    VkAccelerationStructureKHR *                 pAccelerationStructure);

void CVKAS_destroyAccelerationStructure(
    VkDevice                   device,
    VkAccelerationStructureKHR accelerationStructure);

VkDeviceAddress CVKAS_getAccelerationStructureDeviceAddress(
    VkDevice                   device,
    VkAccelerationStructureKHR accelerationStructure);

// Simplified wrapper: always submits exactly one build info + its range array.
void CVKAS_cmdBuildAccelerationStructures(
    VkCommandBuffer                                     commandBuffer,
    const VkAccelerationStructureBuildGeometryInfoKHR * pInfo,
    const VkAccelerationStructureBuildRangeInfoKHR *    pRanges);

VkDeviceAddress CVKAS_getBufferDeviceAddress(VkDevice device, VkBuffer buffer);

#endif // CACCELSTRUCT_H
