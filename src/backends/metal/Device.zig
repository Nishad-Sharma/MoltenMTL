const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const errors = @import("Error.zig");
const resource = @import("Resource.zig");
const Buffer = @import("Buffer.zig").Buffer;
const texture = @import("Texture.zig");
const CommandAllocator = @import("CommandAllocator.zig").CommandAllocator;
const CommandBuffer = @import("CommandBuffer.zig").CommandBuffer;
const CommandQueue = @import("CommandQueue.zig").CommandQueue;
const compiler = @import("Compiler.zig");
const arguments = @import("ArgumentTable.zig");
const acceleration = @import("AccelerationStructure.zig");
const residency = @import("ResidencySet.zig");
const SharedEvent = @import("Event.zig").SharedEvent;

pub fn createSystemDefaultDevice() ?Device {
    const ptr = c.MTLCreateSystemDefaultDevice() orelse return null;
    return .{ .ptr = ptr };
}

pub const Device = extern struct {
    ptr: *c.MTLDevice,
    pub fn name(self: Device) [*:0]const u8 {
        return @ptrCast(c.MTLDeviceGetName(self.ptr));
    }
    pub fn supportsMetal4(self: Device) bool {
        return c.MTLDeviceSupportsMetal4(self.ptr);
    }
    pub fn newBuffer(self: Device, length: usize, options: resource.ResourceOptions) ?Buffer {
        return object.wrap(Buffer, c.MTLDeviceNewBuffer(self.ptr, length, options));
    }
    pub fn newBufferWithBytes(self: Device, bytes: *const anyopaque, length: usize, options: resource.ResourceOptions) ?Buffer {
        return object.wrap(Buffer, c.MTLDeviceNewBufferWithBytes(self.ptr, bytes, length, options));
    }
    pub fn newTexture(self: Device, descriptor: texture.TextureDescriptor) ?texture.Texture {
        return object.wrap(texture.Texture, c.MTLDeviceNewTexture(self.ptr, descriptor.ptr));
    }
    pub fn newCommandAllocator(self: Device) ?CommandAllocator {
        return object.wrap(CommandAllocator, c.MTLDeviceNewCommandAllocator(self.ptr));
    }
    pub fn newCommandBuffer(self: Device) ?CommandBuffer {
        return object.wrap(CommandBuffer, c.MTLDeviceNewCommandBuffer(self.ptr));
    }
    pub fn newCommandQueue(self: Device) ?CommandQueue {
        return object.wrap(CommandQueue, c.MTLDeviceNewMTL4CommandQueue(self.ptr));
    }
    pub fn newCompiler(self: Device, descriptor: compiler.CompilerDescriptor, error_out: ?*?errors.Error) ?compiler.Compiler {
        var raw_error: ?*c.MTLError = null;
        const result = c.MTLDeviceNewCompiler(self.ptr, descriptor.ptr, if (error_out != null) &raw_error else null);
        errors.write(error_out, raw_error);
        return object.wrap(compiler.Compiler, result);
    }
    pub fn newArgumentTable(self: Device, descriptor: arguments.ArgumentTableDescriptor, error_out: ?*?errors.Error) ?arguments.ArgumentTable {
        var raw_error: ?*c.MTLError = null;
        const result = c.MTLDeviceNewArgumentTable(self.ptr, @ptrCast(descriptor.ptr), if (error_out != null) &raw_error else null);
        errors.write(error_out, raw_error);
        return object.wrap(arguments.ArgumentTable, result);
    }
    pub fn accelerationStructureSizes(self: Device, descriptor: acceleration.AccelerationStructureDescriptor) acceleration.AccelerationStructureSizes {
        return c.MTLDeviceGetAccelerationStructureSizes(self.ptr, descriptor.ptr);
    }
    pub fn newAccelerationStructure(self: Device, byte_size: usize) ?acceleration.AccelerationStructure {
        return object.wrap(acceleration.AccelerationStructure, c.MTLDeviceNewAccelerationStructure(self.ptr, byte_size));
    }
    pub fn newResidencySet(self: Device, descriptor: residency.ResidencySetDescriptor, error_out: ?*?errors.Error) ?residency.ResidencySet {
        var raw_error: ?*c.MTLError = null;
        const result = c.MTLDeviceNewResidencySet(self.ptr, descriptor.ptr, if (error_out != null) &raw_error else null);
        errors.write(error_out, raw_error);
        return object.wrap(residency.ResidencySet, result);
    }
    pub fn newSharedEvent(self: Device) ?SharedEvent {
        return object.wrap(SharedEvent, c.MTLDeviceNewSharedEvent(self.ptr));
    }
    pub fn deinit(self: *Device) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
