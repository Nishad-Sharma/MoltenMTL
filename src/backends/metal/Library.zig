const c = @import("c.zig").c;
const object = @import("Object.zig");

pub const Library = extern struct {
    ptr: *c.MTLLibrary,
    pub fn deinit(self: *Library) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
