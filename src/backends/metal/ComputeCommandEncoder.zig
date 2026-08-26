const c = @import("c.zig").c;
const object = @import("Object.zig");
const types = @import("types.zig");
const Buffer = @import("Buffer.zig").Buffer;
const Texture = @import("texture.zig").Texture;
const arguments = @import("argument_table.zig");
const pipeline = @import("compute_pipeline.zig");
const AccelerationStructure = @import("acceleration_structure.zig").AccelerationStructure;
const AccelerationStructureDescriptor = @import("acceleration_structure.zig").AccelerationStructureDescriptor;
const command = @import("CommandEncoder.zig");

pub const ComputeCommandEncoder = extern struct {
    ptr: *c.MTL4ComputeCommandEncoder,
    pub fn setComputePipelineState(self: ComputeCommandEncoder, state: pipeline.ComputePipelineState) void {
        c.MTL4ComputeCommandEncoderSetComputePipelineState(self.ptr, state.ptr);
    }
    pub fn setArgumentTable(self: ComputeCommandEncoder, table: arguments.ArgumentTable) void {
        c.MTL4ComputeCommandEncoderSetArgumentTable(self.ptr, @ptrCast(table.ptr));
    }
    pub fn barrierAfterEncoderStages(self: ComputeCommandEncoder, after: types.Stages, before: types.Stages, visibility: command.VisibilityOptions) void {
        c.MTL4ComputeCommandEncoderBarrierAfterEncoderStages(self.ptr, after, before, visibility);
    }
    pub fn endEncoding(self: ComputeCommandEncoder) void {
        c.MTL4ComputeCommandEncoderEndEncoding(self.ptr);
    }
    pub fn dispatchThreads(self: ComputeCommandEncoder, threads_per_grid: types.Size, threads_per_threadgroup: types.Size) void {
        c.MTL4ComputeCommandEncoderDispatchThreads(self.ptr, threads_per_grid, threads_per_threadgroup);
    }
    pub fn dispatchThreadgroups(self: ComputeCommandEncoder, threadgroups_per_grid: types.Size, threads_per_threadgroup: types.Size) void {
        c.MTL4ComputeCommandEncoderDispatchThreadgroups(self.ptr, threadgroups_per_grid, threads_per_threadgroup);
    }
    pub fn copyBuffer(self: ComputeCommandEncoder, source: Buffer, source_offset: usize, destination: Buffer, destination_offset: usize, byte_count: usize) void {
        c.MTL4ComputeCommandEncoderCopyBuffer(self.ptr, source.ptr, source_offset, destination.ptr, destination_offset, byte_count);
    }
    pub fn copyBufferToTexture(self: ComputeCommandEncoder, source: Buffer, source_offset: usize, source_bytes_per_row: usize, source_bytes_per_image: usize, source_size: types.Size, destination: Texture, destination_slice: usize, destination_level: usize, destination_origin: types.Origin) void {
        c.MTL4ComputeCommandEncoderCopyBufferToTexture(self.ptr, source.ptr, source_offset, source_bytes_per_row, source_bytes_per_image, source_size, destination.ptr, destination_slice, destination_level, destination_origin);
    }
    pub fn buildAccelerationStructure(self: ComputeCommandEncoder, structure: AccelerationStructure, descriptor: AccelerationStructureDescriptor, scratch_buffer: types.BufferRange) void {
        c.MTL4ComputeCommandEncoderBuildAccelerationStructure(self.ptr, structure.ptr, descriptor.ptr, scratch_buffer.raw());
    }
    pub fn refitAccelerationStructure(self: ComputeCommandEncoder, source: AccelerationStructure, descriptor: AccelerationStructureDescriptor, destination: AccelerationStructure, scratch_buffer: types.BufferRange) void {
        c.MTL4ComputeCommandEncoderRefitAccelerationStructure(self.ptr, source.ptr, descriptor.ptr, destination.ptr, scratch_buffer.raw());
    }
    pub fn asCommandEncoder(self: ComputeCommandEncoder) command.CommandEncoder {
        return .{ .ptr = @ptrCast(self.ptr) };
    }
    pub fn deinit(self: *ComputeCommandEncoder) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
