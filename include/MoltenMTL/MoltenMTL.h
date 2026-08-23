#ifndef MOLTENMTL_MOLTENMTL_H
#define MOLTENMTL_MOLTENMTL_H

#include <stdint.h>

#if defined(_WIN32)
#    if defined(MMTL_SHARED)
#        if defined(MMTL_BUILDING_LIBRARY)
#            define MMTL_API __declspec(dllexport)
#        else
#            define MMTL_API __declspec(dllimport)
#        endif
#    else
#        define MMTL_API
#    endif
#elif defined(__GNUC__) || defined(__clang__)
#    define MMTL_API __attribute__((visibility("default")))
#else
#    define MMTL_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef int32_t MMTLResult;

enum {
    MMTL_SUCCESS = 0,
    MMTL_NOT_READY = 1,
    MMTL_SUBOPTIMAL = 2,
    MMTL_ERROR_INVALID_ARGUMENT = -1,
    MMTL_ERROR_INVALID_STATE = -2,
    MMTL_ERROR_UNSUPPORTED = -3,
    MMTL_ERROR_NO_DEVICE = -4,
    MMTL_ERROR_OUT_OF_MEMORY = -5,
    MMTL_ERROR_INTERNAL = -6,
    MMTL_ERROR_COMPILATION_FAILED = -7,
    MMTL_ERROR_TIMEOUT = -8,
    MMTL_ERROR_SURFACE_LOST = -9,
    MMTL_ERROR_SURFACE_OUT_OF_DATE = -10,
};

typedef struct MMTLDevice_T* MMTLDevice;
typedef struct MMTLCommandQueue_T* MMTLCommandQueue;
typedef struct MMTLCommandAllocator_T* MMTLCommandAllocator;
typedef struct MMTLCommandBuffer_T* MMTLCommandBuffer;
typedef struct MMTLBuffer_T* MMTLBuffer;
typedef struct MMTLTexture_T* MMTLTexture;
typedef struct MMTLSurface_T* MMTLSurface;
typedef struct MMTLLibrary_T* MMTLLibrary;
typedef struct MMTLComputePipelineState_T* MMTLComputePipelineState;
typedef struct MMTLArgumentTable_T* MMTLArgumentTable;
typedef struct MMTLAccelerationStructure_T* MMTLAccelerationStructure;

typedef uint32_t MMTLStorageMode;

enum {
    MMTL_STORAGE_MODE_SHARED = 0,
    MMTL_STORAGE_MODE_PRIVATE = 1,
};

typedef struct MMTLBufferDescriptor {
    uint64_t length;
    MMTLStorageMode storageMode;
} MMTLBufferDescriptor;

typedef uint32_t MMTLPixelFormat;

enum {
    MMTL_PIXEL_FORMAT_UNDEFINED = 0,
    MMTL_PIXEL_FORMAT_RGBA8_UNORM = 1,
    MMTL_PIXEL_FORMAT_BGRA8_UNORM = 2,
    MMTL_PIXEL_FORMAT_RGBA16_FLOAT = 3,
    MMTL_PIXEL_FORMAT_RGBA32_FLOAT = 4,
};

typedef uint32_t MMTLTextureUsage;

enum {
    MMTL_TEXTURE_USAGE_SHADER_READ = 1u << 0,
    MMTL_TEXTURE_USAGE_SHADER_WRITE = 1u << 1,
    MMTL_TEXTURE_USAGE_COPY_SOURCE = 1u << 2,
    MMTL_TEXTURE_USAGE_COPY_DESTINATION = 1u << 3,
};

enum {
    MMTL_TEXTURE_COPY_BYTES_PER_ROW_ALIGNMENT = 256,
};

/** Describes a single-mip, single-sample 2D texture. */
typedef struct MMTLTextureDescriptor {
    uint32_t width;
    uint32_t height;
    MMTLPixelFormat pixelFormat;
    MMTLTextureUsage usage;
    MMTLStorageMode storageMode;
} MMTLTextureDescriptor;

typedef uint32_t MMTLPresentMode;

enum {
    MMTL_PRESENT_MODE_FIFO = 0,
    MMTL_PRESENT_MODE_IMMEDIATE = 1,
};

typedef struct MMTLSurfaceConfiguration {
    uint32_t width;
    uint32_t height;
    MMTLPixelFormat pixelFormat;
    MMTLPresentMode presentMode;
    uint32_t imageCount;
} MMTLSurfaceConfiguration;

