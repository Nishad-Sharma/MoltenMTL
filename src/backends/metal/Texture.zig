const c = @import("Raw.zig").c;
const object = @import("Object.zig");
const pixel = @import("PixelFormat.zig");
const resource = @import("Resource.zig");
const types = @import("Types.zig");

pub const TextureType = c.MTLTextureType;
pub const TextureUsage = c.MTLTextureUsage;
pub const TextureType1D: TextureType = c.MTLTextureType1D;
pub const TextureType1DArray: TextureType = c.MTLTextureType1DArray;
pub const TextureType2D: TextureType = c.MTLTextureType2D;
pub const TextureType2DArray: TextureType = c.MTLTextureType2DArray;
pub const TextureTypeCube: TextureType = c.MTLTextureTypeCube;
pub const TextureTypeCubeArray: TextureType = c.MTLTextureTypeCubeArray;
pub const TextureType3D: TextureType = c.MTLTextureType3D;
pub const TextureUsageUnknown: TextureUsage = c.MTLTextureUsageUnknown;
pub const TextureUsageShaderRead: TextureUsage = c.MTLTextureUsageShaderRead;
pub const TextureUsageShaderWrite: TextureUsage = c.MTLTextureUsageShaderWrite;
pub const TextureUsageRenderTarget: TextureUsage = c.MTLTextureUsageRenderTarget;
pub const TextureUsagePixelFormatView: TextureUsage = c.MTLTextureUsagePixelFormatView;

pub const TextureDescriptor = extern struct {
    ptr: *c.MTLTextureDescriptor,

    pub fn create() ?TextureDescriptor {
        return object.wrap(TextureDescriptor, c.MTLTextureDescriptorCreate());
    }
    pub fn create2D(format: pixel.PixelFormat, width: usize, height: usize, mipmapped: bool) ?TextureDescriptor {
        return object.wrap(TextureDescriptor, c.MTLTextureDescriptorCreate2D(format, width, height, mipmapped));
    }
    pub fn setTextureType(self: TextureDescriptor, texture_type: TextureType) void {
        c.MTLTextureDescriptorSetTextureType(self.ptr, texture_type);
    }
    pub fn setPixelFormat(self: TextureDescriptor, format: pixel.PixelFormat) void {
        c.MTLTextureDescriptorSetPixelFormat(self.ptr, format);
    }
    pub fn setWidth(self: TextureDescriptor, width: usize) void {
        c.MTLTextureDescriptorSetWidth(self.ptr, width);
    }
    pub fn setHeight(self: TextureDescriptor, height: usize) void {
        c.MTLTextureDescriptorSetHeight(self.ptr, height);
    }
    pub fn setDepth(self: TextureDescriptor, depth: usize) void {
        c.MTLTextureDescriptorSetDepth(self.ptr, depth);
    }
    pub fn setArrayLength(self: TextureDescriptor, length: usize) void {
        c.MTLTextureDescriptorSetArrayLength(self.ptr, length);
    }
    pub fn setMipmapLevelCount(self: TextureDescriptor, count: usize) void {
        c.MTLTextureDescriptorSetMipmapLevelCount(self.ptr, count);
    }
    pub fn setResourceOptions(self: TextureDescriptor, options: resource.ResourceOptions) void {
        c.MTLTextureDescriptorSetResourceOptions(self.ptr, options);
    }
    pub fn setUsage(self: TextureDescriptor, usage: TextureUsage) void {
        c.MTLTextureDescriptorSetUsage(self.ptr, usage);
    }
    pub fn deinit(self: *TextureDescriptor) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};

pub const Texture = extern struct {
    ptr: *c.MTLTexture,

    pub fn width(self: Texture) usize {
        return c.MTLTextureGetWidth(self.ptr);
    }
    pub fn height(self: Texture) usize {
        return c.MTLTextureGetHeight(self.ptr);
    }
    pub fn depth(self: Texture) usize {
        return c.MTLTextureGetDepth(self.ptr);
    }
    pub fn pixelFormat(self: Texture) pixel.PixelFormat {
        return c.MTLTextureGetPixelFormat(self.ptr);
    }
    pub fn gpuResourceID(self: Texture) types.ResourceID {
        return c.MTLTextureGetGPUResourceID(self.ptr);
    }
    pub fn replaceRegion(self: Texture, destination: types.Region, mipmap_level: usize, slice: usize, bytes: *const anyopaque, bytes_per_row: usize, bytes_per_image: usize) void {
        c.MTLTextureReplaceRegion(self.ptr, destination, mipmap_level, slice, bytes, bytes_per_row, bytes_per_image);
    }
    pub fn setLabel(self: Texture, label: [*:0]const u8) void {
        self.asResource().setLabel(label);
    }
    pub fn allocatedSize(self: Texture) usize {
        return self.asResource().allocatedSize();
    }
    pub fn asResource(self: Texture) resource.Resource {
        return .{ .ptr = @ptrCast(self.ptr) };
    }
    pub fn asAllocation(self: Texture) resource.Allocation {
        return .{ .ptr = @ptrCast(self.ptr) };
    }
    pub fn deinit(self: *Texture) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};
