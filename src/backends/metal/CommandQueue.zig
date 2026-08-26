const c = @import("c.zig").c;
const object = @import("Object.zig");
const CommandBuffer = @import("CommandBuffer.zig").CommandBuffer;
const Drawable = @import("Drawable.zig").Drawable;
const SharedEvent = @import("Event.zig").SharedEvent;

pub const CommandQueue = extern struct {
    ptr: *c.MTL4CommandQueue,
    pub fn commit(self: CommandQueue, command_buffers: []const CommandBuffer) void {
        c.MTL4CommandQueueCommit(self.ptr, @ptrCast(command_buffers.ptr), command_buffers.len);
    }
    pub fn signalEvent(self: CommandQueue, event: SharedEvent, value: u64) void {
        c.MTL4CommandQueueSignalEvent(self.ptr, event.ptr, value);
    }
    pub fn waitForEvent(self: CommandQueue, event: SharedEvent, value: u64) void {
        c.MTL4CommandQueueWaitForEvent(self.ptr, event.ptr, value);
    }
    pub fn waitForDrawable(self: CommandQueue, drawable: Drawable) void {
        c.MTL4CommandQueueWaitForDrawable(self.ptr, drawable.ptr);
    }
    pub fn signalDrawable(self: CommandQueue, drawable: Drawable) void {
        c.MTL4CommandQueueSignalDrawable(self.ptr, drawable.ptr);
    }
    pub fn deinit(self: *CommandQueue) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
