const c = @import("Raw.zig").c;

pub const GPUAddress = c.MTLGPUAddress;
pub const ResourceID = c.MTLResourceID;
pub const Origin = c.MTLOrigin;
pub const Size = c.MTLSize;
pub const Range = c.MTLRange;
pub const Region = c.MTLRegion;
pub const PackedFloat4x3 = c.MTLPackedFloat4x3;
pub const Stages = c.MTLStages;
pub const IndexType = c.MTLIndexType;
pub const AttributeFormat = c.MTLAttributeFormat;

pub const StageVertex: Stages = c.MTLStageVertex;
pub const StageFragment: Stages = c.MTLStageFragment;
pub const StageTile: Stages = c.MTLStageTile;
pub const StageObject: Stages = c.MTLStageObject;
pub const StageMesh: Stages = c.MTLStageMesh;
pub const StageResourceState: Stages = c.MTLStageResourceState;
pub const StageBlit: Stages = c.MTLStageBlit;
pub const StageAccelerationStructure: Stages = c.MTLStageAccelerationStructure;
pub const StageDispatch: Stages = c.MTLStageDispatch;
pub const StageAll: Stages = c.MTLStageAll;

pub const IndexTypeUInt16: IndexType = c.MTLIndexTypeUInt16;
pub const IndexTypeUInt32: IndexType = c.MTLIndexTypeUInt32;
pub const AttributeFormatInvalid: AttributeFormat = c.MTLAttributeFormatInvalid;
pub const AttributeFormatFloat: AttributeFormat = c.MTLAttributeFormatFloat;
pub const AttributeFormatFloat2: AttributeFormat = c.MTLAttributeFormatFloat2;
pub const AttributeFormatFloat3: AttributeFormat = c.MTLAttributeFormatFloat3;
pub const AttributeFormatFloat4: AttributeFormat = c.MTLAttributeFormatFloat4;

pub fn origin(x: usize, y: usize, z: usize) Origin {
    return c.MTLOriginMake(x, y, z);
}
pub fn size(width: usize, height: usize, depth: usize) Size {
    return c.MTLSizeMake(width, height, depth);
}
pub fn range(location: usize, length: usize) Range {
    return c.MTLRangeMake(location, length);
}
pub fn region3D(x: usize, y: usize, z: usize, width: usize, height: usize, depth: usize) Region {
    return c.MTLRegionMake3D(x, y, z, width, height, depth);
}

pub const BufferRange = extern struct {
    address: GPUAddress,
    length: usize,

    pub fn make(buffer: anytype, offset: usize, byte_length: usize) BufferRange {
        const value = c.MTL4BufferRangeMake(buffer.ptr, offset, byte_length);
        return .{ .address = value.address, .length = value.length };
    }
    pub fn raw(self: BufferRange) c.MTL4BufferRange {
        return .{ .address = self.address, .length = self.length };
    }
};
