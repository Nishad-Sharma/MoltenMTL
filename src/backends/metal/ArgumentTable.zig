const c = @import("c.zig").c;
const object = @import("Object.zig");
const types = @import("Types.zig");
const Buffer = @import("Buffer.zig").Buffer;
const Texture = @import("Texture.zig").Texture;
const AccelerationStructure = @import("AccelerationStructure.zig").AccelerationStructure;

pub const ArgumentTableDescriptor = extern struct {
    ptr: *c.MTL4ArgumentTableDescriptor,
    pub fn init() ?ArgumentTableDescriptor {
        return .{ .ptr = c.MTL4ArgumentTableDescriptorCreate() };
    }
    pub fn setMaxBufferBindCount(self: ArgumentTableDescriptor, count: usize) void {
        c.MTL4ArgumentTableDescriptorSetMaxBufferBindCount(self.ptr, count);
    }
    pub fn setMaxTextureBindCount(self: ArgumentTableDescriptor, count: usize) void {
        c.MTL4ArgumentTableDescriptorSetMaxTextureBindCount(self.ptr, count);
    }
    pub fn setInitializeBindings(self: ArgumentTableDescriptor, initialize: bool) void {
        c.MTL4ArgumentTableDescriptorSetInitializeBindings(self.ptr, initialize);
    }
    pub fn deinit(self: *ArgumentTableDescriptor) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};

pub const ArgumentTable = extern struct {
    ptr: *c.MTL4ArgumentTable,
    pub fn setAddress(self: ArgumentTable, address: types.GPUAddress, binding_index: usize) void {
        c.MTL4ArgumentTableSetAddress(self.ptr, address, binding_index);
    }
    pub fn setBuffer(self: ArgumentTable, buffer: Buffer, offset: usize, binding_index: usize) void {
        c.MTL4ArgumentTableSetBuffer(self.ptr, @ptrCast(buffer.ptr), offset, binding_index);
    }
    pub fn setTexture(self: ArgumentTable, texture: Texture, binding_index: usize) void {
        c.MTL4ArgumentTableSetTexture(self.ptr, @ptrCast(texture.ptr), binding_index);
    }
    pub fn setAccelerationStructure(self: ArgumentTable, acceleration_structure: AccelerationStructure, binding_index: usize) void {
        c.MTL4ArgumentTableSetAccelerationStructure(self.ptr, @ptrCast(acceleration_structure.ptr), binding_index);
    }
    pub fn deinit(self: *ArgumentTable) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
