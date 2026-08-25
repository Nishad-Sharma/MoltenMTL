const std = @import("std");
const slag = @import("slag");

test "all wrapper declarations compile" {
    std.testing.refAllDecls(slag);
    inline for (comptime std.meta.declarations(slag)) |decl| {
        if (comptime std.mem.eql(u8, decl.name, "c")) continue;
        const value = @field(slag, decl.name);
        if (@TypeOf(value) == type) switch (@typeInfo(value)) {
            .@"struct", .@"union", .@"enum", .@"opaque" => std.testing.refAllDecls(value),
            else => {},
        };
    }
}

test "wrapper objects remain pointer-sized" {
    inline for (&.{
        slag.Device,
        slag.Buffer,
        slag.Texture,
        slag.CommandQueue,
        slag.CommandBuffer,
        slag.ComputeCommandEncoder,
        slag.AccelerationStructure,
        slag.MetalLayer,
    }) |T| {
        try std.testing.expectEqual(@sizeOf(usize), @sizeOf(T));
        try std.testing.expectEqual(@alignOf(usize), @alignOf(T));
    }
}

test "POD helpers match metal-c" {
    const extent = slag.size(8, 4, 2);
    try std.testing.expectEqual(@as(usize, 8), extent.width);
    try std.testing.expectEqual(@as(usize, 4), extent.height);
    try std.testing.expectEqual(@as(usize, 2), extent.depth);

    const box = slag.region3D(1, 2, 3, 4, 5, 6);
    try std.testing.expectEqual(@as(usize, 1), box.origin.x);
    try std.testing.expectEqual(@as(usize, 6), box.size.depth);
}

test "metal-cpp style methods are present" {
    comptime {
        _ = slag.Device.newBuffer;
        _ = slag.Buffer.contents;
        _ = slag.TextureDescriptor.setUsage;
        _ = slag.CommandBuffer.computeCommandEncoder;
        _ = slag.ComputeCommandEncoder.dispatchThreads;
        _ = slag.PrimitiveAccelerationStructureDescriptor.asAccelerationStructureDescriptor;
        _ = slag.MetalLayer.nextDrawable;
    }
}

