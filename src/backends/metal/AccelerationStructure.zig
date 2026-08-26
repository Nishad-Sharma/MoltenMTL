const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const resource = @import("Resource.zig");
const types = @import("Types.zig");

pub const AccelerationStructureUsage = c.MTLAccelerationStructureUsage;
pub const AccelerationStructureInstanceDescriptorType = c.MTLAccelerationStructureInstanceDescriptorType;
pub const AccelerationStructureInstanceOptions = c.MTLAccelerationStructureInstanceOptions;
pub const AccelerationStructureSizes = c.MTLAccelerationStructureSizes;
pub const AccelerationStructureInstanceDescriptor = c.MTLAccelerationStructureInstanceDescriptor;
pub const AccelerationStructureUserIDInstanceDescriptor = c.MTLAccelerationStructureUserIDInstanceDescriptor;
pub const IndirectAccelerationStructureInstanceDescriptor = c.MTLIndirectAccelerationStructureInstanceDescriptor;
pub const AccelerationStructureUsageNone: AccelerationStructureUsage = c.MTLAccelerationStructureUsageNone;
pub const AccelerationStructureUsageRefit: AccelerationStructureUsage = c.MTLAccelerationStructureUsageRefit;
pub const AccelerationStructureUsagePreferFastBuild: AccelerationStructureUsage = c.MTLAccelerationStructureUsagePreferFastBuild;
pub const AccelerationStructureUsageExtendedLimits: AccelerationStructureUsage = c.MTLAccelerationStructureUsageExtendedLimits;
pub const AccelerationStructureUsagePreferFastIntersection: AccelerationStructureUsage = c.MTLAccelerationStructureUsagePreferFastIntersection;
pub const AccelerationStructureUsageMinimizeMemory: AccelerationStructureUsage = c.MTLAccelerationStructureUsageMinimizeMemory;
pub const AccelerationStructureInstanceDescriptorTypeDefault: AccelerationStructureInstanceDescriptorType = c.MTLAccelerationStructureInstanceDescriptorTypeDefault;
pub const AccelerationStructureInstanceDescriptorTypeUserID: AccelerationStructureInstanceDescriptorType = c.MTLAccelerationStructureInstanceDescriptorTypeUserID;
pub const AccelerationStructureInstanceDescriptorTypeIndirect: AccelerationStructureInstanceDescriptorType = c.MTLAccelerationStructureInstanceDescriptorTypeIndirect;
pub const AccelerationStructureInstanceOptionNone: AccelerationStructureInstanceOptions = c.MTLAccelerationStructureInstanceOptionNone;
pub const AccelerationStructureInstanceOptionDisableTriangleCulling: AccelerationStructureInstanceOptions = c.MTLAccelerationStructureInstanceOptionDisableTriangleCulling;
pub const AccelerationStructureInstanceOptionTriangleFrontFacingWindingCounterClockwise: AccelerationStructureInstanceOptions = c.MTLAccelerationStructureInstanceOptionTriangleFrontFacingWindingCounterClockwise;
pub const AccelerationStructureInstanceOptionOpaque: AccelerationStructureInstanceOptions = c.MTLAccelerationStructureInstanceOptionOpaque;
pub const AccelerationStructureInstanceOptionNonOpaque: AccelerationStructureInstanceOptions = c.MTLAccelerationStructureInstanceOptionNonOpaque;

pub const AccelerationStructure = extern struct {
    ptr: *c.MTLAccelerationStructure,
    pub fn size(self: AccelerationStructure) usize {
        return c.MTLAccelerationStructureGetSize(self.ptr);
    }
    pub fn gpuResourceID(self: AccelerationStructure) types.ResourceID {
        return c.MTLAccelerationStructureGetGPUResourceID(self.ptr);
    }
    pub fn asAllocation(self: AccelerationStructure) resource.Allocation {
        return .{ .ptr = @ptrCast(self.ptr) };
    }
    pub fn deinit(self: *AccelerationStructure) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};

