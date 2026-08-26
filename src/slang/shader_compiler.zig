const std = @import("std");
const c = @import("c.zig").c;

pub const Target = enum {
    msl,
    spirv,
};

pub const Stage = enum {
    vertex,
    fragment,
    compute,
};

pub const CompileDescriptor = struct {
    target: Target,
    source: []const u8,
    module_name: []const u8 = "shader",
    source_path: []const u8 = "shader.hlsl",
    entry_point: []const u8 = "main",
    stage: Stage = .compute,
    profile: []const u8 = "sm_6_6",
    search_paths: []const []const u8 = &.{},
};

pub const Status = enum {
    success,
    compilation_failed,
    invalid_argument,
    internal_error,
};

pub const Compilation = struct {
    allocator: std.mem.Allocator,
    status: Status,
    code: ?[]u8,
    diagnostics: []u8,

    pub fn succeeded(self: Compilation) bool {
        return self.status == .success;
    }

    pub fn deinit(self: *Compilation) void {
        if (self.code) |code| self.allocator.free(code);
        self.allocator.free(self.diagnostics);
        self.* = undefined;
    }
};

pub const Compiler = struct {
    ptr: *c.ShaderCompiler,

    pub fn init() error{InitializationFailed}!Compiler {
        return .{
            .ptr = c.ShaderCompilerCreate() orelse
                return error.InitializationFailed,
        };
    }

    pub fn deinit(self: *Compiler) void {
        c.ShaderCompilerDestroy(self.ptr);
        self.* = undefined;
    }

    pub fn compile(
        self: Compiler,
        allocator: std.mem.Allocator,
        descriptor: CompileDescriptor,
    ) std.mem.Allocator.Error!Compilation {
        const module_name = try allocator.dupeZ(u8, descriptor.module_name);
        defer allocator.free(module_name);
        const source_path = try allocator.dupeZ(u8, descriptor.source_path);
        defer allocator.free(source_path);
        const entry_point = try allocator.dupeZ(u8, descriptor.entry_point);
        defer allocator.free(entry_point);
        const profile = try allocator.dupeZ(u8, descriptor.profile);
        defer allocator.free(profile);

        const search_paths = try allocator.alloc([*:0]const u8, descriptor.search_paths.len);
        defer allocator.free(search_paths);
        var initialized_path_count: usize = 0;
        defer for (search_paths[0..initialized_path_count]) |path| {
            allocator.free(std.mem.span(path));
        };
        for (descriptor.search_paths, search_paths) |path, *output| {
            output.* = try allocator.dupeZ(u8, path);
            initialized_path_count += 1;
        }

        var raw_output: c.ShaderCompileOutput = std.mem.zeroes(c.ShaderCompileOutput);
        defer c.ShaderCompileOutputFree(&raw_output);
        const raw_descriptor: c.ShaderCompileDescriptor = .{
            .target = switch (descriptor.target) {
                .msl => c.ShaderTargetMsl,
                .spirv => c.ShaderTargetSpirv,
            },
            .stage = switch (descriptor.stage) {
                .vertex => c.ShaderStageVertex,
                .fragment => c.ShaderStageFragment,
                .compute => c.ShaderStageCompute,
            },
            .source = @ptrCast(descriptor.source.ptr),
            .source_size = descriptor.source.len,
            .module_name = module_name.ptr,
            .source_path = source_path.ptr,
            .entry_point = entry_point.ptr,
            .profile = profile.ptr,
            .search_paths = if (search_paths.len == 0)
                null
            else
                @ptrCast(search_paths.ptr),
            .search_path_count = search_paths.len,
        };
        const raw_status = c.ShaderCompilerCompile(
            self.ptr,
            &raw_descriptor,
            &raw_output,
        );
        if (raw_status == c.ShaderStatusOutOfMemory) return error.OutOfMemory;

        const diagnostics = try copyBlob(allocator, raw_output.diagnostics);
        errdefer allocator.free(diagnostics);
        const code = if (raw_status == c.ShaderStatusSuccess)
            try copyBlob(allocator, raw_output.code)
        else
            null;

        return .{
            .allocator = allocator,
            .status = if (raw_status == c.ShaderStatusSuccess)
                .success
            else if (raw_status == c.ShaderStatusCompilationFailed)
                .compilation_failed
            else if (raw_status == c.ShaderStatusInvalidArgument)
                .invalid_argument
            else
                .internal_error,
            .code = code,
            .diagnostics = diagnostics,
        };
    }
};

fn copyBlob(allocator: std.mem.Allocator, blob: c.ShaderBlob) ![]u8 {
    if (blob.size == 0) return allocator.alloc(u8, 0);
    const data: [*]const u8 = @ptrCast(blob.data);
    return allocator.dupe(u8, data[0..blob.size]);
}

test "compile HLSL to Metal source" {
    var compiler = try Compiler.init();
    defer compiler.deinit();

    var compilation = try compiler.compile(std.testing.allocator, .{
        .target = .msl,
        .source =
        \\RWStructuredBuffer<float> output;
        \\[numthreads(1, 1, 1)]
        \\void main(uint3 id : SV_DispatchThreadID) { output[id.x] = 42.0; }
        ,
    });
    defer compilation.deinit();

    if (!compilation.succeeded()) {
        std.debug.print("Slang diagnostics:\n{s}\n", .{compilation.diagnostics});
        return error.CompilationFailed;
    }
    try std.testing.expect(std.mem.indexOf(u8, compilation.code.?, "metal_stdlib") != null);
}

test "compile HLSL to SPIR-V" {
    var compiler = try Compiler.init();
    defer compiler.deinit();

    var compilation = try compiler.compile(std.testing.allocator, .{
        .target = .spirv,
        .source =
        \\RWStructuredBuffer<float> output;
        \\[numthreads(1, 1, 1)]
        \\void main(uint3 id : SV_DispatchThreadID) { output[id.x] = 42.0; }
        ,
    });
    defer compilation.deinit();

    if (!compilation.succeeded()) {
        std.debug.print("Slang diagnostics:\n{s}\n", .{compilation.diagnostics});
        return error.CompilationFailed;
    }
    try std.testing.expect(compilation.code.?.len >= 4);
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x03, 0x02, 0x23, 0x07 },
        compilation.code.?[0..4],
    );
}

test "return diagnostics for invalid HLSL" {
    var compiler = try Compiler.init();
    defer compiler.deinit();

    var compilation = try compiler.compile(std.testing.allocator, .{
        .target = .msl,
        .source = "this is not valid HLSL",
    });
    defer compilation.deinit();

    try std.testing.expectEqual(Status.compilation_failed, compilation.status);
    try std.testing.expect(compilation.code == null);
    try std.testing.expect(compilation.diagnostics.len != 0);
}
