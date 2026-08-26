const c = @import("c.zig").c;

pub fn release(ptr: anytype) void {
    c.MTLRelease(@ptrCast(ptr));
}
