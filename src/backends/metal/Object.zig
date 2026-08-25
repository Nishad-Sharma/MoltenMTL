const c = @import("Raw.zig").c;

pub fn retain(ptr: anytype) @TypeOf(ptr) {
    return @ptrCast(c.MTLRetain(@ptrCast(ptr)) orelse unreachable);
}

pub fn deinit(ptr: anytype) void {
    c.MTLRelease(@ptrCast(ptr));
}

pub fn wrap(comptime T: type, ptr: anytype) ?T {
    return if (ptr) |value| .{ .ptr = value } else null;
}
