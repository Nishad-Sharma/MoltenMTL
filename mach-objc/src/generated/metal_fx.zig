const mtl = @import("metal.zig");
const ns = @import("../foundation.zig");
const objc = @import("../objc.zig");

pub const Device = mtl.Device;
pub const Texture = mtl.Texture;
pub const CommandBuffer = mtl.CommandBuffer;
pub const MTL4CommandBuffer = mtl.MTL4CommandBuffer;
pub const MTL4Compiler = mtl.MTL4Compiler;
pub const UInteger = ns.UInteger;

pub const simd_float4x4 = extern struct {
    columns: [4]@Vector(4, f32),
};

pub const SpatialScalerColorProcessingMode = ns.Integer;
pub const SpatialScalerColorProcessingModePerceptual: SpatialScalerColorProcessingMode = 0;
pub const SpatialScalerColorProcessingModeLinear: SpatialScalerColorProcessingMode = 1;
pub const SpatialScalerColorProcessingModeHDR: SpatialScalerColorProcessingMode = 2;

pub const FrameInterpolatorDescriptor = opaque {
    pub const InternalInfo = objc.ExternClass("MTLFXFrameInterpolatorDescriptor", @This(), ns.ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    /// Returns +1: the caller owns the result and must release it.
    pub fn newFrameInterpolatorWithDevice(self_: *@This(), device_: *mtl.Device) ?*FrameInterpolator {
        return objc.msgSend(self_, "newFrameInterpolatorWithDevice:", ?*FrameInterpolator, .{device_});
    }
    /// Returns +1: the caller owns the result and must release it.
    pub fn newFrameInterpolatorWithDevice_compiler(self_: *@This(), device_: *mtl.Device, compiler_: *mtl.MTL4Compiler) ?*MTL4FXFrameInterpolator {
        return objc.msgSend(self_, "newFrameInterpolatorWithDevice:compiler:", ?*MTL4FXFrameInterpolator, .{ device_, compiler_ });
    }
    pub fn supportsMetal4FX(device_: *mtl.Device) bool {
        return objc.msgSend(@This().InternalInfo.class(), "supportsMetal4FX:", bool, .{device_});
    }
    pub fn supportsDevice(device_: *mtl.Device) bool {
        return objc.msgSend(@This().InternalInfo.class(), "supportsDevice:", bool, .{device_});
    }
    pub fn colorTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "colorTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setColorTextureFormat(self_: *@This(), colorTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setColorTextureFormat:", void, .{colorTextureFormat_});
    }
    pub fn outputTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "outputTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setOutputTextureFormat(self_: *@This(), outputTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setOutputTextureFormat:", void, .{outputTextureFormat_});
    }
    pub fn depthTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "depthTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setDepthTextureFormat(self_: *@This(), depthTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setDepthTextureFormat:", void, .{depthTextureFormat_});
    }
    pub fn motionTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "motionTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setMotionTextureFormat(self_: *@This(), motionTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setMotionTextureFormat:", void, .{motionTextureFormat_});
    }
    pub fn uiTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "uiTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setUITextureFormat(self_: *@This(), uiTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setUITextureFormat:", void, .{uiTextureFormat_});
    }
    pub fn scaler(self_: *@This()) ?*FrameInterpolatableScaler {
        return objc.msgSend(self_, "scaler", ?*FrameInterpolatableScaler, .{});
    }
    pub fn setScaler(self_: *@This(), scaler_: ?*FrameInterpolatableScaler) void {
        return objc.msgSend(self_, "setScaler:", void, .{scaler_});
    }
    pub fn inputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputWidth", ns.UInteger, .{});
    }
    pub fn setInputWidth(self_: *@This(), inputWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputWidth:", void, .{inputWidth_});
    }
    pub fn inputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputHeight", ns.UInteger, .{});
    }
    pub fn setInputHeight(self_: *@This(), inputHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputHeight:", void, .{inputHeight_});
    }
    pub fn outputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputWidth", ns.UInteger, .{});
    }
    pub fn setOutputWidth(self_: *@This(), outputWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setOutputWidth:", void, .{outputWidth_});
    }
    pub fn outputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputHeight", ns.UInteger, .{});
    }
    pub fn setOutputHeight(self_: *@This(), outputHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setOutputHeight:", void, .{outputHeight_});
    }
};

pub const SpatialScalerDescriptor = opaque {
    pub const InternalInfo = objc.ExternClass("MTLFXSpatialScalerDescriptor", @This(), ns.ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    /// Returns +1: the caller owns the result and must release it.
    pub fn newSpatialScalerWithDevice(self_: *@This(), device_: *mtl.Device) ?*SpatialScaler {
        return objc.msgSend(self_, "newSpatialScalerWithDevice:", ?*SpatialScaler, .{device_});
    }
    /// Returns +1: the caller owns the result and must release it.
    pub fn newSpatialScalerWithDevice_compiler(self_: *@This(), device_: *mtl.Device, compiler_: *mtl.MTL4Compiler) ?*MTL4FXSpatialScaler {
        return objc.msgSend(self_, "newSpatialScalerWithDevice:compiler:", ?*MTL4FXSpatialScaler, .{ device_, compiler_ });
    }
    pub fn supportsMetal4FX(device_: *mtl.Device) bool {
        return objc.msgSend(@This().InternalInfo.class(), "supportsMetal4FX:", bool, .{device_});
    }
    pub fn supportsDevice(device_: *mtl.Device) bool {
        return objc.msgSend(@This().InternalInfo.class(), "supportsDevice:", bool, .{device_});
    }
    pub fn colorTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "colorTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setColorTextureFormat(self_: *@This(), colorTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setColorTextureFormat:", void, .{colorTextureFormat_});
    }
    pub fn outputTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "outputTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setOutputTextureFormat(self_: *@This(), outputTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setOutputTextureFormat:", void, .{outputTextureFormat_});
    }
    pub fn inputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputWidth", ns.UInteger, .{});
    }
    pub fn setInputWidth(self_: *@This(), inputWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputWidth:", void, .{inputWidth_});
    }
    pub fn inputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputHeight", ns.UInteger, .{});
    }
    pub fn setInputHeight(self_: *@This(), inputHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputHeight:", void, .{inputHeight_});
    }
    pub fn outputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputWidth", ns.UInteger, .{});
    }
    pub fn setOutputWidth(self_: *@This(), outputWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setOutputWidth:", void, .{outputWidth_});
    }
    pub fn outputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputHeight", ns.UInteger, .{});
    }
    pub fn setOutputHeight(self_: *@This(), outputHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setOutputHeight:", void, .{outputHeight_});
    }
    pub fn colorProcessingMode(self_: *@This()) SpatialScalerColorProcessingMode {
        return objc.msgSend(self_, "colorProcessingMode", SpatialScalerColorProcessingMode, .{});
    }
    pub fn setColorProcessingMode(self_: *@This(), colorProcessingMode_: SpatialScalerColorProcessingMode) void {
        return objc.msgSend(self_, "setColorProcessingMode:", void, .{colorProcessingMode_});
    }
};

