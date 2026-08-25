const c = @import("Raw.zig").c;
const object = @import("Object.zig");

pub const Library = extern struct {
    ptr: *c.MTLLibrary,
    pub fn retain(self: Library) Library {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *Library) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
