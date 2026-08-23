#include <MoltenMTL/MoltenMTL.h>

#include "shader_source.h"

#include <SDL3/SDL.h>
#include <SDL3/SDL_metal.h>

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

static int isNear(uint8_t value, uint8_t expected)
{
    return abs((int)value - (int)expected) <= 1;
}

static MMTLResult acquireSurfaceImage(
    MMTLSurface surface,
    MMTLCommandQueue queue,
    MMTLSurfaceImage* outSurfaceImage)
{
    MMTLResult result = MMTL_NOT_READY;
    for (uint32_t attempt = 0; attempt < 1000 && result == MMTL_NOT_READY; ++attempt) {
        SDL_PumpEvents();
        result = mmtlAcquireNextSurfaceImage(surface, queue, outSurfaceImage);
        if (result == MMTL_NOT_READY) {
            SDL_Delay(1);
        }
    }
    return result;
}

int main(int argumentCount, char** arguments)
{
    if (argumentCount != 2) {
        fprintf(stderr, "usage: surface-presentation-smoke <compute-shader>\n");
        return 1;
    }

    const uint32_t width = 16;
    const uint32_t height = 16;
    const uint64_t bytesPerRow = MMTL_TEXTURE_COPY_BYTES_PER_ROW_ALIGNMENT;

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow(
        "MoltenMTL surface smoke test",
        (int)width,
        (int)height,
        SDL_WINDOW_METAL);
    if (window == NULL) {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_MetalView metalView = SDL_Metal_CreateView(window);
    if (metalView == NULL) {
        fprintf(stderr, "SDL_Metal_CreateView failed: %s\n", SDL_GetError());
        return 1;
    }
    void* metalLayer = SDL_Metal_GetLayer(metalView);
    if (metalLayer == NULL) {
        fprintf(stderr, "SDL_Metal_GetLayer returned NULL\n");
        return 1;
    }

    MMTLDevice device = NULL;
    MMTLCommandQueue queue = NULL;
    MMTLCommandAllocator allocator = NULL;
    MMTLCommandBuffer commandBuffer = NULL;
    MMTLSurface surface = NULL;
    MMTLBuffer readbackBuffer = NULL;
    MMTLLibrary library = NULL;
    MMTLComputePipelineState pipelineState = NULL;
    MMTLArgumentTable argumentTable = NULL;

    CHECK(mmtlCreateDevice(&device));
    CHECK(mmtlCreateCommandQueue(device, &queue));
    CHECK(mmtlCreateCommandAllocator(device, &allocator));
    CHECK(mmtlCreateCommandBuffer(device, &commandBuffer));
    CHECK(mmtlCreateSurfaceFromMetalLayer(device, metalLayer, &surface));

    MMTLSurfaceConfiguration surfaceConfiguration = {
        .width = width,
        .height = height,
        .pixelFormat = MMTL_PIXEL_FORMAT_BGRA8_UNORM,
        .presentMode = MMTL_PRESENT_MODE_FIFO,
        .imageCount = 3,
    };
    CHECK(mmtlConfigureSurface(surface, &surfaceConfiguration));

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

    char* computeSource = readShaderSource(arguments[1]);
    if (computeSource == NULL) {
        fprintf(stderr, "failed to read surface-presentation shader: %s\n", arguments[1]);
        return 1;
    }

    const MMTLLibraryDescriptor libraryDescriptor = {
        .source = computeSource,
        .moduleName = "surfacePresentation",
        .sourcePath = arguments[1],
    };
    const MMTLResult libraryResult = mmtlCreateLibrary(device, &libraryDescriptor, &library);
    free(computeSource);
    if (libraryResult != MMTL_SUCCESS) {
        fprintf(
            stderr,
            "mmtlCreateLibrary failed with result %d: %s\n",
            (int)libraryResult,
            mmtlGetLastShaderError(device));
        return 1;
    }
    CHECK(mmtlCreateComputePipelineState(device, library, "writeSurface", &pipelineState));
    const MMTLArgumentTableDescriptor argumentTableDescriptor = {
        .maxBufferBindCount = 0,
        .maxTextureBindCount = 1,
    };
    CHECK(mmtlCreateArgumentTable(device, &argumentTableDescriptor, &argumentTable));

    MMTLSurfaceImage surfaceImage = {0};
    const MMTLResult acquireResult = acquireSurfaceImage(surface, queue, &surfaceImage);
    if (acquireResult != MMTL_SUCCESS) {
        fprintf(stderr, "mmtlAcquireNextSurfaceImage failed with result %d\n", acquireResult);
        return 1;
    }

    if (mmtlConfigureSurface(surface, &surfaceConfiguration) != MMTL_ERROR_INVALID_STATE) {
        fprintf(stderr, "configuring a surface with an acquired image should fail\n");
        return 1;
    }
    if (mmtlGetTextureWidth(surfaceImage.texture) != width ||
        mmtlGetTextureHeight(surfaceImage.texture) != height ||
        mmtlGetTexturePixelFormat(surfaceImage.texture) != MMTL_PIXEL_FORMAT_BGRA8_UNORM) {
        fprintf(stderr, "acquired surface texture does not match its configuration\n");
        return 1;
    }

    CHECK(mmtlSetArgumentTableTexture(argumentTable, 0, surfaceImage.texture));
    CHECK(mmtlBeginCommandBuffer(commandBuffer, allocator));
    CHECK(mmtlCmdDispatchThreads(
        commandBuffer,
        pipelineState,
        argumentTable,
        (MMTLSize){.width = width, .height = height, .depth = 1},
        (MMTLSize){.width = 8, .height = 8, .depth = 1}));
    CHECK(mmtlCmdCopyTextureToBuffer(
        commandBuffer,
        surfaceImage.texture,
        readbackBuffer,
        0,
        bytesPerRow));
    CHECK(mmtlEndCommandBuffer(commandBuffer));
    CHECK(mmtlQueueSubmit(queue, &commandBuffer, 1));
    CHECK(mmtlQueuePresent(queue, surface, surfaceImage.imageToken));
    CHECK(mmtlQueueWaitIdle(queue));

    if (!isNear(readbackBytes[0], 64) ||
        !isNear(readbackBytes[1], 128) ||
        !isNear(readbackBytes[2], 255) ||
        !isNear(readbackBytes[3], 255)) {
        fprintf(
            stderr,
            "unexpected BGRA surface pixel: got {%u, %u, %u, %u}\n",
            readbackBytes[0],
            readbackBytes[1],
            readbackBytes[2],
            readbackBytes[3]);
        return 1;
    }

    surfaceConfiguration.width = 8;
    surfaceConfiguration.height = 8;
    surfaceConfiguration.presentMode = MMTL_PRESENT_MODE_IMMEDIATE;
    CHECK(mmtlConfigureSurface(surface, &surfaceConfiguration));
    CHECK(mmtlResetCommandAllocator(allocator));

    surfaceImage = (MMTLSurfaceImage){0};
    CHECK(acquireSurfaceImage(surface, queue, &surfaceImage));
    if (mmtlGetTextureWidth(surfaceImage.texture) != surfaceConfiguration.width ||
        mmtlGetTextureHeight(surfaceImage.texture) != surfaceConfiguration.height) {
        fprintf(stderr, "resized surface returned an image with the old dimensions\n");
        return 1;
    }

    CHECK(mmtlSetArgumentTableTexture(argumentTable, 0, surfaceImage.texture));
    CHECK(mmtlBeginCommandBuffer(commandBuffer, allocator));
    CHECK(mmtlCmdDispatchThreads(
        commandBuffer,
        pipelineState,
        argumentTable,
        (MMTLSize){
            .width = surfaceConfiguration.width,
            .height = surfaceConfiguration.height,
            .depth = 1,
        },
        (MMTLSize){.width = 8, .height = 8, .depth = 1}));
    CHECK(mmtlEndCommandBuffer(commandBuffer));
    CHECK(mmtlQueueSubmit(queue, &commandBuffer, 1));
    CHECK(mmtlQueuePresent(queue, surface, surfaceImage.imageToken));
    CHECK(mmtlQueueWaitIdle(queue));

    mmtlDestroyArgumentTable(argumentTable);
    mmtlDestroyComputePipelineState(pipelineState);
    mmtlDestroyLibrary(library);
    mmtlDestroyBuffer(readbackBuffer);
    mmtlDestroySurface(surface);
    mmtlDestroyCommandBuffer(commandBuffer);
    mmtlDestroyCommandAllocator(allocator);
    mmtlDestroyCommandQueue(queue);
    mmtlDestroyDevice(device);
    SDL_Metal_DestroyView(metalView);
    SDL_DestroyWindow(window);
    SDL_Quit();

    puts("SDL Metal surface presentation smoke test passed");
    return 0;
}
