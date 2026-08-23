#include <MoltenMTL/MoltenMTL.h>

#include <stdio.h>

#define CHECK(call)                                                                 \
    do {                                                                            \
        const MMTLResult resultValue = (call);                                       \
        if (resultValue != MMTL_SUCCESS) {                                           \
            fprintf(stderr, "%s failed with result %d\n", #call, (int)resultValue); \
            return 1;                                                               \
        }                                                                           \
    } while (0)

int runDeviceQueueSmoke(void)
{
    MMTLDevice device = NULL;
    MMTLCommandQueue queue = NULL;
    MMTLCommandAllocator allocator = NULL;
    MMTLCommandBuffer commandBuffer = NULL;

    CHECK(mmtlCreateDevice(&device));
    CHECK(mmtlCreateCommandQueue(device, &queue));
    CHECK(mmtlCreateCommandAllocator(device, &allocator));
    CHECK(mmtlResetCommandAllocator(allocator));
    CHECK(mmtlCreateCommandBuffer(device, &commandBuffer));

    if (mmtlEndCommandBuffer(commandBuffer) != MMTL_ERROR_INVALID_STATE) {
        fprintf(stderr, "ending an idle command buffer should fail\n");
        return 1;
    }

    CHECK(mmtlBeginCommandBuffer(commandBuffer, allocator));

    if (mmtlBeginCommandBuffer(commandBuffer, allocator) != MMTL_ERROR_INVALID_STATE) {
        fprintf(stderr, "beginning a recording command buffer should fail\n");
        return 1;
    }

    CHECK(mmtlEndCommandBuffer(commandBuffer));
    CHECK(mmtlQueueSubmit(queue, &commandBuffer, 1));

    mmtlDestroyCommandBuffer(commandBuffer);
    mmtlDestroyCommandAllocator(allocator);
    mmtlDestroyCommandQueue(queue);
    mmtlDestroyDevice(device);

    puts("device/queue/allocator/command-buffer smoke test passed");
    return 0;
}