/**
 * One acquired presentation image.
 *
 * texture is borrowed from the surface and remains valid until imageToken is
 * presented or the surface is destroyed. It must not be destroyed directly.
 */
typedef struct MMTLSurfaceImage {
    MMTLTexture texture;
    uint64_t imageToken;
} MMTLSurfaceImage;

typedef struct MMTLArgumentTableDescriptor {
    uint32_t maxBufferBindCount;
    uint32_t maxTextureBindCount;
} MMTLArgumentTableDescriptor;

/**
 * Describes one HLSL/Slang source module.
 *
 * moduleName and sourcePath are optional. sourcePath is used for diagnostics
 * and for resolving includes relative to the source file.
 */
typedef struct MMTLLibraryDescriptor {
    const char* source;
    const char* moduleName;
    const char* sourcePath;
    const char* const* searchPaths;
    uint32_t searchPathCount;
} MMTLLibraryDescriptor;

typedef uint32_t MMTLIndexType;

enum {
    MMTL_INDEX_TYPE_NONE = 0,
    MMTL_INDEX_TYPE_UINT16 = 1,
    MMTL_INDEX_TYPE_UINT32 = 2,
};

typedef uint32_t MMTLAccelerationStructureInstanceOptions;

enum {
    MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_NONE = 0,
    MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_DISABLE_TRIANGLE_CULLING = 1u << 0,
    MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_TRIANGLE_FRONT_FACING_WINDING_COUNTER_CLOCKWISE = 1u << 1,
    MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_OPAQUE = 1u << 2,
    MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_NON_OPAQUE = 1u << 3,
};

/** Describes one tightly or strided triangle geometry for a BLAS. */
typedef struct MMTLAccelerationStructureTriangleGeometryDescriptor {
    MMTLBuffer vertexBuffer;
    uint64_t vertexBufferOffset;
    uint32_t vertexStride;
    uint32_t triangleCount;
    MMTLBuffer indexBuffer;
    uint64_t indexBufferOffset;
    MMTLIndexType indexType;
    uint32_t opaque;
} MMTLAccelerationStructureTriangleGeometryDescriptor;

/**
 * Describes one TLAS instance.
 *
 * transformationMatrix is a row-major affine 3x4 matrix. mask is compared
 * with the ray mask by the shader; a zero mask makes the instance invisible.
 */
typedef struct MMTLAccelerationStructureInstanceDescriptor {
    MMTLAccelerationStructure accelerationStructure;
    float transformationMatrix[12];
    MMTLAccelerationStructureInstanceOptions options;
    uint32_t mask;
    uint32_t userID;
} MMTLAccelerationStructureInstanceDescriptor;

typedef struct MMTLInstanceAccelerationStructureDescriptor {
    const MMTLAccelerationStructureInstanceDescriptor* instances;
    uint32_t instanceCount;
} MMTLInstanceAccelerationStructureDescriptor;

typedef struct MMTLSize {
    uint32_t width;
    uint32_t height;
    uint32_t depth;
} MMTLSize;

/**
 * Creates the system default GPU device.
 *
 * This first backend requires Metal 4. The returned handle is owned by the
 * caller and must be released with mmtlDestroyDevice().
 */
MMTL_API MMTLResult mmtlCreateDevice(MMTLDevice* outDevice);

MMTL_API void mmtlDestroyDevice(MMTLDevice device);

/** Creates an owned Metal 4 command queue. */
MMTL_API MMTLResult mmtlCreateCommandQueue(
    MMTLDevice device,
    MMTLCommandQueue* outQueue);

MMTL_API void mmtlDestroyCommandQueue(MMTLCommandQueue queue);

/** Blocks until all work previously submitted to the queue has completed. */
MMTL_API MMTLResult mmtlQueueWaitIdle(MMTLCommandQueue queue);

/**
 * Submits executable command buffers without waiting for completion.
 *
 * Command buffers must have been ended before submission. Metal retains the
 * native work required by the submission; releasing the C handles afterwards
 * does not cancel submitted work.
 */
MMTL_API MMTLResult mmtlQueueSubmit(
    MMTLCommandQueue queue,
    const MMTLCommandBuffer* commandBuffers,
    uint32_t commandBufferCount);

/** Creates an owned Metal 4 command allocator. */
MMTL_API MMTLResult mmtlCreateCommandAllocator(
    MMTLDevice device,
    MMTLCommandAllocator* outAllocator);

