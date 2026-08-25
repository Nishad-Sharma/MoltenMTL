const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const LibraryFunctionDescriptor = @import("LibraryFunctionDescriptor.zig").LibraryFunctionDescriptor;

pub const ComputePipelineDescriptor = extern struct {
    ptr: *c.MTL4ComputePipelineDescriptor,
    pub fn create() ?ComputePipelineDescriptor {
        return object.wrap(ComputePipelineDescriptor, c.MTL4ComputePipelineDescriptorCreate());
    }
    pub fn setComputeFunctionDescriptor(self: ComputePipelineDescriptor, descriptor: LibraryFunctionDescriptor) void {
        c.MTL4ComputePipelineDescriptorSetComputeFunctionDescriptor(self.ptr, descriptor.ptr);
    }
    pub fn setMaxTotalThreadsPerThreadgroup(self: ComputePipelineDescriptor, count: usize) void {
        c.MTL4ComputePipelineDescriptorSetMaxTotalThreadsPerThreadgroup(self.ptr, count);
    }
    pub fn retain(self: ComputePipelineDescriptor) ComputePipelineDescriptor {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *ComputePipelineDescriptor) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};

pub const ComputePipelineState = extern struct {
    ptr: *c.MTLComputePipelineState,
    pub fn threadExecutionWidth(self: ComputePipelineState) usize {
        return c.MTLComputePipelineStateGetThreadExecutionWidth(self.ptr);
    }
    pub fn maxTotalThreadsPerThreadgroup(self: ComputePipelineState) usize {
        return c.MTLComputePipelineStateGetMaxTotalThreadsPerThreadgroup(self.ptr);
    }
    pub fn retain(self: ComputePipelineState) ComputePipelineState {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *ComputePipelineState) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
