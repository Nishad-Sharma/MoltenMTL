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
    metal_c_module.addIncludePath(b.path("include"));
    metal_c_module.addSystemIncludePath(metal_cpp.path(""));
    metal_c_module.addCSourceFiles(.{
        .files = &.{
            "src/Metal/MetalCppImplementation.cpp",
            "src/Metal/MTLObject.cpp",
            "src/Metal/MTLError.cpp",
            "src/Metal/MTLDevice.cpp",
            "src/Metal/MTLResource.cpp",
            "src/Metal/MTLResidencySet.cpp",
            "src/Metal/MTL4ArgumentTable.cpp",
            "src/Metal/MTL4Command.cpp",
            "src/Metal/MTL4Compiler.cpp",
            "src/Metal/MTL4ComputeCommandEncoder.cpp",
            "src/Metal/MTL4AccelerationStructure.cpp",
            "src/QuartzCore/CAMetalLayer.cpp",
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

    const slag_module = b.addModule("metal", .{
        .root_source_file = b.path("src/slag.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    slag_module.addIncludePath(b.path("include"));
    slag_module.linkLibrary(metal_c_library);

    metal_c_library.installHeadersDirectory(b.path("include/Metal"), "Metal", .{});
    metal_c_library.installHeadersDirectory(b.path("include/QuartzCore"), "QuartzCore", .{});
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
