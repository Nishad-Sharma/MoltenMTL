const c = @import("Raw.zig").c;

pub fn retain(ptr: anytype) @TypeOf(ptr) {
    return @ptrCast(c.MTLRetain(@ptrCast(ptr)) orelse unreachable);
}

pub fn release(ptr: anytype) void {
    c.MTLRelease(@ptrCast(ptr));
}

pub fn wrap(comptime T: type, ptr: anytype) ?T {
    return if (ptr) |value| .{ .ptr = value } else null;
}

pub const AutoreleasePool = extern struct {
    ptr: *c.MTLAutoreleasePool,

    pub fn create() ?AutoreleasePool {
        return wrap(AutoreleasePool, c.MTLAutoreleasePoolCreate());
    }
    pub fn retain(self: AutoreleasePool) AutoreleasePool {
        return .{ .ptr = @import("Object.zig").retain(self.ptr) };
    }
    pub fn release(self: *AutoreleasePool) void {
        @import("Object.zig").release(self.ptr);
        self.* = undefined;
    }
};