pub const TemporalDenoisedScalerDescriptor = opaque {
    pub const InternalInfo = objc.ExternClass("MTLFXTemporalDenoisedScalerDescriptor", @This(), ns.ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    /// Returns +1: the caller owns the result and must release it.
    pub fn newTemporalDenoisedScalerWithDevice(self_: *@This(), device_: *mtl.Device) ?*TemporalDenoisedScaler {
        return objc.msgSend(self_, "newTemporalDenoisedScalerWithDevice:", ?*TemporalDenoisedScaler, .{device_});
    }
    /// Returns +1: the caller owns the result and must release it.
    pub fn newTemporalDenoisedScalerWithDevice_compiler(self_: *@This(), device_: *mtl.Device, compiler_: *mtl.MTL4Compiler) ?*MTL4FXTemporalDenoisedScaler {
        return objc.msgSend(self_, "newTemporalDenoisedScalerWithDevice:compiler:", ?*MTL4FXTemporalDenoisedScaler, .{ device_, compiler_ });
    }
    pub fn supportedInputContentMinScaleForDevice(device_: *mtl.Device) f32 {
        return objc.msgSend(@This().InternalInfo.class(), "supportedInputContentMinScaleForDevice:", f32, .{device_});
    }
    pub fn supportedInputContentMaxScaleForDevice(device_: *mtl.Device) f32 {
        return objc.msgSend(@This().InternalInfo.class(), "supportedInputContentMaxScaleForDevice:", f32, .{device_});
    }
    pub fn supportsMetal4FX(device_: *mtl.Device) bool {
        return objc.msgSend(@This().InternalInfo.class(), "supportsMetal4FX:", bool, .{device_});
    }
    pub fn supportsDevice(device_: *mtl.Device) bool {
        return objc.msgSend(@This().InternalInfo.class(), "supportsDevice:", bool, .{device_});
    }
    pub fn colorTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "colorTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setColorTextureFormat(self_: *@This(), colorTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setColorTextureFormat:", void, .{colorTextureFormat_});
    }
    pub fn depthTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "depthTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setDepthTextureFormat(self_: *@This(), depthTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setDepthTextureFormat:", void, .{depthTextureFormat_});
    }
    pub fn motionTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "motionTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setMotionTextureFormat(self_: *@This(), motionTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setMotionTextureFormat:", void, .{motionTextureFormat_});
    }
    pub fn diffuseAlbedoTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "diffuseAlbedoTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setDiffuseAlbedoTextureFormat(self_: *@This(), diffuseAlbedoTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setDiffuseAlbedoTextureFormat:", void, .{diffuseAlbedoTextureFormat_});
    }
    pub fn specularAlbedoTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "specularAlbedoTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setSpecularAlbedoTextureFormat(self_: *@This(), specularAlbedoTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setSpecularAlbedoTextureFormat:", void, .{specularAlbedoTextureFormat_});
    }
    pub fn normalTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "normalTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setNormalTextureFormat(self_: *@This(), normalTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setNormalTextureFormat:", void, .{normalTextureFormat_});
    }
    pub fn roughnessTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "roughnessTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setRoughnessTextureFormat(self_: *@This(), roughnessTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setRoughnessTextureFormat:", void, .{roughnessTextureFormat_});
    }
    pub fn specularHitDistanceTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "specularHitDistanceTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setSpecularHitDistanceTextureFormat(self_: *@This(), specularHitDistanceTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setSpecularHitDistanceTextureFormat:", void, .{specularHitDistanceTextureFormat_});
    }
    pub fn denoiseStrengthMaskTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "denoiseStrengthMaskTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setDenoiseStrengthMaskTextureFormat(self_: *@This(), denoiseStrengthMaskTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setDenoiseStrengthMaskTextureFormat:", void, .{denoiseStrengthMaskTextureFormat_});
    }
    pub fn transparencyOverlayTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "transparencyOverlayTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setTransparencyOverlayTextureFormat(self_: *@This(), transparencyOverlayTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setTransparencyOverlayTextureFormat:", void, .{transparencyOverlayTextureFormat_});
    }
    pub fn outputTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "outputTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setOutputTextureFormat(self_: *@This(), outputTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setOutputTextureFormat:", void, .{outputTextureFormat_});
    }
    pub fn inputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputWidth", ns.UInteger, .{});
    }
    pub fn setInputWidth(self_: *@This(), inputWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputWidth:", void, .{inputWidth_});
    }
    pub fn inputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputHeight", ns.UInteger, .{});
    }
    pub fn setInputHeight(self_: *@This(), inputHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputHeight:", void, .{inputHeight_});
    }
    pub fn outputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputWidth", ns.UInteger, .{});
    }
    pub fn setOutputWidth(self_: *@This(), outputWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setOutputWidth:", void, .{outputWidth_});
    }
    pub fn outputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputHeight", ns.UInteger, .{});
    }
    pub fn setOutputHeight(self_: *@This(), outputHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setOutputHeight:", void, .{outputHeight_});
    }
    pub fn requiresSynchronousInitialization(self_: *@This()) bool {
        return objc.msgSend(self_, "requiresSynchronousInitialization", bool, .{});
    }
    pub fn setRequiresSynchronousInitialization(self_: *@This(), requiresSynchronousInitialization_: bool) void {
        return objc.msgSend(self_, "setRequiresSynchronousInitialization:", void, .{requiresSynchronousInitialization_});
    }
    pub fn isAutoExposureEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "isAutoExposureEnabled", bool, .{});
    }
    pub fn setAutoExposureEnabled(self_: *@This(), autoExposureEnabled_: bool) void {
        return objc.msgSend(self_, "setAutoExposureEnabled:", void, .{autoExposureEnabled_});
    }
    pub fn isReactiveMaskTextureEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "isReactiveMaskTextureEnabled", bool, .{});
    }
    pub fn setReactiveMaskTextureEnabled(self_: *@This(), reactiveMaskTextureEnabled_: bool) void {
        return objc.msgSend(self_, "setReactiveMaskTextureEnabled:", void, .{reactiveMaskTextureEnabled_});
    }
    pub fn reactiveMaskTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "reactiveMaskTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setReactiveMaskTextureFormat(self_: *@This(), reactiveMaskTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setReactiveMaskTextureFormat:", void, .{reactiveMaskTextureFormat_});
    }
    pub fn isSpecularHitDistanceTextureEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "isSpecularHitDistanceTextureEnabled", bool, .{});
    }
    pub fn setSpecularHitDistanceTextureEnabled(self_: *@This(), specularHitDistanceTextureEnabled_: bool) void {
        return objc.msgSend(self_, "setSpecularHitDistanceTextureEnabled:", void, .{specularHitDistanceTextureEnabled_});
    }
    pub fn isDenoiseStrengthMaskTextureEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "isDenoiseStrengthMaskTextureEnabled", bool, .{});
    }
    pub fn setDenoiseStrengthMaskTextureEnabled(self_: *@This(), denoiseStrengthMaskTextureEnabled_: bool) void {
        return objc.msgSend(self_, "setDenoiseStrengthMaskTextureEnabled:", void, .{denoiseStrengthMaskTextureEnabled_});
    }
    pub fn isTransparencyOverlayTextureEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "isTransparencyOverlayTextureEnabled", bool, .{});
    }
    pub fn setTransparencyOverlayTextureEnabled(self_: *@This(), transparencyOverlayTextureEnabled_: bool) void {
        return objc.msgSend(self_, "setTransparencyOverlayTextureEnabled:", void, .{transparencyOverlayTextureEnabled_});
    }
};

