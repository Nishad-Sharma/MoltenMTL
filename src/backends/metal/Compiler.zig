const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const errors = @import("Error.zig");
const Library = @import("Library.zig").Library;
const LibraryDescriptor = @import("LibraryDescriptor.zig").LibraryDescriptor;
const ComputePipelineDescriptor = @import("ComputePipeline.zig").ComputePipelineDescriptor;
const ComputePipelineState = @import("ComputePipeline.zig").ComputePipelineState;

pub const CompilerDescriptor = extern struct {
    ptr: *c.MTL4CompilerDescriptor,
    pub fn create() ?CompilerDescriptor {
        return object.wrap(CompilerDescriptor, c.MTL4CompilerDescriptorCreate());
    }
    pub fn deinit(self: *CompilerDescriptor) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};

pub const Compiler = extern struct {
    ptr: *c.MTL4Compiler,
    pub fn newLibrary(self: Compiler, descriptor: LibraryDescriptor, error_out: ?*?errors.Error) ?Library {
        var raw_error: ?*c.MTLError = null;
        const result = c.MTL4CompilerNewLibrary(self.ptr, descriptor.ptr, if (error_out != null) &raw_error else null);
        errors.write(error_out, raw_error);
        return object.wrap(Library, result);
    }
    pub fn newComputePipelineState(self: Compiler, descriptor: ComputePipelineDescriptor, error_out: ?*?errors.Error) ?ComputePipelineState {
        var raw_error: ?*c.MTLError = null;
        const result = c.MTL4CompilerNewComputePipelineState(self.ptr, descriptor.ptr, if (error_out != null) &raw_error else null);
        errors.write(error_out, raw_error);
        return object.wrap(ComputePipelineState, result);
    }
    pub fn deinit(self: *Compiler) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
