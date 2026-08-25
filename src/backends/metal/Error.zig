const c = @import("Raw.zig").c;
const object = @import("Object.zig");

pub const Error = extern struct {
    ptr: *c.MTLError,

    fn init(ptr: *c.MTLError) Error {
        return .{ .ptr = object.retain(ptr) };
    }

    pub fn code(self: Error) i64 {
        return c.MTLErrorGetCode(self.ptr);
    }
    pub fn localizedDescription(self: Error) [*:0]const u8 {
        return @ptrCast(c.MTLErrorGetLocalizedDescription(self.ptr));
    }
    pub fn deinit(self: *Error) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};

pub fn write(out: ?*?Error, raw: ?*c.MTLError) void {
    if (out) |destination| destination.* = object.wrap(Error, raw);
}
