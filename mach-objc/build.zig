const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const sdk_root = b.option(
        []const u8,
        "macos-sdk",
        "macOS SDK root used to generate bindings",
    ) orelse "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
    const frameworks_dir = b.pathResolve(&.{ sdk_root, "System/Library/Frameworks" });

    const module = b.addModule("mach-objc", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.linkSystemLibrary("objc", .{});
    module.linkFramework("Foundation", .{});
    module.linkFramework("Metal", .{});
    module.linkFramework("MetalFX", .{});
    module.linkFramework("QuartzCore", .{});

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    unit_tests.root_module.linkSystemLibrary("objc", .{});
    unit_tests.root_module.linkFramework("Foundation", .{});
    unit_tests.root_module.linkFramework("Metal", .{});
    unit_tests.root_module.linkFramework("MetalFX", .{});
    unit_tests.root_module.linkFramework("QuartzCore", .{});

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_unit_tests.step);

    const raytrace_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/metal4_raytrace.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    raytrace_tests.root_module.addImport("mach-objc", module);
    const run_raytrace_tests = b.addRunArtifact(raytrace_tests);
    test_step.dependOn(&run_raytrace_tests.step);

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
    gen_run.addArgs(&.{ "--sdk-root", sdk_root, "--frameworks-dir", frameworks_dir });

    const generate_step = b.step("generate", "Generate files");
    generate_step.dependOn(&gen_run.step);
}
