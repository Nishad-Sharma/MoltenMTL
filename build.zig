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

    const library_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    library_module.addIncludePath(b.path("include"));
    library_module.addSystemIncludePath(metal_cpp.path(""));
    library_module.addCSourceFiles(.{
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
    library_module.linkFramework("Foundation", .{});
    library_module.linkFramework("Metal", .{});
    library_module.linkFramework("QuartzCore", .{});

    const library = b.addLibrary(.{
        .name = "metal-c",
        .linkage = .static,
        .root_module = library_module,
    });
    library.installHeadersDirectory(b.path("include/Metal"), "Metal", .{});
    library.installHeadersDirectory(b.path("include/QuartzCore"), "QuartzCore", .{});
    b.installArtifact(library);
}