MMTL_API void mmtlDestroyCommandAllocator(MMTLCommandAllocator allocator);

/**
 * Releases the allocator's recorded-command storage for reuse.
 *
 * The caller must ensure that no command buffer using this allocator is still
 * recording or executing on the GPU.
 */
MMTL_API MMTLResult mmtlResetCommandAllocator(MMTLCommandAllocator allocator);

MMTL_API uint64_t mmtlGetCommandAllocatorAllocatedSize(
    MMTLCommandAllocator allocator);

/** Creates an owned, reusable Metal 4 command buffer. */
MMTL_API MMTLResult mmtlCreateCommandBuffer(
    MMTLDevice device,
    MMTLCommandBuffer* outCommandBuffer);

MMTL_API void mmtlDestroyCommandBuffer(MMTLCommandBuffer commandBuffer);

/*
 * Beginning a previously submitted command buffer is only valid after that
 * submission has completed and its allocator is safe to reuse.
 */
MMTL_API MMTLResult mmtlBeginCommandBuffer(
    MMTLCommandBuffer commandBuffer,
    MMTLCommandAllocator allocator);

MMTL_API MMTLResult mmtlEndCommandBuffer(MMTLCommandBuffer commandBuffer);

/** Creates an owned buffer using shared or private storage. */
MMTL_API MMTLResult mmtlCreateBuffer(
    MMTLDevice device,
    const MMTLBufferDescriptor* descriptor,
    MMTLBuffer* outBuffer);

MMTL_API void mmtlDestroyBuffer(MMTLBuffer buffer);

MMTL_API uint64_t mmtlGetBufferLength(MMTLBuffer buffer);

/** Returns NULL for buffers that aren't CPU-visible. */
MMTL_API void* mmtlGetBufferContents(MMTLBuffer buffer);

/** Creates an owned single-mip, single-sample 2D texture. */
MMTL_API MMTLResult mmtlCreateTexture(
    MMTLDevice device,
    const MMTLTextureDescriptor* descriptor,
    MMTLTexture* outTexture);

MMTL_API void mmtlDestroyTexture(MMTLTexture texture);

MMTL_API uint32_t mmtlGetTextureWidth(MMTLTexture texture);

MMTL_API uint32_t mmtlGetTextureHeight(MMTLTexture texture);

MMTL_API MMTLPixelFormat mmtlGetTexturePixelFormat(MMTLTexture texture);

MMTL_API MMTLTextureUsage mmtlGetTextureUsage(MMTLTexture texture);

/**
 * Creates a surface around a CAMetalLayer supplied by the window system.
 *
 * The layer is retained by the surface. SDL applications can obtain it from
 * SDL_Metal_GetLayer() without making MoltenMTL depend on SDL.
 */
MMTL_API MMTLResult mmtlCreateSurfaceFromMetalLayer(
    MMTLDevice device,
    void* metalLayer,
    MMTLSurface* outSurface);

MMTL_API void mmtlDestroySurface(MMTLSurface surface);

/** Configures or resizes the surface when no image is currently acquired. */
MMTL_API MMTLResult mmtlConfigureSurface(
    MMTLSurface surface,
    const MMTLSurfaceConfiguration* configuration);

/**
 * Acquires the next presentation image and schedules its queue-side wait.
 *
 * Returns MMTL_NOT_READY when the window system temporarily has no drawable.
 * Only one not-yet-presented image may be acquired from a surface at a time.
 */
MMTL_API MMTLResult mmtlAcquireNextSurfaceImage(
    MMTLSurface surface,
    MMTLCommandQueue queue,
    MMTLSurfaceImage* outSurfaceImage);

/** Presents an acquired image after work previously submitted to queue. */
MMTL_API MMTLResult mmtlQueuePresent(
    MMTLCommandQueue queue,
    MMTLSurface surface,
    uint64_t imageToken);

/** Parses an HLSL/Slang source module into an owned shader library. */
MMTL_API MMTLResult mmtlCreateLibrary(
    MMTLDevice device,
    const MMTLLibraryDescriptor* descriptor,
    MMTLLibrary* outLibrary);

MMTL_API void mmtlDestroyLibrary(MMTLLibrary library);

/** Creates an owned compute pipeline for a function in a compiled library. */
MMTL_API MMTLResult mmtlCreateComputePipelineState(
    MMTLDevice device,
    MMTLLibrary library,
    const char* functionName,
    MMTLComputePipelineState* outPipelineState);

