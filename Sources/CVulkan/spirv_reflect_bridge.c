#include "spirv_reflect_bridge.h"
#include "spirv_reflect.h"
#include <stdlib.h>

int spv_get_descriptor_bindings(const void*   spirvData,
                                size_t         byteCount,
                                SPIRVBinding*  outBindings,
                                int            maxBindings) {
    SpvReflectShaderModule module;
    SpvReflectResult result = spvReflectCreateShaderModule(byteCount, spirvData, &module);
    if (result != SPV_REFLECT_RESULT_SUCCESS) {
        return -1;
    }

    uint32_t count = 0;
    result = spvReflectEnumerateDescriptorBindings(&module, &count, NULL);
    if (result != SPV_REFLECT_RESULT_SUCCESS) {
        spvReflectDestroyShaderModule(&module);
        return -1;
    }

    SpvReflectDescriptorBinding** bindings =
        (SpvReflectDescriptorBinding**)malloc(count * sizeof(SpvReflectDescriptorBinding*));
    if (!bindings) {
        spvReflectDestroyShaderModule(&module);
        return -1;
    }

    result = spvReflectEnumerateDescriptorBindings(&module, &count, bindings);
    if (result != SPV_REFLECT_RESULT_SUCCESS) {
        free(bindings);
        spvReflectDestroyShaderModule(&module);
        return -1;
    }

    int written = 0;
    for (uint32_t i = 0; i < count && written < maxBindings; i++) {
        outBindings[written].binding        = bindings[i]->binding;
        outBindings[written].set            = bindings[i]->set;
        outBindings[written].descriptorType = (uint32_t)bindings[i]->descriptor_type;
        written++;
    }

    free(bindings);
    spvReflectDestroyShaderModule(&module);
    return written;
}
