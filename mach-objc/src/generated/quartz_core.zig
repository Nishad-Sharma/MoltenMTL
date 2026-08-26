const cg = @import("../core_graphics.zig");
const cf = @import("../core_foundation.zig");
const mtl = @import("metal.zig");
const ns = @import("../foundation.zig");
const objc = @import("../objc.zig");

pub const UInteger = ns.UInteger;
pub const TimeInterval = ns.TimeInterval;
pub const String = ns.String;

pub const Layer = opaque {
    pub const InternalInfo = objc.ExternClass("CALayer", @This(), ns.ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn addSublayer(self_: *@This(), layer_: *Layer) void {
        return objc.msgSend(self_, "addSublayer:", void, .{layer_});
    }
    pub fn setFrame(self_: *@This(), frame_: cg.Rect) void {
        return objc.msgSend(self_, "setFrame:", void, .{frame_});
    }
    pub fn contentsScale(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "contentsScale", cg.Float, .{});
    }
    pub fn setContentsScale(self_: *@This(), contentsScale_: cg.Float) void {
        return objc.msgSend(self_, "setContentsScale:", void, .{contentsScale_});
    }
    pub fn setOpaque(self_: *@This(), opaque_: bool) void {
        return objc.msgSend(self_, "setOpaque:", void, .{opaque_});
    }
    pub fn setOpacity(self_: *@This(), opacity_: f32) void {
        return objc.msgSend(self_, "setOpacity:", void, .{opacity_});
    }
};

pub const MetalLayer = opaque {
    pub const InternalInfo = objc.ExternClass("CAMetalLayer", @This(), Layer, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn nextDrawable(self_: *@This()) ?*MetalDrawable {
        return objc.msgSend(self_, "nextDrawable", ?*MetalDrawable, .{});
    }
    pub fn device(self_: *@This()) ?*mtl.Device {
        return objc.msgSend(self_, "device", ?*mtl.Device, .{});
    }
    pub fn setDevice(self_: *@This(), device_: ?*mtl.Device) void {
        return objc.msgSend(self_, "setDevice:", void, .{device_});
    }
    pub fn preferredDevice(self_: *@This()) *mtl.Device {
        return objc.msgSend(self_, "preferredDevice", *mtl.Device, .{});
    }
    pub fn pixelFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "pixelFormat", mtl.PixelFormat, .{});
    }
    pub fn setPixelFormat(self_: *@This(), pixelFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setPixelFormat:", void, .{pixelFormat_});
    }
    pub fn framebufferOnly(self_: *@This()) bool {
        return objc.msgSend(self_, "framebufferOnly", bool, .{});
    }
    pub fn setFramebufferOnly(self_: *@This(), framebufferOnly_: bool) void {
        return objc.msgSend(self_, "setFramebufferOnly:", void, .{framebufferOnly_});
    }
    pub fn drawableSize(self_: *@This()) cg.Size {
        return objc.msgSend(self_, "drawableSize", cg.Size, .{});
    }
    pub fn setDrawableSize(self_: *@This(), drawableSize_: cg.Size) void {
        return objc.msgSend(self_, "setDrawableSize:", void, .{drawableSize_});
    }
    pub fn maximumDrawableCount(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "maximumDrawableCount", ns.UInteger, .{});
    }
    pub fn setMaximumDrawableCount(self_: *@This(), maximumDrawableCount_: ns.UInteger) void {
        return objc.msgSend(self_, "setMaximumDrawableCount:", void, .{maximumDrawableCount_});
    }
    pub fn presentsWithTransaction(self_: *@This()) bool {
        return objc.msgSend(self_, "presentsWithTransaction", bool, .{});
    }
    pub fn setPresentsWithTransaction(self_: *@This(), presentsWithTransaction_: bool) void {
        return objc.msgSend(self_, "setPresentsWithTransaction:", void, .{presentsWithTransaction_});
    }
    pub fn colorspace(self_: *@This()) cg.ColorSpaceRef {
        return objc.msgSend(self_, "colorspace", cg.ColorSpaceRef, .{});
    }
    pub fn setColorspace(self_: *@This(), colorspace_: cg.ColorSpaceRef) void {
        return objc.msgSend(self_, "setColorspace:", void, .{colorspace_});
    }
    pub fn displaySyncEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "displaySyncEnabled", bool, .{});
    }
    pub fn setDisplaySyncEnabled(self_: *@This(), displaySyncEnabled_: bool) void {
        return objc.msgSend(self_, "setDisplaySyncEnabled:", void, .{displaySyncEnabled_});
    }
    pub fn allowsNextDrawableTimeout(self_: *@This()) bool {
        return objc.msgSend(self_, "allowsNextDrawableTimeout", bool, .{});
    }
    pub fn setAllowsNextDrawableTimeout(self_: *@This(), allowsNextDrawableTimeout_: bool) void {
        return objc.msgSend(self_, "setAllowsNextDrawableTimeout:", void, .{allowsNextDrawableTimeout_});
    }
};

pub const MetalDrawable = opaque {
    pub const InternalInfo = objc.ExternProtocol("CAMetalDrawable", @This(), &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn texture(self_: *@This()) *mtl.Texture {
        return objc.msgSend(self_, "texture", *mtl.Texture, .{});
    }
    pub fn layer(self_: *@This()) *MetalLayer {
        return objc.msgSend(self_, "layer", *MetalLayer, .{});
    }
};
