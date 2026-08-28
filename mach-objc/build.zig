const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // mach-objc does not parse availability or weak-link post-floor symbols, so
    // the deployment floor is the contract: every symbol in the selected surface
    // must exist at this version.
    //
    // Checked here rather than pinned into the default target query. Setting
    // os_version_min makes Query.isNativeOs() false, at which point Zig stops
    // discovering the host SDK and every module that links objc or a framework
    // fails with "unable to find dynamic system library 'objc' ... searched
    // paths: none". A real pin would have to pass the SDK's framework, include
    // and library paths to every module by hand.
    if (target.result.os.tag != .macos or target.result.cpu.arch != .aarch64) {
        @panic("mach-objc requires an aarch64-macos target");
    }
    if (target.result.os.version_range.semver.min.order(.{
        .major = 26,
        .minor = 0,
        .patch = 0,
    }) == .lt) {
        @panic("mach-objc requires a macOS 26.0 or newer deployment target");
    }
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

    const objc_abi_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/objc_abi.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    objc_abi_tests.root_module.addImport("mach-objc", module);
    objc_abi_tests.root_module.addCSourceFile(.{
        .file = b.path("tests/objc_abi_fixture.m"),
        .flags = &.{"-fno-objc-arc"},
    });
    objc_abi_tests.root_module.linkSystemLibrary("objc", .{});
    objc_abi_tests.root_module.linkFramework("Foundation", .{});

    const run_objc_abi_tests = b.addRunArtifact(objc_abi_tests);
    test_step.dependOn(&run_objc_abi_tests.step);

    const generator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("generator.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    const run_generator_tests = b.addRunArtifact(generator_tests);
    test_step.dependOn(&run_generator_tests.step);

    const block_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/objc_blocks.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    block_tests.root_module.addImport("mach-objc", module);
    const run_block_tests = b.addRunArtifact(block_tests);
    test_step.dependOn(&run_block_tests.step);

    const drawable_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/metal_drawable.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    drawable_tests.root_module.addImport("mach-objc", module);
    const run_drawable_tests = b.addRunArtifact(drawable_tests);
    test_step.dependOn(&run_drawable_tests.step);

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
