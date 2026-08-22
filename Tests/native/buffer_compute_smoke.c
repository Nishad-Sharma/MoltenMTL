#include <MoltenMTL/MoltenMTL.h>

#include <stdint.h>
#include <stdio.h>

#define CHECK(call)                                                                 \
    do {                                                                            \
        const MMTLResult resultValue = (call);                                       \
        if (resultValue != MMTL_SUCCESS) {                                           \
            fprintf(stderr, "%s failed with result %d\n", #call, (int)resultValue); \
            return 1;                                                               \
        }                                                                           \
    } while (0)

static const char* computeSource =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "kernel void doubleValues(device uint* values [[buffer(0)]], "
    "uint index [[thread_position_in_grid]])\n"
    "{\n"
    "    values[index] *= 2;\n"
    "}\n";

int main(void)
{
    MMTLDevice device = NULL;
    MMTLCommandQueue queue = NULL;
    MMTLCommandAllocator allocator = NULL;
    MMTLCommandBuffer commandBuffer = NULL;
    MMTLBuffer buffer = NULL;
    MMTLLibrary library = NULL;
    MMTLComputePipelineState pipelineState = NULL;
    MMTLArgumentTable argumentTable = NULL;

    CHECK(mmtlCreateDevice(&device));
    CHECK(mmtlCreateCommandQueue(device, &queue));
    CHECK(mmtlCreateCommandAllocator(device, &allocator));
    CHECK(mmtlCreateCommandBuffer(device, &commandBuffer));

    const MMTLBufferDescriptor bufferDescriptor = {
        .length = 4 * sizeof(uint32_t),
        .storageMode = MMTL_STORAGE_MODE_SHARED,
    };
    CHECK(mmtlCreateBuffer(device, &bufferDescriptor, &buffer));
    if (mmtlGetBufferLength(buffer) != bufferDescriptor.length) {
        fprintf(stderr, "buffer length does not match its descriptor\n");
        return 1;
    }

    uint32_t* values = mmtlGetBufferContents(buffer);
    if (values == NULL) {
        fprintf(stderr, "shared buffer is not CPU-visible\n");
        return 1;
    }
    values[0] = 1;
    values[1] = 2;
    values[2] = 3;
    values[3] = 4;

    CHECK(mmtlCreateLibraryWithSource(device, computeSource, &library));
    CHECK(mmtlCreateComputePipelineState(device, library, "doubleValues", &pipelineState));

    const MMTLArgumentTableDescriptor argumentTableDescriptor = {
        .maxBufferBindCount = 1,
    };
    CHECK(mmtlCreateArgumentTable(device, &argumentTableDescriptor, &argumentTable));
    CHECK(mmtlSetArgumentTableBuffer(argumentTable, 0, buffer, 0));

    CHECK(mmtlBeginCommandBuffer(commandBuffer, allocator));
    CHECK(mmtlCmdDispatchThreads(
        commandBuffer,
        pipelineState,
        argumentTable,
        (MMTLSize){.width = 4, .height = 1, .depth = 1},
        (MMTLSize){.width = 4, .height = 1, .depth = 1}));
    CHECK(mmtlEndCommandBuffer(commandBuffer));
    CHECK(mmtlQueueSubmit(queue, &commandBuffer, 1));
    CHECK(mmtlQueueWaitIdle(queue));

    const uint32_t expected[] = {2, 4, 6, 8};
    for (uint32_t index = 0; index < 4; ++index) {
        if (values[index] != expected[index]) {
            fprintf(
                stderr,
                "unexpected value at index %u: got %u, expected %u\n",
                index,
                values[index],
                expected[index]);
            return 1;
        }
    }

    mmtlDestroyArgumentTable(argumentTable);
    mmtlDestroyComputePipelineState(pipelineState);
    mmtlDestroyLibrary(library);
    mmtlDestroyBuffer(buffer);
    mmtlDestroyCommandBuffer(commandBuffer);
    mmtlDestroyCommandAllocator(allocator);
    mmtlDestroyCommandQueue(queue);
    mmtlDestroyDevice(device);

    puts("buffer compute-dispatch smoke test passed");
    return 0;
}
