const c = @import("c.zig").c;
const object = @import("Object.zig");

pub const CommandAllocator = extern struct {
    ptr: *c.MTL4CommandAllocator,
    pub fn reset(self: CommandAllocator) void {
        c.MTL4CommandAllocatorReset(self.ptr);
    }
    pub fn allocatedSize(self: CommandAllocator) u64 {
        return c.MTL4CommandAllocatorGetAllocatedSize(self.ptr);
    }
    pub fn deinit(self: *CommandAllocator) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
