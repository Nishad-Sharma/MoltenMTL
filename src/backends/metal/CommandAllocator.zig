const c = @import("Raw.zig").c;
const object = @import("Object.zig");

pub const CommandAllocator = extern struct {
    ptr: *c.MTL4CommandAllocator,
    pub fn reset(self: CommandAllocator) void {
        c.MTL4CommandAllocatorReset(self.ptr);
    }
    pub fn allocatedSize(self: CommandAllocator) u64 {
        return c.MTL4CommandAllocatorGetAllocatedSize(self.ptr);
    }
    pub fn retain(self: CommandAllocator) CommandAllocator {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *CommandAllocator) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
