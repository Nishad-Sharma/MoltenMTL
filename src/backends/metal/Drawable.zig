const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const Texture = @import("Texture.zig").Texture;

pub const Drawable = extern struct {
    ptr: *c.MTLDrawable,
    pub fn present(self: Drawable) void {
        c.MTLDrawablePresent(self.ptr);
    }
    pub fn texture(self: Drawable) ?Texture {
        return Texture{ .ptr = c.CAMetalDrawableGetTexture(@ptrCast(self.ptr)) };
    }
    pub fn deinit(self: *Drawable) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
