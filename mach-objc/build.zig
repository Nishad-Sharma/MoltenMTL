const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const module = b.addModule("mach-objc", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.linkSystemLibrary("objc", .{});

    if (target.result.os.tag == .macos) {
        module.linkFramework("AppKit", .{});
        module.linkFramework("CoreVideo", .{});
        module.linkFramework("QuartzCore", .{});
    } else if (target.result.os.tag == .ios) {
        module.linkFramework("UIKit", .{});
        module.linkFramework("QuartzCore", .{});
        module.linkFramework("Foundation", .{});
    }

    addXcodeFrameworks(b, module, target, optimize);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    unit_tests.root_module.linkSystemLibrary("objc", .{});
    if (target.result.os.tag == .macos) {
        unit_tests.root_module.linkFramework("AppKit", .{});
        unit_tests.root_module.linkFramework("CoreVideo", .{});
        unit_tests.root_module.linkFramework("Metal", .{});
        unit_tests.root_module.linkFramework("QuartzCore", .{});
        unit_tests.root_module.linkFramework("AVFAudio", .{});
        unit_tests.root_module.linkFramework("CoreMIDI", .{});
    } else if (target.result.os.tag == .ios) {
        unit_tests.root_module.linkFramework("UIKit", .{});
        unit_tests.root_module.linkFramework("Metal", .{});
        unit_tests.root_module.linkFramework("QuartzCore", .{});
        unit_tests.root_module.linkFramework("AVFAudio", .{});
        unit_tests.root_module.linkFramework("CoreMIDI", .{});
        unit_tests.root_module.linkFramework("Foundation", .{});
        unit_tests.root_module.linkFramework("CoreGraphics", .{});
    }
    addXcodeFrameworks(b, unit_tests.root_module, target, optimize);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const generator_exe = b.addExecutable(.{
        .name = "generator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("generator.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(generator_exe);

    const gen_run = b.addRunArtifact(generator_exe);
    gen_run.addArg("--generate-all");
    if (b.lazyDependency("xcode_frameworks", .{})) |dep| {
        gen_run.addArg("--frameworks-dir");
        gen_run.addDirectoryArg(dep.path("Frameworks"));
        gen_run.addArg("--iphoneos-frameworks-dir");
        gen_run.addDirectoryArg(dep.path("iphoneos/Frameworks"));
        gen_run.addArg("--iphoneos-include-dir");
        gen_run.addDirectoryArg(dep.path("iphoneos/include"));
    }

    const generate_step = b.step("generate", "Generate files");
    generate_step.dependOn(&gen_run.step);
}

/// Adds system framework / include / library paths from the bundled `xcode_frameworks` package,
/// picking the right subtree based on `target` (macOS vs iOS device vs iOS simulator).
fn addXcodeFrameworks(
    b: *std.Build,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    _ = optimize;
    const dep = b.lazyDependency("xcode_frameworks", .{}) orelse return;

    const subdir: ?[]const u8 = switch (target.result.os.tag) {
        .macos => null,
        .ios => if (target.result.abi == .simulator) "iphonesimulator" else "iphoneos",
        else => null,
    };

    if (subdir) |sd| {
        module.addSystemFrameworkPath(dep.path(b.fmt("{s}/Frameworks", .{sd})));
        module.addSystemIncludePath(dep.path(b.fmt("{s}/include", .{sd})));
        module.addLibraryPath(dep.path(b.fmt("{s}/lib", .{sd})));
    } else {
        module.addSystemFrameworkPath(dep.path("Frameworks"));
        module.addSystemIncludePath(dep.path("include"));
        module.addLibraryPath(dep.path("lib"));
    }
}