pub const TemporalScalerDescriptor = opaque {
    pub const InternalInfo = objc.ExternClass("MTLFXTemporalScalerDescriptor", @This(), ns.ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    /// Returns +1: the caller owns the result and must release it.
    pub fn newTemporalScalerWithDevice(self_: *@This(), device_: *mtl.Device) ?*TemporalScaler {
        return objc.msgSend(self_, "newTemporalScalerWithDevice:", ?*TemporalScaler, .{device_});
    }
    /// Returns +1: the caller owns the result and must release it.
    pub fn newTemporalScalerWithDevice_compiler(self_: *@This(), device_: *mtl.Device, compiler_: *mtl.MTL4Compiler) ?*MTL4FXTemporalScaler {
        return objc.msgSend(self_, "newTemporalScalerWithDevice:compiler:", ?*MTL4FXTemporalScaler, .{ device_, compiler_ });
    }
    pub fn supportedInputContentMinScaleForDevice(device_: *mtl.Device) f32 {
        return objc.msgSend(@This().InternalInfo.class(), "supportedInputContentMinScaleForDevice:", f32, .{device_});
    }
    pub fn supportedInputContentMaxScaleForDevice(device_: *mtl.Device) f32 {
        return objc.msgSend(@This().InternalInfo.class(), "supportedInputContentMaxScaleForDevice:", f32, .{device_});
    }
    pub fn supportsDevice(device_: *mtl.Device) bool {
        return objc.msgSend(@This().InternalInfo.class(), "supportsDevice:", bool, .{device_});
    }
    pub fn supportsMetal4FX(device_: *mtl.Device) bool {
        return objc.msgSend(@This().InternalInfo.class(), "supportsMetal4FX:", bool, .{device_});
    }
    pub fn colorTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "colorTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setColorTextureFormat(self_: *@This(), colorTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setColorTextureFormat:", void, .{colorTextureFormat_});
    }
    pub fn depthTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "depthTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setDepthTextureFormat(self_: *@This(), depthTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setDepthTextureFormat:", void, .{depthTextureFormat_});
    }
    pub fn motionTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "motionTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setMotionTextureFormat(self_: *@This(), motionTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setMotionTextureFormat:", void, .{motionTextureFormat_});
    }
    pub fn outputTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "outputTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setOutputTextureFormat(self_: *@This(), outputTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setOutputTextureFormat:", void, .{outputTextureFormat_});
    }
    pub fn inputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputWidth", ns.UInteger, .{});
    }
    pub fn setInputWidth(self_: *@This(), inputWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputWidth:", void, .{inputWidth_});
    }
    pub fn inputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputHeight", ns.UInteger, .{});
    }
    pub fn setInputHeight(self_: *@This(), inputHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputHeight:", void, .{inputHeight_});
    }
    pub fn outputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputWidth", ns.UInteger, .{});
    }
    pub fn setOutputWidth(self_: *@This(), outputWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setOutputWidth:", void, .{outputWidth_});
    }
    pub fn outputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputHeight", ns.UInteger, .{});
    }
    pub fn setOutputHeight(self_: *@This(), outputHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setOutputHeight:", void, .{outputHeight_});
    }
    pub fn isAutoExposureEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "isAutoExposureEnabled", bool, .{});
    }
    pub fn setAutoExposureEnabled(self_: *@This(), autoExposureEnabled_: bool) void {
        return objc.msgSend(self_, "setAutoExposureEnabled:", void, .{autoExposureEnabled_});
    }
    pub fn requiresSynchronousInitialization(self_: *@This()) bool {
        return objc.msgSend(self_, "requiresSynchronousInitialization", bool, .{});
    }
    pub fn setRequiresSynchronousInitialization(self_: *@This(), requiresSynchronousInitialization_: bool) void {
        return objc.msgSend(self_, "setRequiresSynchronousInitialization:", void, .{requiresSynchronousInitialization_});
    }
    pub fn isInputContentPropertiesEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "isInputContentPropertiesEnabled", bool, .{});
    }
    pub fn setInputContentPropertiesEnabled(self_: *@This(), inputContentPropertiesEnabled_: bool) void {
        return objc.msgSend(self_, "setInputContentPropertiesEnabled:", void, .{inputContentPropertiesEnabled_});
    }
    pub fn inputContentMinScale(self_: *@This()) f32 {
        return objc.msgSend(self_, "inputContentMinScale", f32, .{});
    }
    pub fn setInputContentMinScale(self_: *@This(), inputContentMinScale_: f32) void {
        return objc.msgSend(self_, "setInputContentMinScale:", void, .{inputContentMinScale_});
    }
    pub fn inputContentMaxScale(self_: *@This()) f32 {
        return objc.msgSend(self_, "inputContentMaxScale", f32, .{});
    }
    pub fn setInputContentMaxScale(self_: *@This(), inputContentMaxScale_: f32) void {
        return objc.msgSend(self_, "setInputContentMaxScale:", void, .{inputContentMaxScale_});
    }
    pub fn isReactiveMaskTextureEnabled(self_: *@This()) bool {
        return objc.msgSend(self_, "isReactiveMaskTextureEnabled", bool, .{});
    }
    pub fn setReactiveMaskTextureEnabled(self_: *@This(), reactiveMaskTextureEnabled_: bool) void {
        return objc.msgSend(self_, "setReactiveMaskTextureEnabled:", void, .{reactiveMaskTextureEnabled_});
    }
    pub fn reactiveMaskTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "reactiveMaskTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn setReactiveMaskTextureFormat(self_: *@This(), reactiveMaskTextureFormat_: mtl.PixelFormat) void {
        return objc.msgSend(self_, "setReactiveMaskTextureFormat:", void, .{reactiveMaskTextureFormat_});
    }
};

