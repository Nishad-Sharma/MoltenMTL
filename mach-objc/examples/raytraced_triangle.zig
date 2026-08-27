const std = @import("std");
const mach = @import("mach-objc");

const appkit = mach.app_kit;
const ca = mach.quartz_core;
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
    \\    texture2d<float, access::write> output [[texture(0)]],
    \\    uint2 tid [[thread_position_in_grid]])
    \\{
    \\    const uint width = output.get_width();
    \\    const uint height = output.get_height();
    \\    if (tid.x >= width || tid.y >= height) return;
    \\
    \\    float2 uv = (float2(tid) + 0.5f) / float2(width, height);
    \\    uv = uv * 2.0f - 1.0f;
    \\    uv.x *= float(width) / float(height);
    \\
    \\    ray query;
    \\    query.origin = float3(0.0f, 0.0f, 1.5f);
    \\    query.direction = normalize(float3(uv.x, -uv.y, -1.5f));
    \\    query.min_distance = 0.001f;
    \\    query.max_distance = 10.0f;
    \\
    \\    intersector<triangle_data> trace;
    \\    const auto intersection = trace.intersect(query, acceleration_structure);
    \\    float3 color = float3(0.025f, 0.035f, 0.06f);
    \\    if (intersection.type == intersection_type::triangle) {
    \\        const float2 bary = intersection.triangle_barycentric_coord;
    \\        color = float3(1.0f - bary.x - bary.y, bary.x, bary.y);
    \\    }
    \\    output.write(float4(color, 1.0f), tid);
    \\}
;

pub fn main(init: std.process.Init) !void {
    const frame_limit = try parseFrameLimit(init);
    try run(frame_limit);
}

fn parseFrameLimit(init: std.process.Init) !?usize {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();

    var frame_limit: ?usize = null;
    while (args.next()) |arg| {
        if (!std.mem.eql(u8, arg, "--frames")) return error.InvalidArgument;
        const value = args.next() orelse return error.InvalidArgument;
        frame_limit = try std.fmt.parseInt(usize, value, 10);
    }
    return frame_limit;
}

fn run(frame_limit: ?usize) !void {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const device = mtl.createSystemDefaultDevice() orelse return error.NoMetalDevice;
    defer device.release();
    if (!objc.respondsTo(device, "newCommandAllocator")) return error.Metal4Unavailable;
    if (!device.supportsRaytracing()) return error.RayTracingUnavailable;

    const app = appkit.Application.sharedApplication();
    if (!app.setActivationPolicy(appkit.ApplicationActivationPolicyRegular)) {
        return error.ApplicationActivationFailed;
    }
    app.finishLaunching();

    const content_rect = appkit.Rect{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{ .width = 960, .height = 720 },
    };
    const style = appkit.WindowStyleMaskTitled |
        appkit.WindowStyleMaskClosable |
        appkit.WindowStyleMaskMiniaturizable |
        appkit.WindowStyleMaskResizable;
    const window = appkit.Window.alloc().?.initWithContentRect_styleMask_backing_defer_screen(
        content_rect,
        style,
        appkit.BackingStoreBuffered,
        false,
        null,
    );
    defer window.release();
    window.setReleasedWhenClosed(false);
    window.setTitle(ns.String.stringWithUTF8String("Mach-ObjC Metal 4 Ray-Traced Triangle"));
    window.center();

    const view = window.contentView() orelse return error.MissingContentView;
    const layer = ca.MetalLayer.allocInit().?;
    defer layer.release();
    layer.setDevice(device);
    layer.setPixelFormat(mtl.PixelFormatBGRA8Unorm);
    layer.setFramebufferOnly(false);
    layer.setMaximumDrawableCount(3);
    view.setWantsLayer(true);
    view.setLayer(layer.as(ca.Layer));
    updateDrawableSize(window, view, layer);

    window.makeKeyAndOrderFront(null);
    app.activateIgnoringOtherApps(true);

    const allocator = device.newCommandAllocator() orelse return error.Metal4Unavailable;
    defer allocator.release();
    const queue = device.newMTL4CommandQueue() orelse return error.Metal4Unavailable;
    defer queue.release();
    const completion = device.newSharedEvent() orelse return error.OutOfHostMemory;
    defer completion.release();

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
    library_descriptor.setName(ns.String.stringWithUTF8String("raytraced-triangle"));
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

    const GeometryArray = ns.Array(?*mtl.MTL4AccelerationStructureGeometryDescriptor);
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

    const static_residency_descriptor = mtl.ResidencySetDescriptor.allocInit().?;
    defer static_residency_descriptor.release();
    static_residency_descriptor.setInitialCapacity(4);
    metal_error = null;
    const static_residency = device.newResidencySetWithDescriptor_error(
        static_residency_descriptor,
        &metal_error,
    ) orelse return reportMetalError(metal_error);
    defer static_residency.release();
    static_residency.addAllocation(vertex_buffer.as(mtl.Allocation));
    static_residency.addAllocation(scratch_buffer.as(mtl.Allocation));
    static_residency.addAllocation(acceleration_structure.as(mtl.Allocation));
    static_residency.addAllocation(pipeline.as(mtl.Allocation));
    static_residency.commit();

    var completion_value: u64 = 1;
    try buildAccelerationStructure(
        device,
        allocator,
        queue,
        completion,
        completion_value,
        static_residency,
        acceleration_structure,
        acceleration_descriptor,
        scratch_buffer,
        acceleration_sizes.buildScratchBufferSize,
    );
    allocator.reset();

    std.debug.print(
        "Device: {s}\nRendering with native AppKit + CAMetalLayer + Metal 4 ray queries. Close the window to quit.\n",
        .{device.name().UTF8String()},
    );

    var frame_count: usize = 0;
    while (window.isVisible()) {
        var frame_pool = objc.AutoreleasePool.init();
        defer frame_pool.deinit();

        pumpEvents(app);
        if (!window.isVisible()) break;

        updateDrawableSize(window, view, layer);
        const drawable = layer.nextDrawable() orelse continue;
        const texture = drawable.texture();

        const argument_descriptor = mtl.MTL4ArgumentTableDescriptor.allocInit().?;
        defer argument_descriptor.release();
        argument_descriptor.setMaxBufferBindCount(1);
        argument_descriptor.setMaxTextureBindCount(1);
        argument_descriptor.setInitializeBindings(true);
        metal_error = null;
        const arguments = device.newArgumentTableWithDescriptor_error(
            argument_descriptor,
            &metal_error,
        ) orelse return reportMetalError(metal_error);
        defer arguments.release();
        arguments.setResource_atBufferIndex(acceleration_structure.gpuResourceID(), 0);
        arguments.setTexture_atIndex(texture.gpuResourceID(), 0);

        const drawable_residency_descriptor = mtl.ResidencySetDescriptor.allocInit().?;
        defer drawable_residency_descriptor.release();
        drawable_residency_descriptor.setInitialCapacity(1);
        metal_error = null;
        const drawable_residency = device.newResidencySetWithDescriptor_error(
            drawable_residency_descriptor,
            &metal_error,
        ) orelse return reportMetalError(metal_error);
        defer drawable_residency.release();
        drawable_residency.addAllocation(texture.as(mtl.Allocation));
        drawable_residency.commit();

        const command_buffer = device.newCommandBuffer() orelse return error.OutOfHostMemory;
        defer command_buffer.release();
        command_buffer.beginCommandBufferWithAllocator(allocator);
        command_buffer.useResidencySet(static_residency);
        command_buffer.useResidencySet(drawable_residency);
        const encoder = command_buffer.computeCommandEncoder() orelse return error.OutOfHostMemory;
        encoder.setComputePipelineState(pipeline);
        encoder.setArgumentTable(arguments);
        encoder.dispatchThreads_threadsPerThreadgroup(
            .init(texture.width(), texture.height(), 1),
            .init(8, 8, 1),
        );
        encoder.as(mtl.MTL4CommandEncoder).endEncoding();
        command_buffer.endCommandBuffer();

        const mtl_drawable: *mtl.Drawable = @ptrCast(drawable);
        queue.waitForDrawable(mtl_drawable);
        var command_buffers = [_]*mtl.MTL4CommandBuffer{command_buffer};
        queue.commit_count(@ptrCast(&command_buffers), command_buffers.len);
        queue.signalDrawable(mtl_drawable);
        completion_value += 1;
        queue.signalEvent_value(completion.as(mtl.Event), completion_value);
        mtl_drawable.present();

        if (!completion.waitUntilSignaledValue_timeoutMS(completion_value, 10_000)) {
            return error.GpuTimeout;
        }
        allocator.reset();
        frame_count += 1;
        if (frame_limit) |limit| {
            if (frame_count >= limit) break;
        }
    }
}