pub const AccelerationStructureDescriptor = extern struct { ptr: *c.MTL4AccelerationStructureDescriptor };
pub const AccelerationStructureTriangleGeometryDescriptor = extern struct {
    ptr: *c.MTL4AccelerationStructureTriangleGeometryDescriptor,
    pub fn init() ?AccelerationStructureTriangleGeometryDescriptor {
        return .{ .ptr = c.MTL4AccelerationStructureTriangleGeometryDescriptorCreate() };
    }
    pub fn setVertexBuffer(self: AccelerationStructureTriangleGeometryDescriptor, buffer: types.BufferRange) void {
        c.MTL4AccelerationStructureTriangleGeometryDescriptorSetVertexBuffer(self.ptr, buffer.raw());
    }
    pub fn setVertexFormat(self: AccelerationStructureTriangleGeometryDescriptor, format: types.AttributeFormat) void {
        c.MTL4AccelerationStructureTriangleGeometryDescriptorSetVertexFormat(self.ptr, format);
    }
    pub fn setVertexStride(self: AccelerationStructureTriangleGeometryDescriptor, stride: usize) void {
        c.MTL4AccelerationStructureTriangleGeometryDescriptorSetVertexStride(self.ptr, stride);
    }
    pub fn setIndexBuffer(self: AccelerationStructureTriangleGeometryDescriptor, buffer: types.BufferRange) void {
        c.MTL4AccelerationStructureTriangleGeometryDescriptorSetIndexBuffer(self.ptr, buffer.raw());
    }
    pub fn setIndexType(self: AccelerationStructureTriangleGeometryDescriptor, index_type: types.IndexType) void {
        c.MTL4AccelerationStructureTriangleGeometryDescriptorSetIndexType(self.ptr, index_type);
    }
    pub fn setTriangleCount(self: AccelerationStructureTriangleGeometryDescriptor, count: usize) void {
        c.MTL4AccelerationStructureTriangleGeometryDescriptorSetTriangleCount(self.ptr, count);
    }
    pub fn setOpaque(self: AccelerationStructureTriangleGeometryDescriptor, is_opaque: bool) void {
        c.MTL4AccelerationStructureTriangleGeometryDescriptorSetOpaque(self.ptr, is_opaque);
    }
    pub fn deinit(self: *AccelerationStructureTriangleGeometryDescriptor) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};

pub const PrimitiveAccelerationStructureDescriptor = extern struct {
    ptr: *c.MTL4PrimitiveAccelerationStructureDescriptor,
    pub fn init() ?PrimitiveAccelerationStructureDescriptor {
        return .{ .ptr = c.MTL4PrimitiveAccelerationStructureDescriptorCreate() };
    }
    pub fn setGeometryDescriptors(self: PrimitiveAccelerationStructureDescriptor, descriptors: []const AccelerationStructureTriangleGeometryDescriptor) void {
        c.MTL4PrimitiveAccelerationStructureDescriptorSetGeometryDescriptors(self.ptr, @ptrCast(descriptors.ptr), descriptors.len);
    }
    pub fn setUsage(self: PrimitiveAccelerationStructureDescriptor, usage: AccelerationStructureUsage) void {
        c.MTL4PrimitiveAccelerationStructureDescriptorSetUsage(self.ptr, usage);
    }
    pub fn asAccelerationStructureDescriptor(self: PrimitiveAccelerationStructureDescriptor) AccelerationStructureDescriptor {
        return .{ .ptr = @ptrCast(self.ptr) };
    }
    pub fn deinit(self: *PrimitiveAccelerationStructureDescriptor) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};

pub const InstanceAccelerationStructureDescriptor = extern struct {
    ptr: *c.MTL4InstanceAccelerationStructureDescriptor,
    pub fn init() ?InstanceAccelerationStructureDescriptor {
        return .{ .ptr = c.MTL4InstanceAccelerationStructureDescriptorCreate() };
    }
    pub fn setInstanceDescriptorBuffer(self: InstanceAccelerationStructureDescriptor, buffer: types.BufferRange) void {
        c.MTL4InstanceAccelerationStructureDescriptorSetInstanceDescriptorBuffer(self.ptr, buffer.raw());
    }
    pub fn setInstanceDescriptorStride(self: InstanceAccelerationStructureDescriptor, stride: usize) void {
        c.MTL4InstanceAccelerationStructureDescriptorSetInstanceDescriptorStride(self.ptr, stride);
    }
    pub fn setInstanceDescriptorType(self: InstanceAccelerationStructureDescriptor, descriptor_type: AccelerationStructureInstanceDescriptorType) void {
        c.MTL4InstanceAccelerationStructureDescriptorSetInstanceDescriptorType(self.ptr, descriptor_type);
    }
    pub fn setInstanceCount(self: InstanceAccelerationStructureDescriptor, count: usize) void {
        c.MTL4InstanceAccelerationStructureDescriptorSetInstanceCount(self.ptr, count);
    }
    pub fn setUsage(self: InstanceAccelerationStructureDescriptor, usage: AccelerationStructureUsage) void {
        c.MTL4InstanceAccelerationStructureDescriptorSetUsage(self.ptr, usage);
    }
    pub fn asAccelerationStructureDescriptor(self: InstanceAccelerationStructureDescriptor) AccelerationStructureDescriptor {
        return .{ .ptr = @ptrCast(self.ptr) };
    }
    pub fn deinit(self: *InstanceAccelerationStructureDescriptor) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
