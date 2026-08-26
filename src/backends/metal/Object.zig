const c = @import("Raw.zig").c;

pub fn deinit(ptr: anytype) void {
    c.MTLRelease(@ptrCast(ptr));
}
