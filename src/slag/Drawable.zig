const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const Texture = @import("Texture.zig").Texture;

pub const Drawable = extern struct {
    ptr: *c.MTLDrawable,
    pub fn present(self: Drawable) void {
        c.MTLDrawablePresent(self.ptr);
    }
    pub fn texture(self: Drawable) ?Texture {
        return object.wrap(Texture, c.CAMetalDrawableGetTexture(@ptrCast(self.ptr)));
    }
    pub fn retain(self: Drawable) Drawable {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *Drawable) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
