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
    MMTL_ERROR_INVALID_ARGUMENT = -1,
    MMTL_ERROR_INVALID_STATE = -2,
    MMTL_ERROR_UNSUPPORTED = -3,
    MMTL_ERROR_NO_DEVICE = -4,
    MMTL_ERROR_OUT_OF_MEMORY = -5,
    MMTL_ERROR_INTERNAL = -6,
    MMTL_ERROR_COMPILATION_FAILED = -7,
    MMTL_ERROR_TIMEOUT = -8,
};

typedef struct MMTLDevice_T* MMTLDevice;
typedef struct MMTLCommandQueue_T* MMTLCommandQueue;
typedef struct MMTLCommandAllocator_T* MMTLCommandAllocator;
typedef struct MMTLCommandBuffer_T* MMTLCommandBuffer;
typedef struct MMTLBuffer_T* MMTLBuffer;
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

typedef struct MMTLArgumentTableDescriptor {
    uint32_t maxBufferBindCount;
} MMTLArgumentTableDescriptor;

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

/** Compiles a Metal Shading Language source string into an owned library. */
MMTL_API MMTLResult mmtlCreateLibraryWithSource(
    MMTLDevice device,
    const char* source,
    MMTLLibrary* outLibrary);

MMTL_API void mmtlDestroyLibrary(MMTLLibrary library);

/** Creates an owned compute pipeline for a function in a compiled library. */
MMTL_API MMTLResult mmtlCreateComputePipelineState(
    MMTLDevice device,
    MMTLLibrary library,
    const char* functionName,
    MMTLComputePipelineState* outPipelineState);

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
 * Creates an owned Metal 4 argument table with buffer-compatible binding slots.
 *
 * Each slot can hold a buffer or acceleration structure. Texture and sampler
 * slots can extend this descriptor separately in a later slice.
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

#ifdef __cplusplus
}
#endif

#endif
