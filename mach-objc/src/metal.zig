const std = @import("std");
const cf = @import("../core_foundation.zig");
const ns = @import("../foundation.zig");
const objc = @import("../objc.zig");

// ------------------------------------------------------------------------------------------------
// Opaque types

pub const dispatch_data_t = *opaque {};
pub const dispatch_queue_t = *opaque {};
pub const IOSurfaceRef = *opaque {};
pub const GPUAddress = u64;
pub const task_id_token_t = u32;
pub const kern_return_t = c_int;

// Forward-declared by MTLDevice.h but not defined as an Objective-C class in the SDK.
pub const TilePipelineColorAttachmentDescriptor = opaque {};

// ------------------------------------------------------------------------------------------------
// Types

// MTLCounters.hpp
pub const CommonCounter = *ns.String;
pub const CommonCounterSet = *ns.String;

// MTLDevice.hpp
pub const DeviceNotificationName = *ns.String;
pub const AutoreleasedComputePipelineReflection = *ComputePipelineReflection;
pub const AutoreleasedRenderPipelineReflection = *RenderPipelineReflection;
pub const Timestamp = u64;

// MTLLibrary.hpp
pub const AutoreleasedArgument = *Argument;

// ------------------------------------------------------------------------------------------------
// Constants

// MTLCounters.hpp
extern const CounterErrorDomain: ns.ErrorDomain;

extern const CommonCounterTimestamp: CommonCounter;
extern const CommonCounterTessellationInputPatches: CommonCounter;
extern const CommonCounterVertexInvocations: CommonCounter;
extern const CommonCounterPostTessellationVertexInvocations: CommonCounter;
extern const CommonCounterClipperInvocations: CommonCounter;
extern const CommonCounterClipperPrimitivesOut: CommonCounter;
extern const CommonCounterFragmentInvocations: CommonCounter;
extern const CommonCounterFragmentsPassed: CommonCounter;
extern const CommonCounterComputeKernelInvocations: CommonCounter;
extern const CommonCounterTotalCycles: CommonCounter;
extern const CommonCounterVertexCycles: CommonCounter;
extern const CommonCounterTessellationCycles: CommonCounter;
extern const CommonCounterPostTessellationVertexCycles: CommonCounter;
extern const CommonCounterFragmentCycles: CommonCounter;
extern const CommonCounterRenderTargetWriteCycles: CommonCounter;

extern const CommonCounterSetTimestamp: CommonCounterSet;
extern const CommonCounterSetStageUtilization: CommonCounterSet;
extern const CommonCounterSetStatistic: CommonCounterSet;

// MTLDevice.hpp
extern const DeviceWasAddedNotification: DeviceNotificationName;
extern const DeviceRemovalRequestedNotification: DeviceNotificationName;
extern const DeviceWasRemovedNotification: DeviceNotificationName;

// ------------------------------------------------------------------------------------------------
// Functions

// MTLDevice.hpp
extern fn MTLCreateSystemDefaultDevice() ?*Device;
pub const createSystemDefaultDevice = MTLCreateSystemDefaultDevice;

//extern fn MTLCopyAllDevices() *ns.Array;
//extern fn MTLCopyAllDevicesWithObserver(**ns.Object, DeviceNotificationHandlerBlock) *ns.Array;
//extern fn MTLRemoveDeviceObserver(*ns.Object) void;

// ------------------------------------------------------------------------------------------------
// Structs

// MTLComputeCommandEncoder.hpp
pub const DispatchThreadgroupsIndirectArguments = extern struct {
    threadgroupsPerGrid: [3]u32,

    pub fn init(threadgroupsPerGrid: [3]u32) DispatchThreadgroupsIndirectArguments {
        return DispatchThreadgroupsIndirectArguments{ .threadgroupsPerGrid = threadgroupsPerGrid };
    }
};

pub const StageInRegionIndirectArguments = extern struct {
    stageInOrigin: [3]u32,
    stageInSize: [3]u32,

    pub fn init(stageInOrigin: [3]u32, stageInSize: [3]u32) StageInRegionIndirectArguments {
        return StageInRegionIndirectArguments{ .stageInOrigin = stageInOrigin, .stageInSize = stageInSize };
    }
};

// MTLRenderCommandEncoder.hpp
pub const ScissorRect = extern struct {
    x: ns.UInteger,
    y: ns.UInteger,
    width: ns.UInteger,
    height: ns.UInteger,

    pub fn init(x: ns.UInteger, y: ns.UInteger, width: ns.UInteger, height: ns.UInteger) ScissorRect {
        return ScissorRect{ .x = x, .y = y, .width = width, .height = height };
    }
};

pub const Viewport = extern struct {
    originX: f64,
    originY: f64,
    width: f64,
    height: f64,
    znear: f64,
    zfar: f64,

    pub fn init(originX: f64, originY: f64, width: f64, height: f64, znear: f64, zfar: f64) Viewport {
        return Viewport{ .originX = originX, .originY = originY, .width = width, .height = height, .znear = znear, .zfar = zfar };
    }
};

pub const VertexAmplificationViewMapping = extern struct {
    viewportArrayIndexOffset: u32,
    renderTargetArrayIndexOffset: u32,

    pub fn init(viewportArrayIndexOffset: u32, renderTargetArrayIndexOffset: u32) VertexAmplificationViewMapping {
        return VertexAmplificationViewMapping{ .viewportArrayIndexOffset = viewportArrayIndexOffset, .renderTargetArrayIndexOffset = renderTargetArrayIndexOffset };
    }
};

