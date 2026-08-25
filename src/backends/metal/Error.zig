const c = @import("Raw.zig").c;
const object = @import("Object.zig");

pub const Error = extern struct {
    ptr: *c.MTLError,

    pub fn code(self: Error) i64 {
        return c.MTLErrorGetCode(self.ptr);
    }
    pub fn localizedDescription(self: Error) [*:0]const u8 {
        return @ptrCast(c.MTLErrorGetLocalizedDescription(self.ptr));
    }
    pub fn retain(self: Error) Error {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *Error) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};

pub fn write(out: ?*?Error, raw: ?*c.MTLError) void {
    if (out) |destination| destination.* = object.wrap(Error, raw);
}
