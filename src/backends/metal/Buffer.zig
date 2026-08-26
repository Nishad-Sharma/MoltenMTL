const c = @import("c.zig").c;
const object = @import("Object.zig");
const resource = @import("resource.zig");
const types = @import("types.zig");

pub const Buffer = extern struct {
    ptr: *c.MTLBuffer,

    pub fn contents(self: Buffer) [*]u8 {
        return @ptrCast(c.MTLBufferGetContents(self.ptr));
    }
    pub fn length(self: Buffer) usize {
        return c.MTLBufferGetLength(self.ptr);
    }
    pub fn gpuAddress(self: Buffer) types.GPUAddress {
        return c.MTLBufferGetGPUAddress(self.ptr);
    }
    pub fn didModifyRange(self: Buffer, modified_range: types.Range) void {
        c.MTLBufferDidModifyRange(self.ptr, types.rawRange(modified_range));
    }
    pub fn setLabel(self: Buffer, label: [*:0]const u8) void {
        self.asResource().setLabel(label);
    }
    pub fn allocatedSize(self: Buffer) usize {
        return self.asResource().allocatedSize();
    }
    pub fn asResource(self: Buffer) resource.Resource {
        return .{ .ptr = @ptrCast(self.ptr) };
    }
    pub fn asAllocation(self: Buffer) resource.Allocation {
        return .{ .ptr = @ptrCast(self.ptr) };
    }
    pub fn deinit(self: *Buffer) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
