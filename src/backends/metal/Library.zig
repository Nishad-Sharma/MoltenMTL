const c = @import("Raw.zig").c;
const object = @import("Object.zig");

pub const Library = extern struct {
    ptr: *c.MTLLibrary,
    pub fn deinit(self: *Library) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