pub const FrameInterpolatableScaler = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXFrameInterpolatableScaler", @This(), &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
};

pub const FrameInterpolator = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXFrameInterpolator", @This(), &.{FrameInterpolatorBase});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn encodeToCommandBuffer(self_: *@This(), commandBuffer_: *mtl.CommandBuffer) void {
        return objc.msgSend(self_, "encodeToCommandBuffer:", void, .{commandBuffer_});
    }
};

pub const FrameInterpolatorBase = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXFrameInterpolatorBase", @This(), &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn colorTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "colorTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn outputTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "outputTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn depthTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "depthTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn motionTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "motionTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn uiTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "uiTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn colorTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "colorTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn depthTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "depthTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn motionTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "motionTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn outputTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "outputTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn inputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputWidth", ns.UInteger, .{});
    }
    pub fn inputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputHeight", ns.UInteger, .{});
    }
    pub fn outputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputWidth", ns.UInteger, .{});
    }
    pub fn outputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputHeight", ns.UInteger, .{});
    }
    pub fn uiTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "uiTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn colorTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "colorTexture", ?*mtl.Texture, .{});
    }
    pub fn setColorTexture(self_: *@This(), colorTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setColorTexture:", void, .{colorTexture_});
    }
    pub fn prevColorTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "prevColorTexture", ?*mtl.Texture, .{});
    }
    pub fn setPrevColorTexture(self_: *@This(), prevColorTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setPrevColorTexture:", void, .{prevColorTexture_});
    }
    pub fn depthTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "depthTexture", ?*mtl.Texture, .{});
    }
    pub fn setDepthTexture(self_: *@This(), depthTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setDepthTexture:", void, .{depthTexture_});
    }
    pub fn motionTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "motionTexture", ?*mtl.Texture, .{});
    }
    pub fn setMotionTexture(self_: *@This(), motionTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setMotionTexture:", void, .{motionTexture_});
    }
    pub fn motionVectorScaleX(self_: *@This()) f32 {
        return objc.msgSend(self_, "motionVectorScaleX", f32, .{});
    }
    pub fn setMotionVectorScaleX(self_: *@This(), motionVectorScaleX_: f32) void {
        return objc.msgSend(self_, "setMotionVectorScaleX:", void, .{motionVectorScaleX_});
    }
    pub fn motionVectorScaleY(self_: *@This()) f32 {
        return objc.msgSend(self_, "motionVectorScaleY", f32, .{});
    }
    pub fn setMotionVectorScaleY(self_: *@This(), motionVectorScaleY_: f32) void {
        return objc.msgSend(self_, "setMotionVectorScaleY:", void, .{motionVectorScaleY_});
    }
    pub fn deltaTime(self_: *@This()) f32 {
        return objc.msgSend(self_, "deltaTime", f32, .{});
    }
    pub fn setDeltaTime(self_: *@This(), deltaTime_: f32) void {
        return objc.msgSend(self_, "setDeltaTime:", void, .{deltaTime_});
    }
    pub fn nearPlane(self_: *@This()) f32 {
        return objc.msgSend(self_, "nearPlane", f32, .{});
    }
    pub fn setNearPlane(self_: *@This(), nearPlane_: f32) void {
        return objc.msgSend(self_, "setNearPlane:", void, .{nearPlane_});
    }
    pub fn farPlane(self_: *@This()) f32 {
        return objc.msgSend(self_, "farPlane", f32, .{});
    }
    pub fn setFarPlane(self_: *@This(), farPlane_: f32) void {
        return objc.msgSend(self_, "setFarPlane:", void, .{farPlane_});
    }
    pub fn fieldOfView(self_: *@This()) f32 {
        return objc.msgSend(self_, "fieldOfView", f32, .{});
    }
    pub fn setFieldOfView(self_: *@This(), fieldOfView_: f32) void {
        return objc.msgSend(self_, "setFieldOfView:", void, .{fieldOfView_});
    }
    pub fn aspectRatio(self_: *@This()) f32 {
        return objc.msgSend(self_, "aspectRatio", f32, .{});
    }
    pub fn setAspectRatio(self_: *@This(), aspectRatio_: f32) void {
        return objc.msgSend(self_, "setAspectRatio:", void, .{aspectRatio_});
    }
    pub fn uiTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "uiTexture", ?*mtl.Texture, .{});
    }
    pub fn setUITexture(self_: *@This(), uiTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setUITexture:", void, .{uiTexture_});
    }
    pub fn jitterOffsetX(self_: *@This()) f32 {
        return objc.msgSend(self_, "jitterOffsetX", f32, .{});
    }
    pub fn setJitterOffsetX(self_: *@This(), jitterOffsetX_: f32) void {
        return objc.msgSend(self_, "setJitterOffsetX:", void, .{jitterOffsetX_});
    }
    pub fn jitterOffsetY(self_: *@This()) f32 {
        return objc.msgSend(self_, "jitterOffsetY", f32, .{});
    }
    pub fn setJitterOffsetY(self_: *@This(), jitterOffsetY_: f32) void {
        return objc.msgSend(self_, "setJitterOffsetY:", void, .{jitterOffsetY_});
    }
    pub fn isUITextureComposited(self_: *@This()) bool {
        return objc.msgSend(self_, "isUITextureComposited", bool, .{});
    }
    pub fn setIsUITextureComposited(self_: *@This(), uiTextureComposited_: bool) void {
        return objc.msgSend(self_, "setIsUITextureComposited:", void, .{uiTextureComposited_});
    }
    pub fn shouldResetHistory(self_: *@This()) bool {
        return objc.msgSend(self_, "shouldResetHistory", bool, .{});
    }
    pub fn setShouldResetHistory(self_: *@This(), shouldResetHistory_: bool) void {
        return objc.msgSend(self_, "setShouldResetHistory:", void, .{shouldResetHistory_});
    }
    pub fn outputTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "outputTexture", ?*mtl.Texture, .{});
    }
    pub fn setOutputTexture(self_: *@This(), outputTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setOutputTexture:", void, .{outputTexture_});
    }
    pub fn fence(self_: *@This()) ?*mtl.Fence {
        return objc.msgSend(self_, "fence", ?*mtl.Fence, .{});
    }
    pub fn setFence(self_: *@This(), fence_: ?*mtl.Fence) void {
        return objc.msgSend(self_, "setFence:", void, .{fence_});
    }
    pub fn isDepthReversed(self_: *@This()) bool {
        return objc.msgSend(self_, "isDepthReversed", bool, .{});
    }
    pub fn setDepthReversed(self_: *@This(), depthReversed_: bool) void {
        return objc.msgSend(self_, "setDepthReversed:", void, .{depthReversed_});
    }
};

