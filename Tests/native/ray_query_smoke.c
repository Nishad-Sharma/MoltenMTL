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

typedef struct Vertex {
    float x;
    float y;
    float z;
} Vertex;

static const char* rayQuerySource =
    "#include <metal_stdlib>\n"
    "#include <metal_raytracing>\n"
    "using namespace metal;\n"
    "using namespace raytracing;\n"
    "kernel void traceScene(instance_acceleration_structure scene [[buffer(0)]], "
    "device uint* results [[buffer(1)]], "
    "uint index [[thread_position_in_grid]])\n"
    "{\n"
    "    ray queryRay;\n"
    "    queryRay.origin = index == 0 ? float3(0.0f, 0.0f, -1.0f) "
    ": (index == 1 ? float3(3.0f, 0.0f, -1.0f) "
    ": float3(6.0f, 6.0f, -1.0f));\n"
    "    queryRay.direction = float3(0.0f, 0.0f, 1.0f);\n"
    "    queryRay.min_distance = 0.001f;\n"
    "    queryRay.max_distance = 10.0f;\n"
    "    intersector<instancing, triangle_data> rayIntersector;\n"
    "    rayIntersector.assume_geometry_type(geometry_type::triangle);\n"
    "    auto intersection = rayIntersector.intersect(queryRay, scene, 0xff);\n"
    "    results[index] = intersection.type != intersection_type::none;\n"
    "}\n";

