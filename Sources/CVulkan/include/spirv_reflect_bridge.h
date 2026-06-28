#ifndef SPIRV_REFLECT_BRIDGE_H
#define SPIRV_REFLECT_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

// Raw VkDescriptorType integer values — avoids pulling in vulkan.h.
#define SPV_BRIDGE_DESCRIPTOR_TYPE_STORAGE_IMAGE              3
#define SPV_BRIDGE_DESCRIPTOR_TYPE_STORAGE_BUFFER             7
#define SPV_BRIDGE_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR 1000150000

typedef struct {
    uint32_t binding;
    uint32_t set;
    uint32_t descriptorType;  // one of the SPV_BRIDGE_DESCRIPTOR_TYPE_* values
    uint32_t count;           // array size; 1 for non-arrays
} SPIRVBinding;

// Reflects all descriptor bindings from SPIR-V bytecode.
// Returns the number of bindings written into outBindings, or -1 on error.
int spv_get_descriptor_bindings(const void* spirvData,
                                size_t      byteCount,
                                SPIRVBinding* outBindings,
                                int           maxBindings);

#endif // SPIRV_REFLECT_BRIDGE_H
