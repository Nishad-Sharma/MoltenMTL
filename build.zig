const std = @import("std");

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

    const metal_c_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    metal_c_module.addIncludePath(b.path("metal-c/include"));
    metal_c_module.addSystemIncludePath(metal_cpp.path(""));
    metal_c_module.addCSourceFiles(.{
        .files = &.{
            "metal-c/src/Metal/MetalCppImplementation.cpp",
            "metal-c/src/Metal/MTLObject.cpp",
            "metal-c/src/Metal/MTLError.cpp",
            "metal-c/src/Metal/MTLDevice.cpp",
            "metal-c/src/Metal/MTLResource.cpp",
            "metal-c/src/Metal/MTLResidencySet.cpp",
            "metal-c/src/Metal/MTL4ArgumentTable.cpp",
            "metal-c/src/Metal/MTL4Command.cpp",
            "metal-c/src/Metal/MTL4Compiler.cpp",
            "metal-c/src/Metal/MTL4ComputeCommandEncoder.cpp",
            "metal-c/src/Metal/MTL4AccelerationStructure.cpp",
            "metal-c/src/QuartzCore/CAMetalLayer.cpp",
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
    metal_c_module.linkFramework("Foundation", .{});
    metal_c_module.linkFramework("Metal", .{});
    metal_c_module.linkFramework("QuartzCore", .{});

    const metal_c_library = b.addLibrary(.{
        .name = "metal-c",
        .linkage = .static,
        .root_module = metal_c_module,
    });

    const Backend = enum {
        metal,
        vulkan,
    };

    const default_backend: Backend = switch (target.result.os.tag) {
        .macos => .metal,
        .windows, .linux => .vulkan,
        else => @panic("unsupported platform"),
    };

    const selected_backend =
        b.option(Backend, "backend", "Slag graphics backend") orelse
        default_backend;

    const backend_module = switch (selected_backend) {
        .metal => createMetalBackend(b, target, optimize),
        .vulkan => @panic("Vulkan backend is not implemented yet"),
    };

    const slag_module = b.addModule("slag", .{
        .root_source_file = b.path("src/slag.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "slag_backend", .module = backend_module },
        },
    });

    slag_module.addIncludePath(b.path("metal-c/include"));
    slag_module.linkLibrary(metal_c_library);

    metal_c_library.installHeadersDirectory(b.path("metal-c/include/Metal"), "Metal", .{});
    metal_c_library.installHeadersDirectory(b.path("metal-c/include/QuartzCore"), "QuartzCore", .{});
    b.installArtifact(metal_c_library);

    const wrapper_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("Tests/zig/slag_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "slag", .module = slag_module }},
        }),
    });
    const run_wrapper_tests = b.addRunArtifact(wrapper_tests);
    const test_step = b.step("test", "Run the Zig wrapper tests");
    test_step.dependOn(&run_wrapper_tests.step);
}

fn createMetalBackend(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const backend_module = b.addModule("slag_backend", .{
        .root_source_file = b.path("src/backends/metal.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    backend_module.addIncludePath(b.path("metal-c/include"));
    return backend_module;
}
