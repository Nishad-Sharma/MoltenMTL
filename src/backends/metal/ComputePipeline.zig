const c = @import("c.zig").c;
const object = @import("Object.zig");
const LibraryFunctionDescriptor = @import("LibraryFunctionDescriptor.zig").LibraryFunctionDescriptor;

pub const ComputePipelineDescriptor = extern struct {
    ptr: *c.MTL4ComputePipelineDescriptor,
    pub fn init() ?ComputePipelineDescriptor {
        return .{ .ptr = c.MTL4ComputePipelineDescriptorCreate() };
    }
    pub fn setComputeFunctionDescriptor(self: ComputePipelineDescriptor, descriptor: LibraryFunctionDescriptor) void {
        c.MTL4ComputePipelineDescriptorSetComputeFunctionDescriptor(self.ptr, descriptor.ptr);
    }
    pub fn setMaxTotalThreadsPerThreadgroup(self: ComputePipelineDescriptor, count: usize) void {
        c.MTL4ComputePipelineDescriptorSetMaxTotalThreadsPerThreadgroup(self.ptr, count);
    }
    pub fn deinit(self: *ComputePipelineDescriptor) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};

pub const ComputePipelineState = extern struct {
    ptr: *c.MTLComputePipelineState,
    pub fn init() ?ComputePipelineState {
        return .{ .ptr = c.MTLComputePipelineStateCreate() };
    }
    pub fn threadExecutionWidth(self: ComputePipelineState) usize {
        return c.MTLComputePipelineStateGetThreadExecutionWidth(self.ptr);
    }
    pub fn maxTotalThreadsPerThreadgroup(self: ComputePipelineState) usize {
        return c.MTLComputePipelineStateGetMaxTotalThreadsPerThreadgroup(self.ptr);
    }
    pub fn deinit(self: *ComputePipelineState) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