pub const SpatialScaler = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXSpatialScaler", @This(), &.{SpatialScalerBase});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn encodeToCommandBuffer(self_: *@This(), commandBuffer_: *mtl.CommandBuffer) void {
        return objc.msgSend(self_, "encodeToCommandBuffer:", void, .{commandBuffer_});
    }
};

pub const SpatialScalerBase = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXSpatialScalerBase", @This(), &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn colorTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "colorTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn outputTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "outputTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn inputContentWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputContentWidth", ns.UInteger, .{});
    }
    pub fn setInputContentWidth(self_: *@This(), inputContentWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputContentWidth:", void, .{inputContentWidth_});
    }
    pub fn inputContentHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputContentHeight", ns.UInteger, .{});
    }
    pub fn setInputContentHeight(self_: *@This(), inputContentHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputContentHeight:", void, .{inputContentHeight_});
    }
    pub fn colorTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "colorTexture", ?*mtl.Texture, .{});
    }
    pub fn setColorTexture(self_: *@This(), colorTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setColorTexture:", void, .{colorTexture_});
    }
    pub fn outputTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "outputTexture", ?*mtl.Texture, .{});
    }
    pub fn setOutputTexture(self_: *@This(), outputTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setOutputTexture:", void, .{outputTexture_});
    }
    pub fn colorTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "colorTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn outputTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "outputTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn inputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputWidth", ns.UInteger, .{});
    }
    pub fn inputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputHeight", ns.UInteger, .{});
    }
    pub fn outputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputWidth", ns.UInteger, .{});
    }
    pub fn outputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputHeight", ns.UInteger, .{});
    }
    pub fn colorProcessingMode(self_: *@This()) SpatialScalerColorProcessingMode {
        return objc.msgSend(self_, "colorProcessingMode", SpatialScalerColorProcessingMode, .{});
    }
    pub fn fence(self_: *@This()) ?*mtl.Fence {
        return objc.msgSend(self_, "fence", ?*mtl.Fence, .{});
    }
    pub fn setFence(self_: *@This(), fence_: ?*mtl.Fence) void {
        return objc.msgSend(self_, "setFence:", void, .{fence_});
    }
};

