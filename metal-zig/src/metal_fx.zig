const mtl = @import("metal.zig");
const ns = @import("../foundation.zig");
const objc = @import("../objc.zig");

pub const Device = mtl.Device;
pub const Texture = mtl.Texture;
pub const CommandBuffer = mtl.CommandBuffer;
pub const MTL4CommandBuffer = mtl.MTL4CommandBuffer;
pub const MTL4Compiler = mtl.MTL4Compiler;
pub const UInteger = ns.UInteger;

pub const simd_float4x4 = extern struct {
    columns: [4]@Vector(4, f32),
};
