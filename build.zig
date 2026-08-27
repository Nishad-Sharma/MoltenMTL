const std = @import("std");

// The MoltenMTL RHI and the metal-c C++ shim were removed in "delete old
// project". The Objective-C bindings generator under mach-objc/ is currently
// the only live build target:
//
//     cd mach-objc && zig build test
//     cd mach-objc && ./verify.sh
//
// This root script is intentionally empty so that `zig build` at the
// repository root does not fail against a stale configuration. Wire the RHI
// targets back in here once the RHI is rebuilt on top of the generated
// bindings.
pub fn build(b: *std.Build) void {
    _ = b;
}
