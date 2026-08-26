const c = @import("c.zig").c;
const object = @import("Object.zig");
const types = @import("types.zig");

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
    pub fn deinit(self: *CommandEncoder) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
