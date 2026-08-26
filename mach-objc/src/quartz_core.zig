const cg = @import("../core_graphics.zig");
const cf = @import("../core_foundation.zig");
const mtl = @import("metal.zig");
const ns = @import("../foundation.zig");
const objc = @import("../objc.zig");

pub const UInteger = ns.UInteger;
pub const TimeInterval = ns.TimeInterval;
pub const String = ns.String;

pub const FrameRateRange = extern struct {
    minimum: f32,
    maximum: f32,
    preferred: f32,
};
