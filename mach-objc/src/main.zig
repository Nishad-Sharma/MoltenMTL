const std = @import("std");

pub const objc = @import("objc.zig");
pub const core_foundation = @import("core_foundation.zig");
pub const core_graphics = @import("core_graphics.zig");
pub const foundation = @import("foundation.zig");
pub const metal = @import("generated/metal.zig");
pub const metal_fx = @import("generated/metal_fx.zig");
pub const quartz_core = @import("generated/quartz_core.zig");
pub const system = @import("system.zig");

test {
    @setEvalBranchQuota(100000);
    refAllDeclsRecursive(@This());
}

fn refAllDeclsRecursive(comptime T: type) void {
    inline for (comptime std.meta.declarations(T)) |decl| {
        const ptr_info = @typeInfo(@TypeOf(&@field(T, decl.name)));
        if (ptr_info == .pointer and @typeInfo(ptr_info.pointer.child) == .type) {
            const Inner = @field(T, decl.name);
            const inner_info = @typeInfo(Inner);
            if (inner_info == .@"struct" or inner_info == .@"opaque") {
                refAllDeclsRecursive(Inner);
            }
        } else if (ptr_info == .pointer and @typeInfo(ptr_info.pointer.child) == .@"fn") {
            _ = &@field(T, decl.name);
        }
    }
}
