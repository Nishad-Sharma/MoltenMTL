const c = @import("c.zig").c;

pub const PixelFormat = c.MTLPixelFormat;
pub const PixelFormatInvalid: PixelFormat = c.MTLPixelFormatInvalid;
pub const PixelFormatR8Unorm: PixelFormat = c.MTLPixelFormatR8Unorm;
pub const PixelFormatR16Float: PixelFormat = c.MTLPixelFormatR16Float;
pub const PixelFormatRG8Unorm: PixelFormat = c.MTLPixelFormatRG8Unorm;
pub const PixelFormatR32Float: PixelFormat = c.MTLPixelFormatR32Float;
pub const PixelFormatRG16Float: PixelFormat = c.MTLPixelFormatRG16Float;
pub const PixelFormatRGBA8Unorm: PixelFormat = c.MTLPixelFormatRGBA8Unorm;
pub const PixelFormatRGBA8Unorm_sRGB: PixelFormat = c.MTLPixelFormatRGBA8Unorm_sRGB;
pub const PixelFormatBGRA8Unorm: PixelFormat = c.MTLPixelFormatBGRA8Unorm;
pub const PixelFormatBGRA8Unorm_sRGB: PixelFormat = c.MTLPixelFormatBGRA8Unorm_sRGB;
pub const PixelFormatRG32Float: PixelFormat = c.MTLPixelFormatRG32Float;
pub const PixelFormatRGBA16Float: PixelFormat = c.MTLPixelFormatRGBA16Float;
pub const PixelFormatRGBA32Float: PixelFormat = c.MTLPixelFormatRGBA32Float;
