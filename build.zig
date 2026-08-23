const std = @import("std");

fn linkMoltenMTL(
    module: *std.Build.Module,
    library: *std.Build.Step.Compile,
    slangLib: []const u8,
) void {
    module.addLibraryPath(.{ .cwd_relative = slangLib });
    module.addRPath(.{ .cwd_relative = slangLib });
    module.linkLibrary(library);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .macos) {
        @panic("only the Metal 4 backend is implemented; Vulkan support is the next backend slice");
    }
    if (!(target.result.os.isAtLeast(.macos, .{ .major = 26, .minor = 0, .patch = 0 }) orelse false)) {
        @panic("the Metal 4 backend requires a macOS 26.0 or newer deployment target");
    }

    const metal_cpp = b.dependency("metal_cpp", .{});
    const slangInstall = b.graph.environ_map.get("SLANG_INSTALL") orelse
        @panic("SLANG_INSTALL must point to a Slang development package");
    const slangInclude = b.pathResolve(&.{ slangInstall, "include" });
    const slangLib = b.pathResolve(&.{ slangInstall, "lib" });

    const library_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    library_module.addIncludePath(b.path("include"));
    library_module.addSystemIncludePath(metal_cpp.path(""));
    library_module.addSystemIncludePath(.{ .cwd_relative = slangInclude });
    library_module.addLibraryPath(.{ .cwd_relative = slangLib });
    library_module.addRPath(.{ .cwd_relative = slangLib });
    library_module.addCSourceFiles(.{
        .files = &.{
            "src/metal/MetalCppImplementation.cpp",
            "src/metal/MetalDevice.cpp",
            "src/metal/MetalResources.cpp",
            "src/metal/MetalCompute.cpp",
            "src/metal/MetalAccelerationStructure.cpp",
            "src/metal/MetalSurface.cpp",
        },
        .flags = &.{
            "-std=c++17",
            "-fvisibility=hidden",
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
        },
    });
    library_module.linkFramework("Foundation", .{});
    library_module.linkFramework("Metal", .{});
    library_module.linkFramework("QuartzCore", .{});
    library_module.linkSystemLibrary("slang-compiler", .{ .use_pkg_config = .no });

    const library = b.addLibrary(.{
        .name = "MoltenMTL",
        .linkage = .static,
        .root_module = library_module,
    });
    library.installHeader(
        b.path("include/MoltenMTL/MoltenMTL.h"),
        "MoltenMTL/MoltenMTL.h",
    );
    b.installArtifact(library);

    const smoke_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    smoke_module.addCSourceFile(.{
        .file = b.path("Tests/native/device_queue_smoke.c"),
        .flags = &.{
            "-std=c17",
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
        },
    });
    linkMoltenMTL(smoke_module, library, slangLib);

    const smoke_test = b.addExecutable(.{
        .name = "device-queue-smoke",
        .root_module = smoke_module,
    });
    const run_smoke_test = b.addRunArtifact(smoke_test);

    const compute_smoke_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    compute_smoke_module.addCSourceFile(.{
        .file = b.path("Tests/native/buffer_compute_smoke.c"),
        .flags = &.{
            "-std=c17",
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
        },
    });
    linkMoltenMTL(compute_smoke_module, library, slangLib);

    const compute_smoke_test = b.addExecutable(.{
        .name = "buffer-compute-smoke",
        .root_module = compute_smoke_module,
    });
    const run_compute_smoke_test = b.addRunArtifact(compute_smoke_test);

    const ray_query_smoke_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    ray_query_smoke_module.addCSourceFile(.{
        .file = b.path("Tests/native/ray_query_smoke.c"),
        .flags = &.{
            "-std=c17",
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
        },
    });
    linkMoltenMTL(ray_query_smoke_module, library, slangLib);

    const ray_query_smoke_test = b.addExecutable(.{
        .name = "ray-query-smoke",
        .root_module = ray_query_smoke_module,
    });
    const run_ray_query_smoke_test = b.addRunArtifact(ray_query_smoke_test);

    const output_texture_smoke_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    output_texture_smoke_module.addCSourceFile(.{
        .file = b.path("Tests/native/output_texture_smoke.c"),
        .flags = &.{
            "-std=c17",
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
        },
    });
    linkMoltenMTL(output_texture_smoke_module, library, slangLib);

    const output_texture_smoke_test = b.addExecutable(.{
        .name = "output-texture-smoke",
        .root_module = output_texture_smoke_module,
    });
    const run_output_texture_smoke_test = b.addRunArtifact(output_texture_smoke_test);

    const test_step = b.step("test", "Run native C API tests");
    test_step.dependOn(&run_smoke_test.step);
    test_step.dependOn(&run_compute_smoke_test.step);
    test_step.dependOn(&run_ray_query_smoke_test.step);
    test_step.dependOn(&run_output_texture_smoke_test.step);

    const surface_smoke_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    surface_smoke_module.addCSourceFile(.{
        .file = b.path("Tests/native/surface_presentation_smoke.c"),
        .flags = &.{
            "-std=c17",
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
        },
    });
    linkMoltenMTL(surface_smoke_module, library, slangLib);
    surface_smoke_module.linkSystemLibrary("SDL3", .{});

    const surface_smoke_test = b.addExecutable(.{
        .name = "surface-presentation-smoke",
        .root_module = surface_smoke_module,
    });
    const run_surface_smoke_test = b.addRunArtifact(surface_smoke_test);

    const sdl_test_step = b.step("test-sdl", "Run the SDL3 surface presentation test");
    sdl_test_step.dependOn(&run_surface_smoke_test.step);
}