int main(void)
{
    MMTLDevice device = NULL;
    MMTLCommandQueue queue = NULL;
    MMTLCommandAllocator allocator = NULL;
    MMTLCommandBuffer commandBuffer = NULL;
    MMTLBuffer vertexBuffer = NULL;
    MMTLBuffer indexBuffer = NULL;
    MMTLBuffer resultBuffer = NULL;
    MMTLAccelerationStructure blas = NULL;
    MMTLAccelerationStructure indexedBlas = NULL;
    MMTLAccelerationStructure tlas = NULL;
    MMTLLibrary library = NULL;
    MMTLComputePipelineState pipelineState = NULL;
    MMTLArgumentTable argumentTable = NULL;

    CHECK(mmtlCreateDevice(&device));
    CHECK(mmtlCreateCommandQueue(device, &queue));
    CHECK(mmtlCreateCommandAllocator(device, &allocator));
    CHECK(mmtlCreateCommandBuffer(device, &commandBuffer));

    const MMTLBufferDescriptor vertexBufferDescriptor = {
        .length = 3 * sizeof(Vertex),
        .storageMode = MMTL_STORAGE_MODE_SHARED,
    };
    CHECK(mmtlCreateBuffer(device, &vertexBufferDescriptor, &vertexBuffer));
    Vertex* vertices = mmtlGetBufferContents(vertexBuffer);
    if (vertices == NULL) {
        fprintf(stderr, "vertex buffer is not CPU-visible\n");
        return 1;
    }
    vertices[0] = (Vertex){.x = -1.0f, .y = -1.0f, .z = 0.0f};
    vertices[1] = (Vertex){.x = 1.0f, .y = -1.0f, .z = 0.0f};
    vertices[2] = (Vertex){.x = 0.0f, .y = 1.0f, .z = 0.0f};

    const MMTLAccelerationStructureTriangleGeometryDescriptor geometryDescriptor = {
        .vertexBuffer = vertexBuffer,
        .vertexBufferOffset = 0,
        .vertexStride = sizeof(Vertex),
        .triangleCount = 1,
        .indexBuffer = NULL,
        .indexBufferOffset = 0,
        .indexType = MMTL_INDEX_TYPE_NONE,
        .opaque = 1,
    };
    CHECK(mmtlCreateTriangleAccelerationStructure(device, &geometryDescriptor, &blas));
    if (mmtlGetAccelerationStructureSize(blas) == 0) {
        fprintf(stderr, "BLAS allocation has zero size\n");
        return 1;
    }

    const MMTLBufferDescriptor indexBufferDescriptor = {
        .length = 3 * sizeof(uint16_t),
        .storageMode = MMTL_STORAGE_MODE_SHARED,
    };
    CHECK(mmtlCreateBuffer(device, &indexBufferDescriptor, &indexBuffer));
    uint16_t* indices = mmtlGetBufferContents(indexBuffer);
    if (indices == NULL) {
        fprintf(stderr, "index buffer is not CPU-visible\n");
        return 1;
    }
    indices[0] = 0;
    indices[1] = 1;
    indices[2] = 2;

    MMTLAccelerationStructureTriangleGeometryDescriptor indexedGeometryDescriptor =
        geometryDescriptor;
    indexedGeometryDescriptor.indexBuffer = indexBuffer;
    indexedGeometryDescriptor.indexType = MMTL_INDEX_TYPE_UINT16;
    CHECK(mmtlCreateTriangleAccelerationStructure(
        device,
        &indexedGeometryDescriptor,
        &indexedBlas));

    const MMTLAccelerationStructureInstanceDescriptor instances[] = {
        {
            .accelerationStructure = blas,
            .transformationMatrix = {
                1.0f, 0.0f, 0.0f, 0.0f,
                0.0f, 1.0f, 0.0f, 0.0f,
                0.0f, 0.0f, 1.0f, 0.0f,
            },
            .options = MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_DISABLE_TRIANGLE_CULLING |
                MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_OPAQUE,
            .mask = 0xff,
            .userID = 7,
        },
        {
            .accelerationStructure = indexedBlas,
            .transformationMatrix = {
                1.0f, 0.0f, 0.0f, 3.0f,
                0.0f, 1.0f, 0.0f, 0.0f,
                0.0f, 0.0f, 1.0f, 0.0f,
            },
            .options = MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_DISABLE_TRIANGLE_CULLING |
                MMTL_ACCELERATION_STRUCTURE_INSTANCE_OPTION_OPAQUE,
            .mask = 0xff,
            .userID = 8,
        },
    };
    const MMTLInstanceAccelerationStructureDescriptor instanceDescriptor = {
        .instances = instances,
        .instanceCount = 2,
    };
    CHECK(mmtlCreateInstanceAccelerationStructure(device, &instanceDescriptor, &tlas));
    if (mmtlGetAccelerationStructureSize(tlas) == 0) {
        fprintf(stderr, "TLAS allocation has zero size\n");
        return 1;
    }

    const MMTLBufferDescriptor resultBufferDescriptor = {
        .length = 3 * sizeof(uint32_t),
        .storageMode = MMTL_STORAGE_MODE_SHARED,
    };
    CHECK(mmtlCreateBuffer(device, &resultBufferDescriptor, &resultBuffer));
    uint32_t* results = mmtlGetBufferContents(resultBuffer);
    if (results == NULL) {
        fprintf(stderr, "result buffer is not CPU-visible\n");
        return 1;
    }
    results[0] = 0;
    results[1] = 0;
    results[2] = 1;

    CHECK(mmtlCreateLibraryWithSource(device, rayQuerySource, &library));
    CHECK(mmtlCreateComputePipelineState(device, library, "traceScene", &pipelineState));

    const MMTLArgumentTableDescriptor argumentTableDescriptor = {
        .maxBufferBindCount = 2,
    };
    CHECK(mmtlCreateArgumentTable(device, &argumentTableDescriptor, &argumentTable));
    CHECK(mmtlSetArgumentTableAccelerationStructure(argumentTable, 0, tlas));
    CHECK(mmtlSetArgumentTableBuffer(argumentTable, 1, resultBuffer, 0));

    CHECK(mmtlBeginCommandBuffer(commandBuffer, allocator));
    CHECK(mmtlCmdBuildAccelerationStructure(commandBuffer, blas));
    CHECK(mmtlCmdBuildAccelerationStructure(commandBuffer, indexedBlas));
    CHECK(mmtlCmdBuildAccelerationStructure(commandBuffer, tlas));
    CHECK(mmtlCmdDispatchThreads(
        commandBuffer,
        pipelineState,
        argumentTable,
        (MMTLSize){.width = 3, .height = 1, .depth = 1},
        (MMTLSize){.width = 3, .height = 1, .depth = 1}));
    CHECK(mmtlEndCommandBuffer(commandBuffer));
    CHECK(mmtlQueueSubmit(queue, &commandBuffer, 1));
    CHECK(mmtlQueueWaitIdle(queue));

    if (results[0] != 1 || results[1] != 1 || results[2] != 0) {
        fprintf(
            stderr,
            "unexpected ray-query results: got {%u, %u, %u}, expected {1, 1, 0}\n",
            results[0],
            results[1],
            results[2]);
        return 1;
    }

    mmtlDestroyArgumentTable(argumentTable);
    mmtlDestroyComputePipelineState(pipelineState);
    mmtlDestroyLibrary(library);
    mmtlDestroyAccelerationStructure(tlas);
    mmtlDestroyAccelerationStructure(indexedBlas);
    mmtlDestroyAccelerationStructure(blas);
    mmtlDestroyBuffer(resultBuffer);
    mmtlDestroyBuffer(indexBuffer);
    mmtlDestroyBuffer(vertexBuffer);
    mmtlDestroyCommandBuffer(commandBuffer);
    mmtlDestroyCommandAllocator(allocator);
    mmtlDestroyCommandQueue(queue);
    mmtlDestroyDevice(device);

    puts("BLAS/TLAS inline ray-query smoke test passed");
    return 0;
}
