const c = @import("c.zig").c;
const object = @import("Object.zig");
const CommandAllocator = @import("CommandAllocator.zig").CommandAllocator;
const ComputeCommandEncoder = @import("ComputeCommandEncoder.zig").ComputeCommandEncoder;
const ResidencySet = @import("residency_set.zig").ResidencySet;

pub const CommandBuffer = extern struct {
    ptr: *c.MTL4CommandBuffer,
    pub fn begin(self: CommandBuffer, allocator: CommandAllocator) void {
        c.MTL4CommandBufferBegin(self.ptr, allocator.ptr);
    }
    pub fn computeCommandEncoder(self: CommandBuffer) ?ComputeCommandEncoder {
        return ComputeCommandEncoder{ .ptr = c.MTL4CommandBufferGetComputeCommandEncoder(self.ptr) };
    }
    pub fn useResidencySet(self: CommandBuffer, residency_set: ResidencySet) void {
        c.MTL4CommandBufferUseResidencySet(self.ptr, residency_set.ptr);
    }
    pub fn end(self: CommandBuffer) void {
        c.MTL4CommandBufferEnd(self.ptr);
    }
    pub fn deinit(self: *CommandBuffer) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