fn buildAccelerationStructure(
    device: *mtl.Device,
    allocator: *mtl.MTL4CommandAllocator,
    queue: *mtl.MTL4CommandQueue,
    completion: *mtl.SharedEvent,
    completion_value: u64,
    residency: *mtl.ResidencySet,
    acceleration_structure: *mtl.AccelerationStructure,
    descriptor: *mtl.MTL4PrimitiveAccelerationStructureDescriptor,
    scratch_buffer: *mtl.Buffer,
    scratch_size: usize,
) !void {
    const command_buffer = device.newCommandBuffer() orelse return error.OutOfHostMemory;
    defer command_buffer.release();
    command_buffer.beginCommandBufferWithAllocator(allocator);
    command_buffer.useResidencySet(residency);
    const encoder = command_buffer.computeCommandEncoder() orelse return error.OutOfHostMemory;
    encoder.buildAccelerationStructure_descriptor_scratchBuffer(
        acceleration_structure,
        descriptor.as(mtl.MTL4AccelerationStructureDescriptor),
        .init(scratch_buffer.gpuAddress(), scratch_size),
    );
    encoder.as(mtl.MTL4CommandEncoder).endEncoding();
    command_buffer.endCommandBuffer();

    var command_buffers = [_]*mtl.MTL4CommandBuffer{command_buffer};
    queue.commit_count(@ptrCast(&command_buffers), command_buffers.len);
    queue.signalEvent_value(completion.as(mtl.Event), completion_value);
    if (!completion.waitUntilSignaledValue_timeoutMS(completion_value, 10_000)) {
        return error.GpuTimeout;
    }
}

fn pumpEvents(app: *appkit.Application) void {
    while (app.nextEventMatchingMask_untilDate_inMode_dequeue(
        appkit.EventMaskAny,
        appkit.Date.distantPast(),
        appkit.NSDefaultRunLoopMode,
        true,
    )) |event| {
        app.sendEvent(event);
    }
}

fn updateDrawableSize(
    window: *appkit.Window,
    view: *appkit.View,
    layer: *ca.MetalLayer,
) void {
    const bounds = view.bounds();
    const scale = window.backingScaleFactor();
    layer.as(ca.Layer).setFrame(bounds);
    layer.as(ca.Layer).setContentsScale(scale);
    layer.setDrawableSize(.{
        .width = bounds.size.width * scale,
        .height = bounds.size.height * scale,
    });
}

fn reportMetalError(metal_error: ?*ns.Error) error{MetalFailure} {
    if (metal_error) |err| {
        std.debug.print("Metal error: {s}\n", .{err.localizedDescription().UTF8String()});
    }
    return error.MetalFailure;
}
