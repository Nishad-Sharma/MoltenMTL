const c = @import("c.zig").c;
pub const GPUAddress = c.MTLGPUAddress;
pub const ResourceID = c.MTLResourceID;
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

pub const Origin = extern struct {
    x: usize,
    y: usize,
    z: usize,
};

pub const Size = extern struct {
    width: usize,
    height: usize,
    depth: usize,
};

pub const Range = extern struct {
    location: usize,
    length: usize,
};

pub const Region = extern struct {
    origin: Origin,
    size: Size,
};

pub fn origin(x: usize, y: usize, z: usize) Origin {
    return .{ .x = x, .y = y, .z = z };
}

pub fn size(width: usize, height: usize, depth: usize) Size {
    return .{ .width = width, .height = height, .depth = depth };
}

pub fn range(location: usize, length: usize) Range {
    return .{ .location = location, .length = length };
}

pub fn region3D(x: usize, y: usize, z: usize, width: usize, height: usize, depth: usize) Region {
    return .{ .origin = origin(x, y, z), .size = size(width, height, depth) };
}

pub fn rawOrigin(value: Origin) c.MTLOrigin {
    return .{ .x = value.x, .y = value.y, .z = value.z };
}

pub fn rawSize(value: Size) c.MTLSize {
    return .{ .width = value.width, .height = value.height, .depth = value.depth };
}

pub fn rawRange(value: Range) c.MTLRange {
    return .{ .location = value.location, .length = value.length };
}

pub fn rawRegion(value: Region) c.MTLRegion {
    return .{ .origin = rawOrigin(value.origin), .size = rawSize(value.size) };
}
