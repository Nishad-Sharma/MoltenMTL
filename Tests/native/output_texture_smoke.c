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
    "kernel void writeOutput(texture2d<float, access::write> output [[texture(0)]], "
    "uint2 position [[thread_position_in_grid]])\n"
    "{\n"
    "    output.write(float4(float(position.x) + 0.25f, "
    "float(position.y) + 0.5f, 0.75f, 1.0f), position);\n"
    "}\n";

int main(void)
{
    const uint32_t width = 4;
    const uint32_t height = 2;
    const uint64_t bytesPerRow = MMTL_TEXTURE_COPY_BYTES_PER_ROW_ALIGNMENT;

    MMTLDevice device = NULL;
    MMTLCommandQueue queue = NULL;
    MMTLCommandAllocator allocator = NULL;
    MMTLCommandBuffer commandBuffer = NULL;
    MMTLTexture outputTexture = NULL;
    MMTLTexture copiedTexture = NULL;
    MMTLBuffer readbackBuffer = NULL;
    MMTLLibrary library = NULL;
    MMTLComputePipelineState pipelineState = NULL;
    MMTLArgumentTable argumentTable = NULL;

    CHECK(mmtlCreateDevice(&device));
    CHECK(mmtlCreateCommandQueue(device, &queue));
    CHECK(mmtlCreateCommandAllocator(device, &allocator));
    CHECK(mmtlCreateCommandBuffer(device, &commandBuffer));

    const MMTLTextureDescriptor outputDescriptor = {
        .width = width,
        .height = height,
        .pixelFormat = MMTL_PIXEL_FORMAT_RGBA32_FLOAT,
        .usage = MMTL_TEXTURE_USAGE_SHADER_WRITE | MMTL_TEXTURE_USAGE_COPY_SOURCE,
        .storageMode = MMTL_STORAGE_MODE_PRIVATE,
    };
    CHECK(mmtlCreateTexture(device, &outputDescriptor, &outputTexture));
    if (mmtlGetTextureWidth(outputTexture) != width ||
        mmtlGetTextureHeight(outputTexture) != height ||
        mmtlGetTexturePixelFormat(outputTexture) != outputDescriptor.pixelFormat ||
        mmtlGetTextureUsage(outputTexture) != outputDescriptor.usage) {
        fprintf(stderr, "texture properties do not match its descriptor\n");
        return 1;
    }

    MMTLTextureDescriptor copyDescriptor = outputDescriptor;
    copyDescriptor.usage =
        MMTL_TEXTURE_USAGE_COPY_SOURCE | MMTL_TEXTURE_USAGE_COPY_DESTINATION;
    CHECK(mmtlCreateTexture(device, &copyDescriptor, &copiedTexture));

    const MMTLBufferDescriptor readbackDescriptor = {
        .length = bytesPerRow * height,
        .storageMode = MMTL_STORAGE_MODE_SHARED,
    };
    CHECK(mmtlCreateBuffer(device, &readbackDescriptor, &readbackBuffer));
    uint8_t* readbackBytes = mmtlGetBufferContents(readbackBuffer);
    if (readbackBytes == NULL) {
        fprintf(stderr, "readback buffer is not CPU-visible\n");
        return 1;
    }

    CHECK(mmtlCreateLibraryWithSource(device, computeSource, &library));
    CHECK(mmtlCreateComputePipelineState(device, library, "writeOutput", &pipelineState));

    const MMTLArgumentTableDescriptor argumentTableDescriptor = {
        .maxBufferBindCount = 0,
        .maxTextureBindCount = 1,
    };
    CHECK(mmtlCreateArgumentTable(device, &argumentTableDescriptor, &argumentTable));
    CHECK(mmtlSetArgumentTableTexture(argumentTable, 0, outputTexture));

    CHECK(mmtlBeginCommandBuffer(commandBuffer, allocator));
    CHECK(mmtlCmdDispatchThreads(
        commandBuffer,
        pipelineState,
        argumentTable,
        (MMTLSize){.width = width, .height = height, .depth = 1},
        (MMTLSize){.width = width, .height = height, .depth = 1}));
    CHECK(mmtlCmdCopyTexture(commandBuffer, outputTexture, copiedTexture));
    CHECK(mmtlCmdCopyTextureToBuffer(
        commandBuffer,
        copiedTexture,
        readbackBuffer,
        0,
        bytesPerRow));
    CHECK(mmtlEndCommandBuffer(commandBuffer));
    CHECK(mmtlQueueSubmit(queue, &commandBuffer, 1));
    CHECK(mmtlQueueWaitIdle(queue));

    for (uint32_t y = 0; y < height; ++y) {
        const float* row = (const float*)(readbackBytes + y * bytesPerRow);
        for (uint32_t x = 0; x < width; ++x) {
            const float* pixel = row + x * 4;
            const float expected[] = {(float)x + 0.25f, (float)y + 0.5f, 0.75f, 1.0f};
            for (uint32_t channel = 0; channel < 4; ++channel) {
                if (pixel[channel] != expected[channel]) {
                    fprintf(
                        stderr,
                        "unexpected pixel (%u, %u) channel %u: got %f, expected %f\n",
                        x,
                        y,
                        channel,
                        pixel[channel],
                        expected[channel]);
                    return 1;
                }
            }
        }
    }

    mmtlDestroyArgumentTable(argumentTable);
    mmtlDestroyComputePipelineState(pipelineState);
    mmtlDestroyLibrary(library);
    mmtlDestroyBuffer(readbackBuffer);
    mmtlDestroyTexture(copiedTexture);
    mmtlDestroyTexture(outputTexture);
    mmtlDestroyCommandBuffer(commandBuffer);
    mmtlDestroyCommandAllocator(allocator);
    mmtlDestroyCommandQueue(queue);
    mmtlDestroyDevice(device);

    puts("output-texture compute and copy smoke test passed");
    return 0;
}