pub const TemporalDenoisedScaler = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXTemporalDenoisedScaler", @This(), &.{TemporalDenoisedScalerBase});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn encodeToCommandBuffer(self_: *@This(), commandBuffer_: *mtl.CommandBuffer) void {
        return objc.msgSend(self_, "encodeToCommandBuffer:", void, .{commandBuffer_});
    }
};

pub const TemporalDenoisedScalerBase = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXTemporalDenoisedScalerBase", @This(), &.{FrameInterpolatableScaler});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn colorTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "colorTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn depthTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "depthTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn motionTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "motionTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn reactiveTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "reactiveTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn diffuseAlbedoTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "diffuseAlbedoTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn specularAlbedoTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "specularAlbedoTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn normalTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "normalTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn roughnessTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "roughnessTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn specularHitDistanceTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "specularHitDistanceTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn denoiseStrengthMaskTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "denoiseStrengthMaskTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn transparencyOverlayTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "transparencyOverlayTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn outputTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "outputTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn colorTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "colorTexture", ?*mtl.Texture, .{});
    }
    pub fn setColorTexture(self_: *@This(), colorTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setColorTexture:", void, .{colorTexture_});
    }
    pub fn depthTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "depthTexture", ?*mtl.Texture, .{});
    }
    pub fn setDepthTexture(self_: *@This(), depthTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setDepthTexture:", void, .{depthTexture_});
    }
    pub fn motionTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "motionTexture", ?*mtl.Texture, .{});
    }
    pub fn setMotionTexture(self_: *@This(), motionTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setMotionTexture:", void, .{motionTexture_});
    }
    pub fn diffuseAlbedoTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "diffuseAlbedoTexture", ?*mtl.Texture, .{});
    }
    pub fn setDiffuseAlbedoTexture(self_: *@This(), diffuseAlbedoTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setDiffuseAlbedoTexture:", void, .{diffuseAlbedoTexture_});
    }
    pub fn specularAlbedoTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "specularAlbedoTexture", ?*mtl.Texture, .{});
    }
    pub fn setSpecularAlbedoTexture(self_: *@This(), specularAlbedoTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setSpecularAlbedoTexture:", void, .{specularAlbedoTexture_});
    }
    pub fn normalTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "normalTexture", ?*mtl.Texture, .{});
    }
    pub fn setNormalTexture(self_: *@This(), normalTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setNormalTexture:", void, .{normalTexture_});
    }
    pub fn roughnessTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "roughnessTexture", ?*mtl.Texture, .{});
    }
    pub fn setRoughnessTexture(self_: *@This(), roughnessTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setRoughnessTexture:", void, .{roughnessTexture_});
    }
    pub fn specularHitDistanceTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "specularHitDistanceTexture", ?*mtl.Texture, .{});
    }
    pub fn setSpecularHitDistanceTexture(self_: *@This(), specularHitDistanceTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setSpecularHitDistanceTexture:", void, .{specularHitDistanceTexture_});
    }
    pub fn denoiseStrengthMaskTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "denoiseStrengthMaskTexture", ?*mtl.Texture, .{});
    }
    pub fn setDenoiseStrengthMaskTexture(self_: *@This(), denoiseStrengthMaskTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setDenoiseStrengthMaskTexture:", void, .{denoiseStrengthMaskTexture_});
    }
    pub fn transparencyOverlayTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "transparencyOverlayTexture", ?*mtl.Texture, .{});
    }
    pub fn setTransparencyOverlayTexture(self_: *@This(), transparencyOverlayTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setTransparencyOverlayTexture:", void, .{transparencyOverlayTexture_});
    }
    pub fn outputTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "outputTexture", ?*mtl.Texture, .{});
    }
    pub fn setOutputTexture(self_: *@This(), outputTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setOutputTexture:", void, .{outputTexture_});
    }
    pub fn exposureTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "exposureTexture", ?*mtl.Texture, .{});
    }
    pub fn setExposureTexture(self_: *@This(), exposureTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setExposureTexture:", void, .{exposureTexture_});
    }
    pub fn preExposure(self_: *@This()) f32 {
        return objc.msgSend(self_, "preExposure", f32, .{});
    }
    pub fn setPreExposure(self_: *@This(), preExposure_: f32) void {
        return objc.msgSend(self_, "setPreExposure:", void, .{preExposure_});
    }
    pub fn reactiveMaskTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "reactiveMaskTexture", ?*mtl.Texture, .{});
    }
    pub fn setReactiveMaskTexture(self_: *@This(), reactiveMaskTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setReactiveMaskTexture:", void, .{reactiveMaskTexture_});
    }
    pub fn jitterOffsetX(self_: *@This()) f32 {
        return objc.msgSend(self_, "jitterOffsetX", f32, .{});
    }
    pub fn setJitterOffsetX(self_: *@This(), jitterOffsetX_: f32) void {
        return objc.msgSend(self_, "setJitterOffsetX:", void, .{jitterOffsetX_});
    }
    pub fn jitterOffsetY(self_: *@This()) f32 {
        return objc.msgSend(self_, "jitterOffsetY", f32, .{});
    }
    pub fn setJitterOffsetY(self_: *@This(), jitterOffsetY_: f32) void {
        return objc.msgSend(self_, "setJitterOffsetY:", void, .{jitterOffsetY_});
    }
    pub fn motionVectorScaleX(self_: *@This()) f32 {
        return objc.msgSend(self_, "motionVectorScaleX", f32, .{});
    }
    pub fn setMotionVectorScaleX(self_: *@This(), motionVectorScaleX_: f32) void {
        return objc.msgSend(self_, "setMotionVectorScaleX:", void, .{motionVectorScaleX_});
    }
    pub fn motionVectorScaleY(self_: *@This()) f32 {
        return objc.msgSend(self_, "motionVectorScaleY", f32, .{});
    }
    pub fn setMotionVectorScaleY(self_: *@This(), motionVectorScaleY_: f32) void {
        return objc.msgSend(self_, "setMotionVectorScaleY:", void, .{motionVectorScaleY_});
    }
    pub fn shouldResetHistory(self_: *@This()) bool {
        return objc.msgSend(self_, "shouldResetHistory", bool, .{});
    }
    pub fn setShouldResetHistory(self_: *@This(), shouldResetHistory_: bool) void {
        return objc.msgSend(self_, "setShouldResetHistory:", void, .{shouldResetHistory_});
    }
    pub fn isDepthReversed(self_: *@This()) bool {
        return objc.msgSend(self_, "isDepthReversed", bool, .{});
    }
    pub fn setDepthReversed(self_: *@This(), depthReversed_: bool) void {
        return objc.msgSend(self_, "setDepthReversed:", void, .{depthReversed_});
    }
    pub fn colorTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "colorTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn depthTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "depthTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn motionTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "motionTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn diffuseAlbedoTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "diffuseAlbedoTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn specularAlbedoTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "specularAlbedoTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn normalTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "normalTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn roughnessTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "roughnessTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn specularHitDistanceTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "specularHitDistanceTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn denoiseStrengthMaskTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "denoiseStrengthMaskTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn transparencyOverlayTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "transparencyOverlayTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn reactiveMaskTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "reactiveMaskTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn outputTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "outputTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn inputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputWidth", ns.UInteger, .{});
    }
    pub fn inputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputHeight", ns.UInteger, .{});
    }
    pub fn outputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputWidth", ns.UInteger, .{});
    }
    pub fn outputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputHeight", ns.UInteger, .{});
    }
    pub fn inputContentMinScale(self_: *@This()) f32 {
        return objc.msgSend(self_, "inputContentMinScale", f32, .{});
    }
    pub fn inputContentMaxScale(self_: *@This()) f32 {
        return objc.msgSend(self_, "inputContentMaxScale", f32, .{});
    }
    pub fn worldToViewMatrix(self_: *@This()) simd_float4x4 {
        return objc.msgSend(self_, "worldToViewMatrix", simd_float4x4, .{});
    }
    pub fn setWorldToViewMatrix(self_: *@This(), worldToViewMatrix_: simd_float4x4) void {
        return objc.msgSend(self_, "setWorldToViewMatrix:", void, .{worldToViewMatrix_});
    }
    pub fn viewToClipMatrix(self_: *@This()) simd_float4x4 {
        return objc.msgSend(self_, "viewToClipMatrix", simd_float4x4, .{});
    }
    pub fn setViewToClipMatrix(self_: *@This(), viewToClipMatrix_: simd_float4x4) void {
        return objc.msgSend(self_, "setViewToClipMatrix:", void, .{viewToClipMatrix_});
    }
    pub fn fence(self_: *@This()) ?*mtl.Fence {
        return objc.msgSend(self_, "fence", ?*mtl.Fence, .{});
    }
    pub fn setFence(self_: *@This(), fence_: ?*mtl.Fence) void {
        return objc.msgSend(self_, "setFence:", void, .{fence_});
    }
};

