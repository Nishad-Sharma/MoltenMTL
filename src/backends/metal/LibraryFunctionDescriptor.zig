const c = @import("c.zig").c;
const object = @import("Object.zig");
const Library = @import("Library.zig").Library;

pub const LibraryFunctionDescriptor = extern struct {
    ptr: *c.MTL4LibraryFunctionDescriptor,
    pub fn init() ?LibraryFunctionDescriptor {
        const ptr = c.MTL4LibraryFunctionDescriptorCreate() orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn setLibrary(self: LibraryFunctionDescriptor, library: Library) void {
        c.MTL4LibraryFunctionDescriptorSetLibrary(self.ptr, library.ptr);
    }
    pub fn setName(self: LibraryFunctionDescriptor, name: [*:0]const u8) void {
        c.MTL4LibraryFunctionDescriptorSetName(self.ptr, name);
    }
    pub fn deinit(self: *LibraryFunctionDescriptor) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
