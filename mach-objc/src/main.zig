const std = @import("std");
const builtin = @import("builtin");

pub const objc = @import("objc.zig");
pub const avf_audio = @import("generated/avf_audio.zig");
pub const core_foundation = @import("core_foundation.zig");
pub const core_graphics = @import("core_graphics.zig");
pub const foundation = @import("foundation.zig");
pub const metal = @import("generated/metal.zig");
pub const quartz_core = @import("generated/quartz_core.zig");
pub const core_video = @import("generated/core_video.zig");
pub const system = @import("system.zig");

/// macOS-only windowing/UI framework (NSApplication, NSWindow, NSView, ...). Defined as an empty
/// namespace on non-macOS targets so referencing it from comptime-gated code compiles cleanly.
pub const app_kit = if (builtin.os.tag == .macos) @import("generated/app_kit.zig") else struct {};

/// iOS-only windowing/UI framework (UIApplication, UIWindow, UIView, ...). Defined as an empty
/// namespace on non-iOS targets so referencing it from comptime-gated code compiles cleanly.
pub const ui_kit = if (builtin.os.tag == .ios) @import("generated/ui_kit.zig") else struct {};

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
