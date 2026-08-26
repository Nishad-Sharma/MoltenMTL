const c = @import("c.zig").c;
const object = @import("Object.zig");
const errors = @import("Error.zig");
const resource = @import("resource.zig");
const Buffer = @import("Buffer.zig").Buffer;
const texture = @import("texture.zig");
const CommandAllocator = @import("CommandAllocator.zig").CommandAllocator;
const CommandBuffer = @import("CommandBuffer.zig").CommandBuffer;
const CommandQueue = @import("CommandQueue.zig").CommandQueue;
const compiler = @import("Compiler.zig");
const arguments = @import("argument_table.zig");
const acceleration = @import("acceleration_structure.zig");
const residency = @import("residency_set.zig");
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
    pub fn createBuffer(self: Device, length: usize, options: resource.ResourceOptions) ?Buffer {
        const ptr = c.MTLDeviceCreateBuffer(self.ptr, length, options) orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn createBufferWithBytes(self: Device, bytes: *const anyopaque, length: usize, options: resource.ResourceOptions) ?Buffer {
        const ptr = c.MTLDeviceCreateBufferWithBytes(self.ptr, bytes, length, options) orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn createTexture(self: Device, descriptor: texture.TextureDescriptor) ?texture.Texture {
        const ptr = c.MTLDeviceCreateTexture(self.ptr, descriptor.ptr) orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn createCommandAllocator(self: Device) ?CommandAllocator {
        const ptr = c.MTLDeviceCreateCommandAllocator(self.ptr) orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn createCommandBuffer(self: Device) ?CommandBuffer {
        const ptr = c.MTLDeviceCreateCommandBuffer(self.ptr) orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn createCommandQueue(self: Device) ?CommandQueue {
        const ptr = c.MTLDeviceCreateMTL4CommandQueue(self.ptr) orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn createCompiler(self: Device, descriptor: compiler.CompilerDescriptor) !compiler.Compiler {
        var raw_error: ?*c.NSError = null;
        const result = c.MTLDeviceCreateCompiler(self.ptr, descriptor.ptr, &raw_error);
        if (raw_error) |ptr| {
            return errors.fromMTLError(ptr);
        }
        const ptr = result orelse return error.InvalidArgument;
        return .{ .ptr = ptr };
    }
    pub fn createArgumentTable(
        self: Device,
        descriptor: arguments.ArgumentTableDescriptor,
    ) !arguments.ArgumentTable {
        var raw_error: ?*c.NSError = null;
        const result = c.MTLDeviceCreateArgumentTable(self.ptr, @ptrCast(descriptor.ptr), &raw_error);
        if (raw_error) |ptr| {
            return errors.fromMTLError(ptr);
        }
        const ptr = result orelse return error.InvalidArgument;
        return .{ .ptr = ptr };
    }
    pub fn accelerationStructureSizes(self: Device, descriptor: acceleration.AccelerationStructureDescriptor) acceleration.AccelerationStructureSizes {
        return c.MTLDeviceGetAccelerationStructureSizes(self.ptr, descriptor.ptr);
    }
    pub fn createAccelerationStructure(self: Device, byte_size: usize) ?acceleration.AccelerationStructure {
        const ptr = c.MTLDeviceCreateAccelerationStructure(self.ptr, byte_size) orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn createResidencySet(self: Device, descriptor: residency.ResidencySetDescriptor) !residency.ResidencySet {
        var raw_error: ?*c.NSError = null;
        const result = c.MTLDeviceCreateResidencySet(self.ptr, descriptor.ptr, &raw_error);
        if (raw_error) |ptr| {
            return errors.fromMTLError(ptr);
        }
        const ptr = result orelse return error.InvalidArgument;
        return .{ .ptr = ptr };
    }
    pub fn createSharedEvent(self: Device) ?SharedEvent {
        const ptr = c.MTLDeviceCreateSharedEvent(self.ptr) orelse return null;
        return .{ .ptr = ptr };
    }
    pub fn deinit(self: *Device) void {
        object.release(self.ptr);
        self.* = undefined;
    }
};
