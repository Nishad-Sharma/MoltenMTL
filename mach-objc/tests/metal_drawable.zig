const std = @import("std");
const mach = @import("mach-objc");

const ca = mach.quartz_core;
const cg = mach.core_graphics;
const mtl = mach.metal;
const ns = mach.foundation;
const objc = mach.objc;

// The swapchain path, without a window server.
//
// A `CAMetalLayer` is normally handed to you by whatever owns the window --
// AppKit once, SDL3 now -- but the layer is what vends drawables either way,
// and it does so whether or not it is attached to anything on screen. That
// makes `nextDrawable`/`present` testable here, which matters because those
// two calls are the whole of the RHI's presentation surface and nothing else
// in the repo touches them.
test "an unattached CAMetalLayer vends a drawable and presents it" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const device = mtl.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();

    const layer = ca.MetalLayer.allocInit().?;
    defer layer.release();
    layer.setDevice(device);
    layer.setPixelFormat(mtl.PixelFormatBGRA8Unorm);
    layer.setFramebufferOnly(false);
    layer.setMaximumDrawableCount(3);
    layer.setDrawableSize(.{ .width = 64, .height = 32 });

    // Round-trip the properties a renderer configures, so a wrong ABI on any of
    // them fails here rather than inside one.
    try std.testing.expectEqual(mtl.PixelFormatBGRA8Unorm, layer.pixelFormat());
    try std.testing.expectEqual(@as(cg.Float, 64), layer.drawableSize().width);
    try std.testing.expectEqual(@as(cg.Float, 32), layer.drawableSize().height);
    try std.testing.expect(layer.device() != null);

    const drawable = layer.nextDrawable() orelse return error.NoDrawable;

    // `nextDrawable` is +0: the drawable belongs to the pool, not to us. Its
    // texture has to match what the layer was asked for, and it has to survive
    // being addressed as an MTLTexture, because every downstream use of it goes
    // through Metal rather than QuartzCore.
    const texture = drawable.texture();
    try std.testing.expectEqual(@as(ns.UInteger, 64), texture.width());
    try std.testing.expectEqual(@as(ns.UInteger, 32), texture.height());
    try std.testing.expectEqual(mtl.PixelFormatBGRA8Unorm, texture.pixelFormat());

    // CAMetalDrawable conforms to MTLDrawable, which is where `present` lives.
    // The cast is the one the renderer makes.
    const mtl_drawable: *mtl.Drawable = @ptrCast(drawable);
    mtl_drawable.present();
}
