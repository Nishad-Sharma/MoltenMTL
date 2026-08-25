const c = @import("Raw.zig").c;
const object = @import("Object.zig");

pub const SharedEvent = extern struct {
    ptr: *c.MTLSharedEvent,
    pub fn signaledValue(self: SharedEvent) u64 {
        return c.MTLSharedEventGetSignaledValue(self.ptr);
    }
    pub fn waitUntilSignaledValue(self: SharedEvent, value: u64, timeout_ms: u64) bool {
        return c.MTLSharedEventWaitUntilSignaledValue(self.ptr, value, timeout_ms);
    }
    pub fn deinit(self: *SharedEvent) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
