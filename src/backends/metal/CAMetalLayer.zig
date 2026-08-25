const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const Device = @import("Device.zig").Device;
const Drawable = @import("Drawable.zig").Drawable;
const PixelFormat = @import("PixelFormat.zig").PixelFormat;

pub const CAMetalLayer = extern struct {
    ptr: *c.CAMetalLayer,
    pub fn create() ?CAMetalLayer {
        return object.wrap(CAMetalLayer, c.CAMetalLayerCreate());
    }
    pub fn fromNative(native_layer: *anyopaque) ?CAMetalLayer {
        return object.wrap(CAMetalLayer, c.CAMetalLayerFromNative(native_layer));
    }
    pub fn native(self: CAMetalLayer) *anyopaque {
        return c.CAMetalLayerGetNative(self.ptr) orelse unreachable;
    }
    pub fn setDevice(self: CAMetalLayer, device: Device) void {
        c.CAMetalLayerSetDevice(self.ptr, device.ptr);
    }
    pub fn setPixelFormat(self: CAMetalLayer, format: PixelFormat) void {
        c.CAMetalLayerSetPixelFormat(self.ptr, format);
    }
    pub fn setFramebufferOnly(self: CAMetalLayer, framebuffer_only: bool) void {
        c.CAMetalLayerSetFramebufferOnly(self.ptr, framebuffer_only);
    }
    pub fn setDrawableSize(self: CAMetalLayer, width: f64, height: f64) void {
        c.CAMetalLayerSetDrawableSize(self.ptr, width, height);
    }
    pub fn nextDrawable(self: CAMetalLayer) ?Drawable {
        return object.wrap(Drawable, c.CAMetalLayerNextDrawable(self.ptr));
    }
    pub fn retain(self: CAMetalLayer) CAMetalLayer {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *CAMetalLayer) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
