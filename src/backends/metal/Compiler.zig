const c = @import("c.zig").c;
const object = @import("Object.zig");
const errors = @import("Error.zig");
const Library = @import("Library.zig").Library;
const LibraryDescriptor = @import("LibraryDescriptor.zig").LibraryDescriptor;
const ComputePipelineDescriptor = @import("compute_pipeline.zig").ComputePipelineDescriptor;
const ComputePipelineState = @import("compute_pipeline.zig").ComputePipelineState;

pub const CompilerDescriptor = extern struct {
    ptr: *c.MTL4CompilerDescriptor,
    pub fn init() ?CompilerDescriptor {
        const ptr = c.MTL4CompilerDescriptorCreate() orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn deinit(self: *CompilerDescriptor) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};

pub const Compiler = extern struct {
    ptr: *c.MTL4Compiler,
    pub fn createLibrary(self: Compiler, descriptor: LibraryDescriptor) !Library {
        var raw_error: ?*c.NSError = null;
        const result = c.MTL4CompilerCreateLibrary(self.ptr, descriptor.ptr, &raw_error);
        if (raw_error) |ptr| {
            return errors.fromMetalError(ptr);
        }
        const ptr = result orelse return error.InvalidArgument;
        return .{ .ptr = ptr };
    }
    pub fn createComputePipelineState(self: Compiler, descriptor: ComputePipelineDescriptor) !ComputePipelineState {
        var raw_error: ?*c.NSError = null;
        const result = c.MTL4CompilerCreateComputePipelineState(self.ptr, descriptor.ptr, &raw_error);
        if (raw_error) |ptr| {
            return errors.fromMetalError(ptr);
        }
        const ptr = result orelse return error.InvalidArgument;
        return .{ .ptr = ptr };
    }
    pub fn deinit(self: *Compiler) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
