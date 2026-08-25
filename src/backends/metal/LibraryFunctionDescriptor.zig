const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const Library = @import("Library.zig").Library;

pub const LibraryFunctionDescriptor = extern struct {
    ptr: *c.MTL4LibraryFunctionDescriptor,
    pub fn create() ?LibraryFunctionDescriptor {
        return object.wrap(LibraryFunctionDescriptor, c.MTL4LibraryFunctionDescriptorCreate());
    }
    pub fn setLibrary(self: LibraryFunctionDescriptor, library: Library) void {
        c.MTL4LibraryFunctionDescriptorSetLibrary(self.ptr, library.ptr);
    }
    pub fn setName(self: LibraryFunctionDescriptor, name: [*:0]const u8) void {
        c.MTL4LibraryFunctionDescriptorSetName(self.ptr, name);
    }
    pub fn deinit(self: *LibraryFunctionDescriptor) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
