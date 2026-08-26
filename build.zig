const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const slang_install = b.graph.environ_map.get("SLANG_INSTALL") orelse
        @panic("SLANG_INSTALL must point to a Slang development package");
    const slang_include = b.pathResolve(&.{ slang_install, "include" });
    const slang_lib_dir = b.pathResolve(&.{ slang_install, "lib" });

    const slang_module = b.addModule("slang", .{
        .root_source_file = b.path("src/slang/shader_compiler.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    slang_module.addIncludePath(b.path("src/slang"));
    slang_module.addSystemIncludePath(.{ .cwd_relative = slang_include });
    slang_module.addLibraryPath(.{ .cwd_relative = slang_lib_dir });
    slang_module.addRPath(.{ .cwd_relative = slang_lib_dir });
    slang_module.linkSystemLibrary("slang-compiler", .{ .use_pkg_config = .no });
    slang_module.addCSourceFile(.{
        .file = b.path("src/slang/ShaderCompiler.cpp"),
        .flags = &.{
            "-std=c++17",
            "-fvisibility=hidden",
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
        },
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
        .metal => createMetalBackend(b, target, optimize, slang_module),
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
    const slag_library = b.addLibrary(.{
        .name = "slag",
        .linkage = .static,
        .root_module = slag_module,
    });

    b.installArtifact(slag_library);

    const wrapper_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/vector_add.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "slag", .module = slag_module }},
        }),
    });
    const run_wrapper_tests = b.addRunArtifact(wrapper_tests);
    const test_step = b.step("test", "Run the Zig wrapper tests");
    test_step.dependOn(&run_wrapper_tests.step);

    const shader_compiler_tests = b.addTest(.{
        .root_module = slang_module,
    });
    const run_shader_compiler_tests = b.addRunArtifact(shader_compiler_tests);
    test_step.dependOn(&run_shader_compiler_tests.step);
}

fn createMetalBackend(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    shader_compiler_module: *std.Build.Module,
) *std.Build.Module {
    if (target.result.os.tag != .macos) {
        @panic("only the Metal 4 backend is implemented; Vulkan support is the next backend slice");
    }
    if (!(target.result.os.isAtLeast(.macos, .{ .major = 26, .minor = 0, .patch = 0 }) orelse false)) {
        @panic("the Metal 4 backend requires a macOS 26.0 or newer deployment target");
    }
    const metal_cpp = b.dependency("metal_cpp", .{});
    const backend_module = b.addModule("slag_backend", .{
        .root_source_file = b.path("src/backends/metal.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
        .imports = &.{
            .{ .name = "shader_compiler", .module = shader_compiler_module },
        },
    });
    backend_module.addIncludePath(b.path("metal-c/include"));
    backend_module.addSystemIncludePath(metal_cpp.path(""));
    backend_module.addCSourceFiles(.{
        .root = b.path("metal-c/src"),
        .files = &.{
            "Metal/MetalImplementation.cpp",
            "Metal/MTLDevice.cpp",
            "Metal/MTLResource.cpp",
            "Metal/MTLResidencySet.cpp",
            "Metal/MTL4ArgumentTable.cpp",
            "Metal/MTL4Command.cpp",
            "Metal/MTL4Compiler.cpp",
            "Metal/MTL4ComputeCommandEncoder.cpp",
            "Metal/MTL4AccelerationStructure.cpp",
            "Foundation/NSError.cpp",
            "Foundation/NSObject.cpp",
            "QuartzCore/CAMetalLayer.cpp",
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
    backend_module.linkFramework("Foundation", .{});
    backend_module.linkFramework("Metal", .{});
    backend_module.linkFramework("QuartzCore", .{});
    return backend_module;
}