// MTLRenderPass.hpp
pub const ClearColor = extern struct {
    red: f64,
    green: f64,
    blue: f64,
    alpha: f64,

    pub fn init(red: f64, green: f64, blue: f64, alpha: f64) ClearColor {
        return ClearColor{ .red = red, .green = green, .blue = blue, .alpha = alpha };
    }
};

// MTLTexture.hpp
pub const TextureSwizzleChannels = extern struct {
    red: TextureSwizzle,
    green: TextureSwizzle,
    blue: TextureSwizzle,
    alpha: TextureSwizzle,

    pub fn init(red: TextureSwizzle, green: TextureSwizzle, blue: TextureSwizzle, alpha: TextureSwizzle) TextureSwizzleChannels {
        return TextureSwizzleChannels{ .red = red, .green = green, .blue = blue, .alpha = alpha };
    }
};

// MTLTypes.hpp
pub const Origin = extern struct {
    x: ns.UInteger,
    y: ns.UInteger,
    z: ns.UInteger,

    pub fn init(x: ns.UInteger, y: ns.UInteger, z: ns.UInteger) Origin {
        return .{ .x = x, .y = y, .z = z };
    }
};

pub const Size = extern struct {
    width: ns.UInteger,
    height: ns.UInteger,
    depth: ns.UInteger,

    pub fn init(width: ns.UInteger, height: ns.UInteger, depth: ns.UInteger) Size {
        return .{ .width = width, .height = height, .depth = depth };
    }
};

pub const Region = extern struct {
    origin: Origin,
    size: Size,

    pub fn init1d(x: ns.UInteger, width: ns.UInteger) Region {
        return .{ .origin = .{ .x = x, .y = 0, .z = 0 }, .size = .{ .width = width, .height = 1, .depth = 1 } };
    }

    pub fn init2d(x: ns.UInteger, y: ns.UInteger, width: ns.UInteger, height: ns.UInteger) Region {
        return .{ .origin = .{ .x = x, .y = y, .z = 0 }, .size = .{ .width = width, .height = height, .depth = 1 } };
    }

    pub fn init3d(x: ns.UInteger, y: ns.UInteger, z: ns.UInteger, width: ns.UInteger, height: ns.UInteger, depth: ns.UInteger) Region {
        return .{ .origin = .{ .x = x, .y = y, .z = z }, .size = .{ .width = width, .height = height, .depth = depth } };
    }
};

pub const SamplePosition = extern struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) SamplePosition {
        return .{ .x = x, .y = y };
    }
};

pub const Coordinate2D = SamplePosition;

pub const ResourceID = extern struct {
    _impl: u64,
};

// MTLCounters.hpp
pub const CounterResultTimestamp = extern struct { timestamp: u64 };

pub const CounterResultStageUtilization = extern struct {
    totalCycles: u64,
    vertexCycles: u64,
    tessellationCycles: u64,
    postTessellationVertexCycles: u64,
    fragmentCycles: u64,
    renderTargetCycles: u64,
};

pub const CounterResultStatistic = extern struct {
    tessellationInputPatches: u64,
    vertexInvocations: u64,
    postTessellationVertexInvocations: u64,
    clipperInvocations: u64,
    clipperPrimitivesOut: u64,
    fragmentInvocations: u64,
    fragmentsPassed: u64,
    computeKernelInvocations: u64,
};

// MTLDevice.hpp
pub const AccelerationStructureSizes = extern struct {
    accelerationStructureSize: ns.UInteger,
    buildScratchBufferSize: ns.UInteger,
    refitScratchBufferSize: ns.UInteger,
};

pub const SizeAndAlign = extern struct {
    size: ns.UInteger,
    @"align": ns.UInteger,
};

// MTL4BufferRange.h
pub const MTL4BufferRange = extern struct {
    bufferAddress: u64,
    length: u64,

    pub fn init(buffer_address: u64, length: u64) MTL4BufferRange {
        return .{ .bufferAddress = buffer_address, .length = length };
    }
};

// MTL4Counters.h
pub const MTL4TimestampHeapEntry = extern struct {
    timestamp: u64,
};

// MTL4CommandQueue.h
pub const MTL4UpdateSparseTextureMappingOperation = extern struct {
    mode: SparseTextureMappingMode,
    textureRegion: Region,
    textureLevel: ns.UInteger,
    textureSlice: ns.UInteger,
    heapOffset: ns.UInteger,
};

pub const MTL4CopySparseTextureMappingOperation = extern struct {
    sourceRegion: Region,
    sourceLevel: ns.UInteger,
    sourceSlice: ns.UInteger,
    destinationOrigin: Origin,
    destinationLevel: ns.UInteger,
    destinationSlice: ns.UInteger,
};

pub const MTL4UpdateSparseBufferMappingOperation = extern struct {
    mode: SparseTextureMappingMode,
    bufferRange: ns.Range,
    heapOffset: ns.UInteger,
};

pub const MTL4CopySparseBufferMappingOperation = extern struct {
    sourceRange: ns.Range,
    destinationOffset: ns.UInteger,
};

comptime {
    std.debug.assert(@sizeOf(MTL4BufferRange) == 16);
    std.debug.assert(@sizeOf(MTL4TimestampHeapEntry) == 8);
    std.debug.assert(@sizeOf(MTL4UpdateSparseTextureMappingOperation) == 80);
    std.debug.assert(@sizeOf(MTL4CopySparseTextureMappingOperation) == 104);
    std.debug.assert(@sizeOf(MTL4UpdateSparseBufferMappingOperation) == 32);
    std.debug.assert(@sizeOf(MTL4CopySparseBufferMappingOperation) == 24);
}
// ------------------------------------------------------------------------------------------------
