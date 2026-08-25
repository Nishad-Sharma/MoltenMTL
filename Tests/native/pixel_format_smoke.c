#include <MoltenMTL/MoltenMTL.h>

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define CHECK(call)                                                                 \
    do {                                                                            \
        const MMTLResult resultValue = (call);                                       \
        if (resultValue != MMTL_SUCCESS) {                                           \
            fprintf(stderr, "%s failed with result %d\n", #call, (int)resultValue); \
            return 1;                                                               \
        }                                                                           \
    } while (0)

typedef struct PixelFormatCase {
    MMTLPixelFormat format;
    uint32_t bytesPerPixel;
    const char* name;
} PixelFormatCase;

static const PixelFormatCase pixelFormatCases[] = {
    {MMTL_PIXEL_FORMAT_R8_UNORM, 1, "R8_UNORM"},
    {MMTL_PIXEL_FORMAT_R8_UNORM_SRGB, 1, "R8_UNORM_SRGB"},
    {MMTL_PIXEL_FORMAT_R8_SNORM, 1, "R8_SNORM"},
    {MMTL_PIXEL_FORMAT_R8_UINT, 1, "R8_UINT"},
    {MMTL_PIXEL_FORMAT_R8_SINT, 1, "R8_SINT"},
    {MMTL_PIXEL_FORMAT_R16_UNORM, 2, "R16_UNORM"},
    {MMTL_PIXEL_FORMAT_R16_SNORM, 2, "R16_SNORM"},
    {MMTL_PIXEL_FORMAT_R16_UINT, 2, "R16_UINT"},
    {MMTL_PIXEL_FORMAT_R16_SINT, 2, "R16_SINT"},
    {MMTL_PIXEL_FORMAT_R16_FLOAT, 2, "R16_FLOAT"},
    {MMTL_PIXEL_FORMAT_R32_UINT, 4, "R32_UINT"},
    {MMTL_PIXEL_FORMAT_R32_SINT, 4, "R32_SINT"},
    {MMTL_PIXEL_FORMAT_R32_FLOAT, 4, "R32_FLOAT"},
    {MMTL_PIXEL_FORMAT_RG8_UNORM, 2, "RG8_UNORM"},
    {MMTL_PIXEL_FORMAT_RG8_UNORM_SRGB, 2, "RG8_UNORM_SRGB"},
    {MMTL_PIXEL_FORMAT_RG8_SNORM, 2, "RG8_SNORM"},
    {MMTL_PIXEL_FORMAT_RG8_UINT, 2, "RG8_UINT"},
    {MMTL_PIXEL_FORMAT_RG8_SINT, 2, "RG8_SINT"},
    {MMTL_PIXEL_FORMAT_RG16_UNORM, 4, "RG16_UNORM"},
    {MMTL_PIXEL_FORMAT_RG16_SNORM, 4, "RG16_SNORM"},
    {MMTL_PIXEL_FORMAT_RG16_UINT, 4, "RG16_UINT"},
    {MMTL_PIXEL_FORMAT_RG16_SINT, 4, "RG16_SINT"},
    {MMTL_PIXEL_FORMAT_RG16_FLOAT, 4, "RG16_FLOAT"},
    {MMTL_PIXEL_FORMAT_RG32_UINT, 8, "RG32_UINT"},
    {MMTL_PIXEL_FORMAT_RG32_SINT, 8, "RG32_SINT"},
    {MMTL_PIXEL_FORMAT_RG32_FLOAT, 8, "RG32_FLOAT"},
    {MMTL_PIXEL_FORMAT_RGBA8_UNORM, 4, "RGBA8_UNORM"},
    {MMTL_PIXEL_FORMAT_RGBA8_UNORM_SRGB, 4, "RGBA8_UNORM_SRGB"},
    {MMTL_PIXEL_FORMAT_RGBA8_SNORM, 4, "RGBA8_SNORM"},
    {MMTL_PIXEL_FORMAT_RGBA8_UINT, 4, "RGBA8_UINT"},
    {MMTL_PIXEL_FORMAT_RGBA8_SINT, 4, "RGBA8_SINT"},
    {MMTL_PIXEL_FORMAT_BGRA8_UNORM, 4, "BGRA8_UNORM"},
    {MMTL_PIXEL_FORMAT_BGRA8_UNORM_SRGB, 4, "BGRA8_UNORM_SRGB"},
    {MMTL_PIXEL_FORMAT_RGBA16_UNORM, 8, "RGBA16_UNORM"},
    {MMTL_PIXEL_FORMAT_RGBA16_SNORM, 8, "RGBA16_SNORM"},
    {MMTL_PIXEL_FORMAT_RGBA16_UINT, 8, "RGBA16_UINT"},
    {MMTL_PIXEL_FORMAT_RGBA16_SINT, 8, "RGBA16_SINT"},
    {MMTL_PIXEL_FORMAT_RGBA16_FLOAT, 8, "RGBA16_FLOAT"},
    {MMTL_PIXEL_FORMAT_RGBA32_UINT, 16, "RGBA32_UINT"},
    {MMTL_PIXEL_FORMAT_RGBA32_SINT, 16, "RGBA32_SINT"},
    {MMTL_PIXEL_FORMAT_RGBA32_FLOAT, 16, "RGBA32_FLOAT"},
    {MMTL_PIXEL_FORMAT_RGB10A2_UNORM, 4, "RGB10A2_UNORM"},
    {MMTL_PIXEL_FORMAT_RGB10A2_UINT, 4, "RGB10A2_UINT"},
    {MMTL_PIXEL_FORMAT_BGR10A2_UNORM, 4, "BGR10A2_UNORM"},
    {MMTL_PIXEL_FORMAT_RG11B10_FLOAT, 4, "RG11B10_FLOAT"},
    {MMTL_PIXEL_FORMAT_RGB9E5_FLOAT, 4, "RGB9E5_FLOAT"},
};

int runPixelFormatSmoke(void)
{
    const uint32_t width = 3;
    const uint32_t height = 2;
    const uint64_t bytesPerRow = MMTL_TEXTURE_COPY_BYTES_PER_ROW_ALIGNMENT;
    const uint64_t bufferLength = bytesPerRow * height;

    MMTLDevice device = NULL;
    MMTLCommandQueue queue = NULL;
    MMTLCommandAllocator allocator = NULL;
    MMTLCommandBuffer commandBuffer = NULL;
    MMTLBuffer uploadBuffer = NULL;
    MMTLBuffer readbackBuffer = NULL;

    CHECK(mmtlCreateDevice(&device));
    CHECK(mmtlCreateCommandQueue(device, &queue));
    CHECK(mmtlCreateCommandAllocator(device, &allocator));
    CHECK(mmtlCreateCommandBuffer(device, &commandBuffer));

    const MMTLBufferDescriptor bufferDescriptor = {
        .length = bufferLength,
        .storageMode = MMTL_STORAGE_MODE_SHARED,
    };
    CHECK(mmtlCreateBuffer(device, &bufferDescriptor, &uploadBuffer));
    CHECK(mmtlCreateBuffer(device, &bufferDescriptor, &readbackBuffer));

    uint8_t* uploadBytes = mmtlGetBufferContents(uploadBuffer);
    uint8_t* readbackBytes = mmtlGetBufferContents(readbackBuffer);
    if (uploadBytes == NULL || readbackBytes == NULL) {
        fprintf(stderr, "pixel-format transfer buffers are not CPU-visible\n");
        return 1;
    }
    for (uint64_t index = 0; index < bufferLength; ++index) {
        uploadBytes[index] = (uint8_t)(index * 37u + 11u);
    }

    const size_t formatCount = sizeof(pixelFormatCases) / sizeof(pixelFormatCases[0]);
    for (size_t formatIndex = 0; formatIndex < formatCount; ++formatIndex) {
        const PixelFormatCase* formatCase = &pixelFormatCases[formatIndex];
        MMTLTexture texture = NULL;
        const MMTLTextureDescriptor textureDescriptor = {
            .width = width,
            .height = height,
            .pixelFormat = formatCase->format,
            .usage = MMTL_TEXTURE_USAGE_COPY_SOURCE |
                MMTL_TEXTURE_USAGE_COPY_DESTINATION,
            .storageMode = MMTL_STORAGE_MODE_PRIVATE,
        };
        const MMTLResult textureResult =
            mmtlCreateTexture(device, &textureDescriptor, &texture);
        if (textureResult != MMTL_SUCCESS) {
            fprintf(
                stderr,
                "creating %s texture failed with result %d\n",
                formatCase->name,
                (int)textureResult);
            return 1;
        }
        if (mmtlGetTexturePixelFormat(texture) != formatCase->format) {
            fprintf(stderr, "%s texture reported the wrong format\n", formatCase->name);
            return 1;
        }

        memset(readbackBytes, 0, (size_t)bufferLength);
        CHECK(mmtlResetCommandAllocator(allocator));
        CHECK(mmtlBeginCommandBuffer(commandBuffer, allocator));
        CHECK(mmtlCmdCopyBufferToTexture(
            commandBuffer,
            uploadBuffer,
            0,
            bytesPerRow,
            texture));
        CHECK(mmtlCmdCopyTextureToBuffer(
            commandBuffer,
            texture,
            readbackBuffer,
            0,
            bytesPerRow));
        CHECK(mmtlEndCommandBuffer(commandBuffer));
        CHECK(mmtlQueueSubmit(queue, &commandBuffer, 1));
        CHECK(mmtlQueueWaitIdle(queue));

        const size_t tightRowBytes = (size_t)width * formatCase->bytesPerPixel;
        for (uint32_t row = 0; row < height; ++row) {
            const size_t rowOffset = (size_t)row * bytesPerRow;
            if (memcmp(
                    uploadBytes + rowOffset,
                    readbackBytes + rowOffset,
                    tightRowBytes) != 0) {
                fprintf(stderr, "%s texture copy round-trip changed data\n", formatCase->name);
                return 1;
            }
        }
        mmtlDestroyTexture(texture);
    }

    mmtlDestroyBuffer(readbackBuffer);
    mmtlDestroyBuffer(uploadBuffer);
    mmtlDestroyCommandBuffer(commandBuffer);
    mmtlDestroyCommandAllocator(allocator);
    mmtlDestroyCommandQueue(queue);
    mmtlDestroyDevice(device);

    puts("common uncompressed pixel-format copy smoke test passed");
    return 0;
}