pub const TemporalScaler = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXTemporalScaler", @This(), &.{TemporalScalerBase});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn encodeToCommandBuffer(self_: *@This(), commandBuffer_: *mtl.CommandBuffer) void {
        return objc.msgSend(self_, "encodeToCommandBuffer:", void, .{commandBuffer_});
    }
};

pub const TemporalScalerBase = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTLFXTemporalScalerBase", @This(), &.{FrameInterpolatableScaler});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn colorTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "colorTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn depthTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "depthTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn motionTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "motionTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn reactiveTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "reactiveTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn outputTextureUsage(self_: *@This()) mtl.TextureUsage {
        return objc.msgSend(self_, "outputTextureUsage", mtl.TextureUsage, .{});
    }
    pub fn inputContentWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputContentWidth", ns.UInteger, .{});
    }
    pub fn setInputContentWidth(self_: *@This(), inputContentWidth_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputContentWidth:", void, .{inputContentWidth_});
    }
    pub fn inputContentHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputContentHeight", ns.UInteger, .{});
    }
    pub fn setInputContentHeight(self_: *@This(), inputContentHeight_: ns.UInteger) void {
        return objc.msgSend(self_, "setInputContentHeight:", void, .{inputContentHeight_});
    }
    pub fn colorTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "colorTexture", ?*mtl.Texture, .{});
    }
    pub fn setColorTexture(self_: *@This(), colorTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setColorTexture:", void, .{colorTexture_});
    }
    pub fn depthTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "depthTexture", ?*mtl.Texture, .{});
    }
    pub fn setDepthTexture(self_: *@This(), depthTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setDepthTexture:", void, .{depthTexture_});
    }
    pub fn motionTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "motionTexture", ?*mtl.Texture, .{});
    }
    pub fn setMotionTexture(self_: *@This(), motionTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setMotionTexture:", void, .{motionTexture_});
    }
    pub fn outputTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "outputTexture", ?*mtl.Texture, .{});
    }
    pub fn setOutputTexture(self_: *@This(), outputTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setOutputTexture:", void, .{outputTexture_});
    }
    pub fn exposureTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "exposureTexture", ?*mtl.Texture, .{});
    }
    pub fn setExposureTexture(self_: *@This(), exposureTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setExposureTexture:", void, .{exposureTexture_});
    }
    pub fn reactiveMaskTexture(self_: *@This()) ?*mtl.Texture {
        return objc.msgSend(self_, "reactiveMaskTexture", ?*mtl.Texture, .{});
    }
    pub fn setReactiveMaskTexture(self_: *@This(), reactiveMaskTexture_: ?*mtl.Texture) void {
        return objc.msgSend(self_, "setReactiveMaskTexture:", void, .{reactiveMaskTexture_});
    }
    pub fn preExposure(self_: *@This()) f32 {
        return objc.msgSend(self_, "preExposure", f32, .{});
    }
    pub fn setPreExposure(self_: *@This(), preExposure_: f32) void {
        return objc.msgSend(self_, "setPreExposure:", void, .{preExposure_});
    }
    pub fn jitterOffsetX(self_: *@This()) f32 {
        return objc.msgSend(self_, "jitterOffsetX", f32, .{});
    }
    pub fn setJitterOffsetX(self_: *@This(), jitterOffsetX_: f32) void {
        return objc.msgSend(self_, "setJitterOffsetX:", void, .{jitterOffsetX_});
    }
    pub fn jitterOffsetY(self_: *@This()) f32 {
        return objc.msgSend(self_, "jitterOffsetY", f32, .{});
    }
    pub fn setJitterOffsetY(self_: *@This(), jitterOffsetY_: f32) void {
        return objc.msgSend(self_, "setJitterOffsetY:", void, .{jitterOffsetY_});
    }
    pub fn motionVectorScaleX(self_: *@This()) f32 {
        return objc.msgSend(self_, "motionVectorScaleX", f32, .{});
    }
    pub fn setMotionVectorScaleX(self_: *@This(), motionVectorScaleX_: f32) void {
        return objc.msgSend(self_, "setMotionVectorScaleX:", void, .{motionVectorScaleX_});
    }
    pub fn motionVectorScaleY(self_: *@This()) f32 {
        return objc.msgSend(self_, "motionVectorScaleY", f32, .{});
    }
    pub fn setMotionVectorScaleY(self_: *@This(), motionVectorScaleY_: f32) void {
        return objc.msgSend(self_, "setMotionVectorScaleY:", void, .{motionVectorScaleY_});
    }
    pub fn reset(self_: *@This()) bool {
        return objc.msgSend(self_, "reset", bool, .{});
    }
    pub fn setReset(self_: *@This(), reset_: bool) void {
        return objc.msgSend(self_, "setReset:", void, .{reset_});
    }
    pub fn isDepthReversed(self_: *@This()) bool {
        return objc.msgSend(self_, "isDepthReversed", bool, .{});
    }
    pub fn setDepthReversed(self_: *@This(), depthReversed_: bool) void {
        return objc.msgSend(self_, "setDepthReversed:", void, .{depthReversed_});
    }
    pub fn colorTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "colorTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn depthTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "depthTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn motionTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "motionTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn reactiveMaskTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "reactiveMaskTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn outputTextureFormat(self_: *@This()) mtl.PixelFormat {
        return objc.msgSend(self_, "outputTextureFormat", mtl.PixelFormat, .{});
    }
    pub fn inputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputWidth", ns.UInteger, .{});
    }
    pub fn inputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "inputHeight", ns.UInteger, .{});
    }
    pub fn outputWidth(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputWidth", ns.UInteger, .{});
    }
    pub fn outputHeight(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "outputHeight", ns.UInteger, .{});
    }
    pub fn inputContentMinScale(self_: *@This()) f32 {
        return objc.msgSend(self_, "inputContentMinScale", f32, .{});
    }
    pub fn inputContentMaxScale(self_: *@This()) f32 {
        return objc.msgSend(self_, "inputContentMaxScale", f32, .{});
    }
    pub fn fence(self_: *@This()) ?*mtl.Fence {
        return objc.msgSend(self_, "fence", ?*mtl.Fence, .{});
    }
    pub fn setFence(self_: *@This(), fence_: ?*mtl.Fence) void {
        return objc.msgSend(self_, "setFence:", void, .{fence_});
    }
};

