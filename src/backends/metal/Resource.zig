const c = @import("Raw.zig").c;
const object = @import("Object.zig");

pub const ResourceOptions = c.MTLResourceOptions;
pub const ResourceCPUCacheModeDefaultCache: ResourceOptions = c.MTLResourceCPUCacheModeDefaultCache;
pub const ResourceCPUCacheModeWriteCombined: ResourceOptions = c.MTLResourceCPUCacheModeWriteCombined;
pub const ResourceStorageModeShared: ResourceOptions = c.MTLResourceStorageModeShared;
pub const ResourceStorageModeManaged: ResourceOptions = c.MTLResourceStorageModeManaged;
pub const ResourceStorageModePrivate: ResourceOptions = c.MTLResourceStorageModePrivate;
pub const ResourceStorageModeMemoryless: ResourceOptions = c.MTLResourceStorageModeMemoryless;
pub const ResourceHazardTrackingModeDefault: ResourceOptions = c.MTLResourceHazardTrackingModeDefault;
pub const ResourceHazardTrackingModeUntracked: ResourceOptions = c.MTLResourceHazardTrackingModeUntracked;
pub const ResourceHazardTrackingModeTracked: ResourceOptions = c.MTLResourceHazardTrackingModeTracked;

pub const Resource = extern struct {
    ptr: *c.MTLResource,

    pub fn setLabel(self: Resource, label: [*:0]const u8) void {
        c.MTLResourceSetLabel(self.ptr, label);
    }
    pub fn allocatedSize(self: Resource) usize {
        return c.MTLResourceGetAllocatedSize(self.ptr);
    }
    pub fn deinit(self: *Resource) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};

pub const Allocation = extern struct { ptr: *c.MTLAllocation };
