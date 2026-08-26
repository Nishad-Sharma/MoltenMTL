const c = @import("c.zig").c;
const object = @import("Object.zig");

pub const LibraryDescriptor = extern struct {
    ptr: *c.MTL4LibraryDescriptor,
    pub fn init() ?LibraryDescriptor {
        return .{ .ptr = c.MTL4LibraryDescriptorCreate() };
    }
    pub fn setName(self: LibraryDescriptor, name: [*:0]const u8) void {
        c.MTL4LibraryDescriptorSetName(self.ptr, name);
    }
    pub fn setSource(self: LibraryDescriptor, source: [*:0]const u8) void {
        c.MTL4LibraryDescriptorSetSource(self.ptr, source);
    }
    pub fn deinit(self: *LibraryDescriptor) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
