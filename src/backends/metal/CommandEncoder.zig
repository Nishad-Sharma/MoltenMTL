const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const types = @import("Types.zig");

pub const VisibilityOptions = c.MTL4VisibilityOptions;
pub const VisibilityOptionNone: VisibilityOptions = c.MTL4VisibilityOptionNone;
pub const VisibilityOptionDevice: VisibilityOptions = c.MTL4VisibilityOptionDevice;
pub const VisibilityOptionResourceAlias: VisibilityOptions = c.MTL4VisibilityOptionResourceAlias;

pub const CommandEncoder = extern struct {
    ptr: *c.MTL4CommandEncoder,
    pub fn barrierAfterEncoderStages(self: CommandEncoder, after: types.Stages, before: types.Stages, visibility: VisibilityOptions) void {
        c.MTL4CommandEncoderBarrierAfterEncoderStages(self.ptr, after, before, visibility);
    }
    pub fn endEncoding(self: CommandEncoder) void {
        c.MTL4CommandEncoderEndEncoding(self.ptr);
    }
    pub fn retain(self: CommandEncoder) CommandEncoder {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *CommandEncoder) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
