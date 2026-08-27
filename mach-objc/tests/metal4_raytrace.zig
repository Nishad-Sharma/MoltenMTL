const std = @import("std");
const mach = @import("mach-objc");

const mtl = mach.metal;
const ns = mach.foundation;
const objc = mach.objc;

const shader_source =
    \\#include <metal_stdlib>
    \\#include <metal_raytracing>
    \\using namespace metal;
    \\using namespace raytracing;
    \\
    \\kernel void raytrace_triangle(
    \\    primitive_acceleration_structure acceleration_structure [[buffer(0)]],
    \\    device uint* hit [[buffer(1)]])
    \\{
    \\    ray query;
    \\    query.origin = float3(0.0f, 0.0f, 1.0f);
    \\    query.direction = float3(0.0f, 0.0f, -1.0f);
    \\    query.min_distance = 0.0f;
    \\    query.max_distance = 10.0f;
    \\
    \\    intersector<triangle_data> trace;
    \\    const auto intersection = trace.intersect(query, acceleration_structure);
    \\    hit[0] = intersection.type == intersection_type::triangle ? 1u : 0u;
    \\}
;

test "MTL4 raytraces one triangle" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const device = mtl.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();

    if (!objc.respondsTo(device, "newCommandAllocator")) return error.SkipZigTest;
    if (!device.supportsRaytracing()) return error.SkipZigTest;

    const allocator = device.newCommandAllocator() orelse return error.SkipZigTest;
    defer allocator.release();

    const compiler_descriptor = mtl.MTL4CompilerDescriptor.allocInit().?;
    defer compiler_descriptor.release();
    var metal_error: ?*ns.Error = null;
    const compiler = device.newCompilerWithDescriptor_error(
        compiler_descriptor,
        &metal_error,
    ) orelse return reportMetalError(metal_error);
    defer compiler.release();

    const library_descriptor = mtl.MTL4LibraryDescriptor.allocInit().?;
    defer library_descriptor.release();
    library_descriptor.setName(ns.String.stringWithUTF8String("triangle-raytrace"));
    library_descriptor.setSource(ns.String.stringWithUTF8String(shader_source));
    metal_error = null;
    const library = compiler.newLibraryWithDescriptor_error(
        library_descriptor,
        &metal_error,
    ) orelse return reportMetalError(metal_error);
    defer library.release();

    const function_descriptor = mtl.MTL4LibraryFunctionDescriptor.allocInit().?;
    defer function_descriptor.release();
    function_descriptor.setLibrary(library);
    function_descriptor.setName(ns.String.stringWithUTF8String("raytrace_triangle"));

    const pipeline_descriptor = mtl.MTL4ComputePipelineDescriptor.allocInit().?;
    defer pipeline_descriptor.release();
    pipeline_descriptor.setComputeFunctionDescriptor(
        function_descriptor.as(mtl.MTL4FunctionDescriptor),
    );
    metal_error = null;
    const pipeline = compiler.newComputePipelineStateWithDescriptor_compilerTaskOptions_error(
        pipeline_descriptor,
        null,
        &metal_error,
    ) orelse return reportMetalError(metal_error);
    defer pipeline.release();

    const vertices = [_][3]f32{
        .{ -1.0, -1.0, 0.0 },
        .{ 1.0, -1.0, 0.0 },
        .{ 0.0, 1.0, 0.0 },
    };
    const vertex_buffer = device.newBufferWithBytes_length_options(
        @ptrCast(&vertices),
        @sizeOf(@TypeOf(vertices)),
        mtl.ResourceStorageModeShared,
    ) orelse return error.OutOfHostMemory;
    defer vertex_buffer.release();

    const geometry = mtl.MTL4AccelerationStructureTriangleGeometryDescriptor.allocInit().?;
    defer geometry.release();
    geometry.setVertexBuffer(.init(
        vertex_buffer.gpuAddress(),
        @sizeOf(@TypeOf(vertices)),
    ));
    geometry.setVertexFormat(mtl.AttributeFormatFloat3);
    geometry.setVertexStride(@sizeOf(@TypeOf(vertices[0])));
    geometry.setTriangleCount(1);
    geometry.as(mtl.MTL4AccelerationStructureGeometryDescriptor).setOpaque(true);

    const GeometryArray = ns.Array(*mtl.MTL4AccelerationStructureGeometryDescriptor);
    const geometry_descriptors = objc.msgSend(
        GeometryArray.InternalInfo.class(),
        "arrayWithObject:",
        *GeometryArray,
        .{geometry.as(mtl.MTL4AccelerationStructureGeometryDescriptor)},
    );

    const acceleration_descriptor = mtl.MTL4PrimitiveAccelerationStructureDescriptor.allocInit().?;
    defer acceleration_descriptor.release();
    acceleration_descriptor.setGeometryDescriptors(geometry_descriptors);

    const acceleration_sizes = device.accelerationStructureSizesWithDescriptor(
        acceleration_descriptor.as(mtl.AccelerationStructureDescriptor),
    );
    const acceleration_structure = device.newAccelerationStructureWithSize(
        acceleration_sizes.accelerationStructureSize,
    ) orelse return error.OutOfHostMemory;
    defer acceleration_structure.release();

    const scratch_buffer = device.newBufferWithLength_options(
        acceleration_sizes.buildScratchBufferSize,
        mtl.ResourceStorageModePrivate,
    ) orelse return error.OutOfHostMemory;
    defer scratch_buffer.release();

    const result_buffer = device.newBufferWithLength_options(
        @sizeOf(u32),
        mtl.ResourceStorageModeShared,
    ) orelse return error.OutOfHostMemory;
    defer result_buffer.release();
    const hit: *u32 = @ptrCast(@alignCast(result_buffer.contents()));
    hit.* = 0;

    const argument_descriptor = mtl.MTL4ArgumentTableDescriptor.allocInit().?;
    defer argument_descriptor.release();
    argument_descriptor.setMaxBufferBindCount(2);
    argument_descriptor.setInitializeBindings(true);
    metal_error = null;
    const arguments = device.newArgumentTableWithDescriptor_error(
        argument_descriptor,
        &metal_error,
    ) orelse return reportMetalError(metal_error);
    defer arguments.release();
    arguments.setResource_atBufferIndex(acceleration_structure.gpuResourceID(), 0);
    arguments.setAddress_atIndex(result_buffer.gpuAddress(), 1);

    const residency_descriptor = mtl.ResidencySetDescriptor.allocInit().?;
    defer residency_descriptor.release();
    residency_descriptor.setInitialCapacity(5);
    metal_error = null;
    const residency = device.newResidencySetWithDescriptor_error(
        residency_descriptor,
        &metal_error,
    ) orelse return reportMetalError(metal_error);
    defer residency.release();
    residency.addAllocation(vertex_buffer.as(mtl.Allocation));
    residency.addAllocation(scratch_buffer.as(mtl.Allocation));
    residency.addAllocation(acceleration_structure.as(mtl.Allocation));
    residency.addAllocation(result_buffer.as(mtl.Allocation));
    residency.addAllocation(pipeline.as(mtl.Allocation));
    residency.commit();

    const command_buffer = device.newCommandBuffer() orelse return error.OutOfHostMemory;
    defer command_buffer.release();
    const queue = device.newMTL4CommandQueue() orelse return error.SkipZigTest;
    defer queue.release();
    const completion = device.newSharedEvent() orelse return error.OutOfHostMemory;
    defer completion.release();

    command_buffer.beginCommandBufferWithAllocator(allocator);
    command_buffer.useResidencySet(residency);
    const encoder = command_buffer.computeCommandEncoder() orelse return error.OutOfHostMemory;
    encoder.buildAccelerationStructure_descriptor_scratchBuffer(
        acceleration_structure,
        acceleration_descriptor.as(mtl.MTL4AccelerationStructureDescriptor),
        .init(
            scratch_buffer.gpuAddress(),
            acceleration_sizes.buildScratchBufferSize,
        ),
    );

    const command_encoder = encoder.as(mtl.MTL4CommandEncoder);
    command_encoder.barrierAfterEncoderStages_beforeEncoderStages_visibilityOptions(
        mtl.StageAccelerationStructure,
        mtl.StageDispatch,
        mtl.MTL4VisibilityOptionDevice,
    );
    encoder.setComputePipelineState(pipeline);
    encoder.setArgumentTable(arguments);
    encoder.dispatchThreads_threadsPerThreadgroup(
        .init(1, 1, 1),
        .init(1, 1, 1),
    );
    command_encoder.endEncoding();
    command_buffer.endCommandBuffer();

    var command_buffers = [_]*mtl.MTL4CommandBuffer{command_buffer};
    queue.commit_count(@ptrCast(&command_buffers), command_buffers.len);
    queue.signalEvent_value(completion.as(mtl.Event), 1);
    try std.testing.expect(completion.waitUntilSignaledValue_timeoutMS(1, 10_000));
    try std.testing.expectEqual(@as(u32, 1), hit.*);
}

fn reportMetalError(metal_error: ?*ns.Error) error{MetalFailure} {
    if (metal_error) |err| {
        std.debug.print("Metal error: {s}\n", .{err.localizedDescription().UTF8String()});
    }
    return error.MetalFailure;
}
