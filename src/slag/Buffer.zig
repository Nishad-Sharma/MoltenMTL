const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const resource = @import("Resource.zig");
const types = @import("Types.zig");

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
        c.MTLBufferDidModifyRange(self.ptr, modified_range);
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
    pub fn retain(self: Buffer) Buffer {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *Buffer) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
