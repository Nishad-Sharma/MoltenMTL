const std = @import("std");
const slag = @import("slag");

const element_count = 256;
const byte_count = element_count * @sizeOf(f32);

const vector_add_source =
    \\#include <metal_stdlib>
    \\using namespace metal;
    \\
    \\kernel void vector_add(
    \\    device const float* lhs [[buffer(0)]],
    \\    device const float* rhs [[buffer(1)]],
    \\    device float* result [[buffer(2)]],
    \\    uint index [[thread_position_in_grid]])
    \\{
    \\    result[index] = lhs[index] + rhs[index];
    \\}
;

test "compute vector add" {
    var device = slag.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.deinit();
    if (!device.supportsMetal4()) return error.SkipZigTest;

    var compiler_descriptor = slag.CompilerDescriptor.init() orelse return error.OutOfHostMemory;
    defer compiler_descriptor.deinit();
    var compiler = try device.createCompiler(compiler_descriptor);
    defer compiler.deinit();

    var library_descriptor = slag.LibraryDescriptor.init() orelse return error.OutOfHostMemory;
    defer library_descriptor.deinit();
    library_descriptor.setName("vector-add");
    library_descriptor.setSource(vector_add_source);
    var library = try compiler.createLibrary(library_descriptor);
    defer library.deinit();

    var function_descriptor = slag.LibraryFunctionDescriptor.init() orelse return error.OutOfHostMemory;
    defer function_descriptor.deinit();
    function_descriptor.setLibrary(library);
    function_descriptor.setName("vector_add");

    var pipeline_descriptor = slag.ComputePipelineDescriptor.init() orelse return error.OutOfHostMemory;
    defer pipeline_descriptor.deinit();
    pipeline_descriptor.setComputeFunctionDescriptor(function_descriptor);
    var pipeline = try compiler.createComputePipelineState(pipeline_descriptor);
    defer pipeline.deinit();

    var lhs: [element_count]f32 = undefined;
    var rhs: [element_count]f32 = undefined;
    var expected: [element_count]f32 = undefined;
    for (0..element_count) |index| {
        lhs[index] = @floatFromInt(index);
        rhs[index] = @floatFromInt(index * 2);
        expected[index] = @floatFromInt(index * 3);
    }

    var lhs_buffer = device.createBufferWithBytes(&lhs, byte_count, slag.ResourceStorageModeShared) orelse return error.OutOfHostMemory;
    defer lhs_buffer.deinit();
    var rhs_buffer = device.createBufferWithBytes(&rhs, byte_count, slag.ResourceStorageModeShared) orelse return error.OutOfHostMemory;
    defer rhs_buffer.deinit();
    var result_buffer = device.createBuffer(byte_count, slag.ResourceStorageModeShared) orelse return error.OutOfHostMemory;
    defer result_buffer.deinit();

    var argument_descriptor = slag.ArgumentTableDescriptor.init() orelse return error.OutOfHostMemory;
    defer argument_descriptor.deinit();
    argument_descriptor.setMaxBufferBindCount(3);
    argument_descriptor.setInitializeBindings(true);
    var arguments = try device.createArgumentTable(argument_descriptor);
    defer arguments.deinit();
    arguments.setBuffer(lhs_buffer, 0, 0);
    arguments.setBuffer(rhs_buffer, 0, 1);
    arguments.setBuffer(result_buffer, 0, 2);

    var residency_descriptor = slag.ResidencySetDescriptor.init() orelse return error.OutOfHostMemory;
    defer residency_descriptor.deinit();
    residency_descriptor.setInitialCapacity(4);
    var residency = try device.createResidencySet(residency_descriptor);
    defer residency.deinit();
    residency.addBuffer(lhs_buffer);
    residency.addBuffer(rhs_buffer);
    residency.addBuffer(result_buffer);
    residency.addAllocation(pipeline.asAllocation());
    residency.commit();

    var allocator = device.createCommandAllocator() orelse return error.OutOfHostMemory;
    defer allocator.deinit();
    var command_buffer = device.createCommandBuffer() orelse return error.OutOfHostMemory;
    defer command_buffer.deinit();
    var queue = device.createCommandQueue() orelse return error.OutOfHostMemory;
    defer queue.deinit();
    var completion = device.createSharedEvent() orelse return error.OutOfHostMemory;
    defer completion.deinit();

    command_buffer.begin(allocator);
    command_buffer.useResidencySet(residency);
    var encoder = command_buffer.computeCommandEncoder() orelse return error.OutOfHostMemory;
    defer encoder.deinit();
    encoder.setComputePipelineState(pipeline);
    encoder.setArgumentTable(arguments);

    const threadgroup_width = @min(
        pipeline.threadExecutionWidth(),
        pipeline.maxTotalThreadsPerThreadgroup(),
    );
    try std.testing.expect(threadgroup_width > 0);
    encoder.dispatchThreads(
        slag.size(element_count, 1, 1),
        slag.size(threadgroup_width, 1, 1),
    );
    encoder.endEncoding();
    command_buffer.end();

    queue.commit(&.{command_buffer});
    queue.signalEvent(completion, 1);
    try std.testing.expect(completion.waitUntilSignaledValue(1, 10_000));

    const result: [*]const f32 = @ptrCast(@alignCast(result_buffer.contents()));
    try std.testing.expectEqualSlices(f32, &expected, result[0..element_count]);
}
