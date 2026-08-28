const std = @import("std");

// The Objective-C bindings generator under metal-zig/ is currently
// the only live build target:
//
//     cd metal-zig && zig build test
//     cd metal-zig && ./verify.sh
//
// This root script is intentionally empty so that `zig build` at the
// repository root does not fail against a stale configuration. Wire the RHI
// targets back in here once the RHI is rebuilt on top of the generated
// bindings.
pub fn build(b: *std.Build) void {
    _ = b;
}
