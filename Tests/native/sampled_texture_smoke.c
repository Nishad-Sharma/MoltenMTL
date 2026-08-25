#include <MoltenMTL/MoltenMTL.h>

#include "shader_source.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define CHECK(call)                                                                 \
    do {                                                                            \
        const MMTLResult resultValue = (call);                                       \
        if (resultValue != MMTL_SUCCESS) {                                           \
            fprintf(stderr, "%s failed with result %d\n", #call, (int)resultValue); \
            return 1;                                                               \
        }                                                                           \
    } while (0)

static void fillStagingTexture(
    MMTLBuffer stagingBuffer,
    uint64_t bytesPerRow,
    uint32_t width,
    uint32_t height,
    const float color[4])
{
    uint8_t* bytes = mmtlGetBufferContents(stagingBuffer);
    for (uint32_t y = 0; y < height; ++y) {
        float* row = (float*)(bytes + y * bytesPerRow);
        for (uint32_t x = 0; x < width; ++x) {
            for (uint32_t channel = 0; channel < 4; ++channel) {
                row[x * 4 + channel] = color[channel];
            }
        }
    }
}

static void fillStagingTextureRGBA8(
    MMTLBuffer stagingBuffer,
    uint64_t bytesPerRow,
    uint32_t width,
    uint32_t height,
    const uint8_t color[4])
{
    uint8_t* bytes = mmtlGetBufferContents(stagingBuffer);
    for (uint32_t y = 0; y < height; ++y) {
        uint8_t* row = bytes + y * bytesPerRow;
        for (uint32_t x = 0; x < width; ++x) {
            for (uint32_t channel = 0; channel < 4; ++channel) {
                row[x * 4 + channel] = color[channel];
            }
        }
    }
}

int runSampledTextureSmoke(const char* shaderPath)
{
    const uint32_t width = 2;
    const uint32_t height = 2;
    const uint64_t bytesPerRow = MMTL_TEXTURE_COPY_BYTES_PER_ROW_ALIGNMENT;

    MMTLDevice device = NULL;
    MMTLCommandQueue queue = NULL;
    MMTLCommandAllocator allocator = NULL;
    MMTLCommandBuffer commandBuffer = NULL;
    MMTLBuffer firstStagingBuffer = NULL;
    MMTLBuffer secondStagingBuffer = NULL;
    MMTLBuffer readbackBuffer = NULL;
    MMTLTexture firstTexture = NULL;
    MMTLTexture secondTexture = NULL;
    MMTLTexture outputTexture = NULL;
    MMTLSampler sampler = NULL;
    MMTLLibrary library = NULL;
    MMTLComputePipelineState pipelineState = NULL;
    MMTLArgumentTable argumentTable = NULL;

    CHECK(mmtlCreateDevice(&device));
    CHECK(mmtlCreateCommandQueue(device, &queue));
    CHECK(mmtlCreateCommandAllocator(device, &allocator));
    CHECK(mmtlCreateCommandBuffer(device, &commandBuffer));

    const MMTLBufferDescriptor transferBufferDescriptor = {
        .length = bytesPerRow * height,
        .storageMode = MMTL_STORAGE_MODE_SHARED,
    };
    CHECK(mmtlCreateBuffer(device, &transferBufferDescriptor, &firstStagingBuffer));
    CHECK(mmtlCreateBuffer(device, &transferBufferDescriptor, &secondStagingBuffer));
    CHECK(mmtlCreateBuffer(device, &transferBufferDescriptor, &readbackBuffer));

    const uint8_t firstColor[4] = {128, 0, 0, 255};
    const float secondColor[4] = {0.0f, 0.0f, 1.0f, 1.0f};
    fillStagingTextureRGBA8(firstStagingBuffer, bytesPerRow, width, height, firstColor);
    fillStagingTexture(secondStagingBuffer, bytesPerRow, width, height, secondColor);

    const MMTLTextureDescriptor firstTextureDescriptor = {
        .width = width,
        .height = height,
        .pixelFormat = MMTL_PIXEL_FORMAT_RGBA8_UNORM_SRGB,
        .usage = MMTL_TEXTURE_USAGE_SHADER_READ | MMTL_TEXTURE_USAGE_COPY_DESTINATION,
        .storageMode = MMTL_STORAGE_MODE_PRIVATE,
    };
    const MMTLTextureDescriptor secondTextureDescriptor = {
        .width = width,
        .height = height,
        .pixelFormat = MMTL_PIXEL_FORMAT_RGBA32_FLOAT,
        .usage = MMTL_TEXTURE_USAGE_SHADER_READ | MMTL_TEXTURE_USAGE_COPY_DESTINATION,
        .storageMode = MMTL_STORAGE_MODE_PRIVATE,
    };
    CHECK(mmtlCreateTexture(device, &firstTextureDescriptor, &firstTexture));
    CHECK(mmtlCreateTexture(device, &secondTextureDescriptor, &secondTexture));

    const MMTLTextureDescriptor outputTextureDescriptor = {
        .width = width,
        .height = height,
        .pixelFormat = MMTL_PIXEL_FORMAT_RGBA32_FLOAT,
        .usage = MMTL_TEXTURE_USAGE_SHADER_WRITE | MMTL_TEXTURE_USAGE_COPY_SOURCE,
        .storageMode = MMTL_STORAGE_MODE_PRIVATE,
    };
    CHECK(mmtlCreateTexture(device, &outputTextureDescriptor, &outputTexture));

    const MMTLSamplerDescriptor samplerDescriptor = {
        .minFilter = MMTL_SAMPLER_FILTER_LINEAR,
        .magFilter = MMTL_SAMPLER_FILTER_LINEAR,
        .mipFilter = MMTL_SAMPLER_MIP_FILTER_NOT_MIPMAPPED,
        .addressModeU = MMTL_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .addressModeV = MMTL_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .addressModeW = MMTL_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    };
    CHECK(mmtlCreateSampler(device, &samplerDescriptor, &sampler));

    char* shaderSource = readShaderSource(shaderPath);
    if (shaderSource == NULL) {
        fprintf(stderr, "failed to read sampled-texture shader: %s\n", shaderPath);
        return 1;
    }
    const MMTLLibraryDescriptor libraryDescriptor = {
        .source = shaderSource,
        .moduleName = "sampledTexture",
        .sourcePath = shaderPath,
    };
    const MMTLResult libraryResult = mmtlCreateLibrary(device, &libraryDescriptor, &library);
    free(shaderSource);
    if (libraryResult != MMTL_SUCCESS) {
        fprintf(
            stderr,
            "mmtlCreateLibrary failed with result %d: %s\n",
            (int)libraryResult,
            mmtlGetLastShaderError(device));
        return 1;
    }
    CHECK(mmtlCreateComputePipelineState(device, library, "sampleTextures", &pipelineState));

    const MMTLArgumentTableDescriptor argumentTableDescriptor = {
        .maxTextureBindCount = 3,
        .maxSamplerBindCount = 1,
    };
    CHECK(mmtlCreateArgumentTable(device, &argumentTableDescriptor, &argumentTable));
    const MMTLTexture inputTextures[] = {firstTexture, secondTexture};
    CHECK(mmtlSetArgumentTableTextures(argumentTable, 0, inputTextures, 2));
    CHECK(mmtlSetArgumentTableTexture(argumentTable, 2, outputTexture));
    CHECK(mmtlSetArgumentTableSampler(argumentTable, 0, sampler));

    CHECK(mmtlBeginCommandBuffer(commandBuffer, allocator));
    CHECK(mmtlCmdCopyBufferToTexture(
        commandBuffer,
        firstStagingBuffer,
        0,
        bytesPerRow,
        firstTexture));
    CHECK(mmtlCmdCopyBufferToTexture(
        commandBuffer,
        secondStagingBuffer,
        0,
        bytesPerRow,
        secondTexture));
    CHECK(mmtlCmdDispatchThreads(
        commandBuffer,
        pipelineState,
        argumentTable,
        (MMTLSize){.width = width, .height = height, .depth = 1},
        (MMTLSize){.width = width, .height = height, .depth = 1}));
    CHECK(mmtlCmdCopyTextureToBuffer(
        commandBuffer,
        outputTexture,
        readbackBuffer,
        0,
        bytesPerRow));
    CHECK(mmtlEndCommandBuffer(commandBuffer));
    CHECK(mmtlQueueSubmit(queue, &commandBuffer, 1));
    CHECK(mmtlQueueWaitIdle(queue));

    const uint8_t* readbackBytes = mmtlGetBufferContents(readbackBuffer);
    for (uint32_t y = 0; y < height; ++y) {
        const float* row = (const float*)(readbackBytes + y * bytesPerRow);
        for (uint32_t x = 0; x < width; ++x) {
            const float* pixel = row + x * 4;
            const float expected[4] = {0.0539651f, 0.0f, 0.75f, 1.0f};
            for (uint32_t channel = 0; channel < 4; ++channel) {
                const float difference = pixel[channel] - expected[channel];
                if (difference < -0.00001f || difference > 0.00001f) {
                    fprintf(
                        stderr,
                        "unexpected sampled pixel (%u, %u) channel %u: got %f, expected %f\n",
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
    mmtlDestroySampler(sampler);
    mmtlDestroyTexture(outputTexture);
    mmtlDestroyTexture(secondTexture);
    mmtlDestroyTexture(firstTexture);
    mmtlDestroyBuffer(readbackBuffer);
    mmtlDestroyBuffer(secondStagingBuffer);
    mmtlDestroyBuffer(firstStagingBuffer);
    mmtlDestroyCommandBuffer(commandBuffer);
    mmtlDestroyCommandAllocator(allocator);
    mmtlDestroyCommandQueue(queue);
    mmtlDestroyDevice(device);

    puts("sampled texture-array, sRGB decode, and upload smoke test passed");
    return 0;
}