// Exporting this function forces Zig's lazy semantic analysis to compile the
// forwarding bodies without executing calls on fabricated Metal objects.
export fn compileWrapperMethodBodies() void {
    var pool: slag.AutoreleasePool = undefined;
    var device: slag.Device = undefined;
    var buffer: slag.Buffer = undefined;
    var texture_descriptor: slag.TextureDescriptor = undefined;
    var texture: slag.Texture = undefined;
    var allocator: slag.CommandAllocator = undefined;
    var command_buffer: slag.CommandBuffer = undefined;
    var queue: slag.CommandQueue = undefined;
    var event: slag.SharedEvent = undefined;
    var argument_descriptor: slag.ArgumentTableDescriptor = undefined;
    var argument_table: slag.ArgumentTable = undefined;
    var library_descriptor: slag.LibraryDescriptor = undefined;
    var library: slag.Library = undefined;
    var function_descriptor: slag.LibraryFunctionDescriptor = undefined;
    var pipeline_descriptor: slag.ComputePipelineDescriptor = undefined;
    var compiler_descriptor: slag.CompilerDescriptor = undefined;
    var compiler: slag.Compiler = undefined;
    var pipeline: slag.ComputePipelineState = undefined;
    var command_encoder: slag.CommandEncoder = undefined;
    var encoder: slag.ComputeCommandEncoder = undefined;
    var acceleration_structure: slag.AccelerationStructure = undefined;
    var triangle_descriptor: slag.AccelerationStructureTriangleGeometryDescriptor = undefined;
    var primitive_descriptor: slag.PrimitiveAccelerationStructureDescriptor = undefined;
    var instance_descriptor: slag.InstanceAccelerationStructureDescriptor = undefined;
    var residency_descriptor: slag.ResidencySetDescriptor = undefined;
    var residency_set: slag.ResidencySet = undefined;
    var drawable: slag.Drawable = undefined;
    var layer: slag.MetalLayer = undefined;
    var metal_error: ?slag.Error = null;

    _ = slag.AutoreleasePool.create();
    _ = slag.createSystemDefaultDevice();
    _ = device.name();
    _ = device.supportsMetal4();
    _ = device.newBuffer(16, slag.ResourceStorageModeShared);
    _ = device.newBufferWithBytes(@ptrCast(&device), @sizeOf(slag.Device), slag.ResourceStorageModeShared);
    _ = device.newTexture(texture_descriptor);
    _ = device.newCommandAllocator();
    _ = device.newCommandBuffer();
    _ = device.newCommandQueue();
    _ = device.newCompiler(compiler_descriptor, &metal_error);
    _ = device.newArgumentTable(argument_descriptor, &metal_error);
    _ = device.accelerationStructureSizes(primitive_descriptor.asAccelerationStructureDescriptor());
    _ = device.newAccelerationStructure(16);
    _ = device.newResidencySet(residency_descriptor, &metal_error);
    _ = device.newSharedEvent();

    _ = buffer.contents();
    _ = buffer.length();
    _ = buffer.gpuAddress();
    buffer.didModifyRange(slag.range(0, 16));
    buffer.setLabel("buffer");
    _ = buffer.allocatedSize();
    _ = buffer.asResource();
    _ = buffer.asAllocation();

    _ = slag.TextureDescriptor.create();
    _ = slag.TextureDescriptor.create2D(slag.PixelFormatRGBA8Unorm, 1, 1, false);
    texture_descriptor.setTextureType(slag.TextureType2D);
    texture_descriptor.setPixelFormat(slag.PixelFormatRGBA8Unorm);
    texture_descriptor.setWidth(1);
    texture_descriptor.setHeight(1);
    texture_descriptor.setDepth(1);
    texture_descriptor.setArrayLength(1);
    texture_descriptor.setMipmapLevelCount(1);
    texture_descriptor.setResourceOptions(slag.ResourceStorageModeShared);
    texture_descriptor.setUsage(slag.TextureUsageShaderRead);
    _ = texture.width();
    _ = texture.height();
    _ = texture.depth();
    _ = texture.pixelFormat();
    _ = texture.gpuResourceID();
    texture.replaceRegion(slag.region3D(0, 0, 0, 1, 1, 1), 0, 0, @ptrCast(&texture), 4, 4);
    texture.setLabel("texture");
    _ = texture.allocatedSize();
    _ = texture.asResource();
    _ = texture.asAllocation();

    allocator.reset();
    _ = allocator.allocatedSize();
    command_buffer.begin(allocator);
    _ = command_buffer.computeCommandEncoder();
    command_buffer.useResidencySet(residency_set);
    command_buffer.end();
    queue.commit(&.{command_buffer});
    queue.signalEvent(event, 1);
    queue.waitForEvent(event, 1);
    queue.waitForDrawable(drawable);
    queue.signalDrawable(drawable);
    _ = event.signaledValue();
    _ = event.waitUntilSignaledValue(1, 1);

    _ = slag.ArgumentTableDescriptor.create();
    argument_descriptor.setMaxBufferBindCount(1);
    argument_descriptor.setMaxTextureBindCount(1);
    argument_descriptor.setInitializeBindings(true);
    argument_table.setAddress(0, 0);
    argument_table.setBuffer(buffer, 0, 0);
    argument_table.setTexture(texture, 0);
    argument_table.setAccelerationStructure(acceleration_structure, 0);

    _ = slag.LibraryDescriptor.create();
    library_descriptor.setName("library");
    library_descriptor.setSource("");
    _ = slag.LibraryFunctionDescriptor.create();
    function_descriptor.setLibrary(library);
    function_descriptor.setName("main");
    _ = slag.ComputePipelineDescriptor.create();
    pipeline_descriptor.setComputeFunctionDescriptor(function_descriptor);
    pipeline_descriptor.setMaxTotalThreadsPerThreadgroup(64);
    _ = slag.CompilerDescriptor.create();
    _ = compiler.newLibrary(library_descriptor, &metal_error);
    _ = compiler.newComputePipelineState(pipeline_descriptor, &metal_error);
    _ = pipeline.threadExecutionWidth();
    _ = pipeline.maxTotalThreadsPerThreadgroup();

    const buffer_range = slag.BufferRange.make(buffer, 0, 16);
    command_encoder.barrierAfterEncoderStages(slag.StageDispatch, slag.StageBlit, slag.VisibilityOptionDevice);
    command_encoder.endEncoding();
    encoder.setComputePipelineState(pipeline);
    encoder.setArgumentTable(argument_table);
    encoder.barrierAfterEncoderStages(slag.StageDispatch, slag.StageBlit, slag.VisibilityOptionDevice);
    encoder.dispatchThreads(slag.size(1, 1, 1), slag.size(1, 1, 1));
    encoder.dispatchThreadgroups(slag.size(1, 1, 1), slag.size(1, 1, 1));
    encoder.copyBuffer(buffer, 0, buffer, 0, 16);
    encoder.copyBufferToTexture(buffer, 0, 256, 256, slag.size(1, 1, 1), texture, 0, 0, slag.origin(0, 0, 0));
    encoder.buildAccelerationStructure(acceleration_structure, primitive_descriptor.asAccelerationStructureDescriptor(), buffer_range);
    encoder.refitAccelerationStructure(acceleration_structure, primitive_descriptor.asAccelerationStructureDescriptor(), acceleration_structure, buffer_range);
    _ = encoder.asCommandEncoder();
    encoder.endEncoding();

    _ = acceleration_structure.size();
    _ = acceleration_structure.gpuResourceID();
    _ = acceleration_structure.asAllocation();
    _ = slag.AccelerationStructureTriangleGeometryDescriptor.create();
    triangle_descriptor.setVertexBuffer(buffer_range);
    triangle_descriptor.setVertexFormat(slag.AttributeFormatFloat3);
    triangle_descriptor.setVertexStride(12);
    triangle_descriptor.setIndexBuffer(buffer_range);
    triangle_descriptor.setIndexType(slag.IndexTypeUInt32);
    triangle_descriptor.setTriangleCount(1);
    triangle_descriptor.setOpaque(true);
    _ = slag.PrimitiveAccelerationStructureDescriptor.create();
    primitive_descriptor.setGeometryDescriptors(&.{triangle_descriptor});
    primitive_descriptor.setUsage(slag.AccelerationStructureUsagePreferFastIntersection);
    _ = primitive_descriptor.asAccelerationStructureDescriptor();
    _ = slag.InstanceAccelerationStructureDescriptor.create();
    instance_descriptor.setInstanceDescriptorBuffer(buffer_range);
    instance_descriptor.setInstanceDescriptorStride(@sizeOf(slag.AccelerationStructureInstanceDescriptor));
    instance_descriptor.setInstanceDescriptorType(slag.AccelerationStructureInstanceDescriptorTypeDefault);
    instance_descriptor.setInstanceCount(1);
    instance_descriptor.setUsage(slag.AccelerationStructureUsageRefit);
    _ = instance_descriptor.asAccelerationStructureDescriptor();

    _ = slag.ResidencySetDescriptor.create();
    residency_descriptor.setInitialCapacity(3);
    residency_set.addAllocation(buffer.asAllocation());
    residency_set.removeAllocation(buffer.asAllocation());
    residency_set.addBuffer(buffer);
    residency_set.addTexture(texture);
    residency_set.addAccelerationStructure(acceleration_structure);
    residency_set.commit();

    drawable.present();
    _ = drawable.texture();
    _ = slag.MetalLayer.create();
    _ = slag.MetalLayer.fromNative(@ptrCast(&layer));
    _ = layer.native();
    layer.setDevice(device);
    layer.setPixelFormat(slag.PixelFormatBGRA8Unorm);
    layer.setFramebufferOnly(false);
    layer.setDrawableSize(1, 1);
    _ = layer.nextDrawable();

    _ = pool.retain();
    _ = device.retain();
    _ = buffer.retain();
    _ = texture.retain();
    _ = allocator.retain();
    _ = command_buffer.retain();
    _ = queue.retain();
    _ = event.retain();
    _ = argument_table.retain();
    _ = compiler.retain();
    _ = pipeline.retain();
    _ = command_encoder.retain();
    _ = encoder.retain();
    _ = acceleration_structure.retain();
    _ = residency_set.retain();
    _ = drawable.retain();
    _ = layer.retain();

    pool.release();
    device.release();
    buffer.release();
    texture.release();
    allocator.release();
    command_buffer.release();
    queue.release();
    event.release();
    argument_table.release();
    argument_descriptor.release();
    library.release();
    library_descriptor.release();
    function_descriptor.release();
    pipeline_descriptor.release();
    compiler_descriptor.release();
    compiler.release();
    pipeline.release();
    command_encoder.release();
    encoder.release();
    acceleration_structure.release();
    triangle_descriptor.release();
    primitive_descriptor.release();
    instance_descriptor.release();
    residency_descriptor.release();
    residency_set.release();
    drawable.release();
    layer.release();
    texture_descriptor.release();
    if (metal_error) |*value| value.release();
}
