const c = @import("c.zig").c;
const object = @import("Object.zig");
const Device = @import("Device.zig").Device;
const Drawable = @import("Drawable.zig").Drawable;
const PixelFormat = @import("PixelFormat.zig").PixelFormat;

pub const SwapChain = extern struct {
    ptr: *c.CAMetalLayer,
    pub fn fromLayer(layer: *c.CAMetalLayer) SwapChain {
        return .{ .ptr = object.retain(layer) };
    }
    pub fn setDevice(self: SwapChain, device: Device) void {
        c.CAMetalLayerSetDevice(self.ptr, device.ptr);
    }
    pub fn setPixelFormat(self: SwapChain, format: PixelFormat) void {
        c.CAMetalLayerSetPixelFormat(self.ptr, format);
    }
    pub fn setFramebufferOnly(self: SwapChain, framebuffer_only: bool) void {
        c.CAMetalLayerSetFramebufferOnly(self.ptr, framebuffer_only);
    }
    pub fn setDrawableSize(self: SwapChain, width: f64, height: f64) void {
        c.CAMetalLayerSetDrawableSize(self.ptr, width, height);
    }
    pub fn nextDrawable(self: SwapChain) ?Drawable {
        return object.wrap(Drawable, c.CAMetalLayerNextDrawable(self.ptr));
    }
    pub fn deinit(self: *SwapChain) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
