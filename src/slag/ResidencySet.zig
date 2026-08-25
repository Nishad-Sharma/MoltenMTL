const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const Resource = @import("Resource.zig");
const Buffer = @import("Buffer.zig").Buffer;
const Texture = @import("Texture.zig").Texture;
const AccelerationStructure = @import("AccelerationStructure.zig").AccelerationStructure;

pub const ResidencySetDescriptor = extern struct {
    ptr: *c.MTLResidencySetDescriptor,
    pub fn create() ?ResidencySetDescriptor {
        return object.wrap(ResidencySetDescriptor, c.MTLResidencySetDescriptorCreate());
    }
    pub fn setInitialCapacity(self: ResidencySetDescriptor, capacity: usize) void {
        c.MTLResidencySetDescriptorSetInitialCapacity(self.ptr, capacity);
    }
    pub fn retain(self: ResidencySetDescriptor) ResidencySetDescriptor {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *ResidencySetDescriptor) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};

pub const ResidencySet = extern struct {
    ptr: *c.MTLResidencySet,
    pub fn addAllocation(self: ResidencySet, allocation: Resource.Allocation) void {
        c.MTLResidencySetAddAllocation(self.ptr, allocation.ptr);
    }
    pub fn removeAllocation(self: ResidencySet, allocation: Resource.Allocation) void {
        c.MTLResidencySetRemoveAllocation(self.ptr, allocation.ptr);
    }
    pub fn addBuffer(self: ResidencySet, buffer: Buffer) void {
        c.MTLResidencySetAddBuffer(self.ptr, buffer.ptr);
    }
    pub fn addTexture(self: ResidencySet, texture: Texture) void {
        c.MTLResidencySetAddTexture(self.ptr, texture.ptr);
    }
    pub fn addAccelerationStructure(self: ResidencySet, acceleration_structure: AccelerationStructure) void {
        c.MTLResidencySetAddAccelerationStructure(self.ptr, acceleration_structure.ptr);
    }
    pub fn commit(self: ResidencySet) void {
        c.MTLResidencySetCommit(self.ptr);
    }
    pub fn retain(self: ResidencySet) ResidencySet {
        return .{ .ptr = object.retain(self.ptr) };
    }
    pub fn release(self: *ResidencySet) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