pub const MTL4FXFrameInterpolator = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTL4FXFrameInterpolator", @This(), &.{FrameInterpolatorBase});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn encodeToCommandBuffer(self_: *@This(), commandBuffer_: *mtl.MTL4CommandBuffer) void {
        return objc.msgSend(self_, "encodeToCommandBuffer:", void, .{commandBuffer_});
    }
};

pub const MTL4FXSpatialScaler = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTL4FXSpatialScaler", @This(), &.{SpatialScalerBase});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn encodeToCommandBuffer(self_: *@This(), commandBuffer_: *mtl.MTL4CommandBuffer) void {
        return objc.msgSend(self_, "encodeToCommandBuffer:", void, .{commandBuffer_});
    }
};

pub const MTL4FXTemporalDenoisedScaler = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTL4FXTemporalDenoisedScaler", @This(), &.{TemporalDenoisedScalerBase});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn encodeToCommandBuffer(self_: *@This(), commandBuffer_: *mtl.MTL4CommandBuffer) void {
        return objc.msgSend(self_, "encodeToCommandBuffer:", void, .{commandBuffer_});
    }
};

pub const MTL4FXTemporalScaler = opaque {
    pub const InternalInfo = objc.ExternProtocol("MTL4FXTemporalScaler", @This(), &.{TemporalScalerBase});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn encodeToCommandBuffer(self_: *@This(), commandBuffer_: *mtl.MTL4CommandBuffer) void {
        return objc.msgSend(self_, "encodeToCommandBuffer:", void, .{commandBuffer_});
    }
};
