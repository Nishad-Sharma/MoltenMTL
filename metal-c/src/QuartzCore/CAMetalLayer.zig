const c = @import("../slag/Raw.zig").c;
const object = @import("../slag/Object.zig");
const Device = @import("../slag/Device.zig").Device;
const Drawable = @import("../slag/Drawable.zig").Drawable;
const PixelFormat = @import("../slag/PixelFormat.zig").PixelFormat;

pub const MetalLayer = extern struct {
    ptr: *c.CAMetalLayer,
    pub fn create() ?MetalLayer {
        return object.wrap(MetalLayer, c.CAMetalLayerCreate());
    }
    pub fn fromNative(native_layer: *anyopaque) ?MetalLayer {
        return object.wrap(MetalLayer, c.CAMetalLayerFromNative(native_layer));
    }
    pub fn native(self: MetalLayer) *anyopaque {
        return c.CAMetalLayerGetNative(self.ptr) orelse unreachable;
    }
    pub fn setDevice(self: MetalLayer, device: Device) void {
        c.CAMetalLayerSetDevice(self.ptr, device.ptr);
    }
    pub fn setPixelFormat(self: MetalLayer, format: PixelFormat) void {
        c.CAMetalLayerSetPixelFormat(self.ptr, format);
    }
    pub fn setFramebufferOnly(self: MetalLayer, framebuffer_only: bool) void {
        c.CAMetalLayerSetFramebufferOnly(self.ptr, framebuffer_only);
    }
    pub fn setDrawableSize(self: MetalLayer, width: f64, height: f64) void {
        c.CAMetalLayerSetDrawableSize(self.ptr, width, height);
    }
    pub fn nextDrawable(self: MetalLayer) ?Drawable {
        return object.wrap(Drawable, c.CAMetalLayerNextDrawable(self.ptr));
    }
    pub fn retain(self: MetalLayer) MetalLayer {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *MetalLayer) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