/**
 * Returns diagnostics from the last shader-library or pipeline operation.
 * The returned pointer remains valid until the next such operation or until
 * the device is destroyed. An empty string means no diagnostics were emitted.
 */
MMTL_API const char* mmtlGetLastShaderError(MMTLDevice device);

MMTL_API void mmtlDestroyComputePipelineState(MMTLComputePipelineState pipelineState);

/**
 * Allocates a bottom-level acceleration structure for one triangle geometry.
 * The vertex format is float3; indexed and non-indexed geometry is supported.
 * Call mmtlCmdBuildAccelerationStructure() before tracing it.
 */
MMTL_API MMTLResult mmtlCreateTriangleAccelerationStructure(
    MMTLDevice device,
    const MMTLAccelerationStructureTriangleGeometryDescriptor* descriptor,
    MMTLAccelerationStructure* outAccelerationStructure);

/**
 * Allocates a top-level acceleration structure and captures its instance data.
 * Call mmtlCmdBuildAccelerationStructure() after its BLAS inputs have
 * been built in the same command buffer or an earlier completed submission.
 */
MMTL_API MMTLResult mmtlCreateInstanceAccelerationStructure(
    MMTLDevice device,
    const MMTLInstanceAccelerationStructureDescriptor* descriptor,
    MMTLAccelerationStructure* outAccelerationStructure);

MMTL_API void mmtlDestroyAccelerationStructure(
    MMTLAccelerationStructure accelerationStructure);

MMTL_API uint64_t mmtlGetAccelerationStructureSize(
    MMTLAccelerationStructure accelerationStructure);

/**
 * Creates an owned Metal 4 argument table with independently indexed buffer
 * and texture binding slots. Acceleration structures use buffer slots.
 */
MMTL_API MMTLResult mmtlCreateArgumentTable(
    MMTLDevice device,
    const MMTLArgumentTableDescriptor* descriptor,
    MMTLArgumentTable* outArgumentTable);

MMTL_API void mmtlDestroyArgumentTable(MMTLArgumentTable argumentTable);

MMTL_API MMTLResult mmtlSetArgumentTableBuffer(
    MMTLArgumentTable argumentTable,
    uint32_t bindingIndex,
    MMTLBuffer buffer,
    uint64_t offset);

MMTL_API MMTLResult mmtlSetArgumentTableAccelerationStructure(
    MMTLArgumentTable argumentTable,
    uint32_t bindingIndex,
    MMTLAccelerationStructure accelerationStructure);

MMTL_API MMTLResult mmtlSetArgumentTableTexture(
    MMTLArgumentTable argumentTable,
    uint32_t bindingIndex,
    MMTLTexture texture);

/**
 * Encodes a BLAS or TLAS build and makes it visible to later builds and
 * dispatches in the command buffer.
 */
MMTL_API MMTLResult mmtlCmdBuildAccelerationStructure(
    MMTLCommandBuffer commandBuffer,
    MMTLAccelerationStructure accelerationStructure);

/**
 * Encodes one compute dispatch into a recording command buffer.
 *
 * The argument table may be NULL when the shader has no resource arguments.
 */
MMTL_API MMTLResult mmtlCmdDispatchThreads(
    MMTLCommandBuffer commandBuffer,
    MMTLComputePipelineState pipelineState,
    MMTLArgumentTable argumentTable,
    MMTLSize threadsPerGrid,
    MMTLSize threadsPerThreadgroup);

/** Copies the complete contents of one compatible 2D texture to another. */
MMTL_API MMTLResult mmtlCmdCopyTexture(
    MMTLCommandBuffer commandBuffer,
    MMTLTexture sourceTexture,
    MMTLTexture destinationTexture);

/**
 * Copies a complete 2D texture into a buffer.
 *
 * destinationBytesPerRow must be at least the tightly packed row size and a
 * multiple of MMTL_TEXTURE_COPY_BYTES_PER_ROW_ALIGNMENT.
 */
MMTL_API MMTLResult mmtlCmdCopyTextureToBuffer(
    MMTLCommandBuffer commandBuffer,
    MMTLTexture sourceTexture,
    MMTLBuffer destinationBuffer,
    uint64_t destinationOffset,
    uint64_t destinationBytesPerRow);

#ifdef __cplusplus
}
#endif

#endif
