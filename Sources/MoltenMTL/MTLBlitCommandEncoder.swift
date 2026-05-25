import CVulkan

/// Mirrors `MTLBlitCommandEncoder` — records image/buffer copy commands.
/// Obtain via `commandBuffer.makeBlitCommandEncoder()`.
public final class MTLBlitCommandEncoder {

    /// Mirrors `MTLBlitCommandEncoder.label` — used by GPU debuggers.
    public var label: String?

    private let commandBuffer: MTLCommandBuffer

    init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
    }

    // MARK: - copyBuffer(_:toImage:width:height:)

    /// Copy `src` (u8 RGBA/BGRA, tightly packed) into a swapchain image.
    ///
    /// Records the necessary image-layout transitions automatically:
    ///   UNDEFINED → TRANSFER_DST_OPTIMAL → PRESENT_SRC_KHR
    ///
    /// - Parameters:
    ///   - src:     A shared/staging `MTLBuffer` holding u8 pixel data.
    ///   - toImage: The destination `MTLTexture` (typically `CAMetalDrawable.texture`).
    ///   - width:   Image width in pixels.
    ///   - height:  Image height in pixels.
    public func copyBuffer(_ src: MTLBuffer,
                           toImage image: MTLTexture,
                           width: Int, height: Int) {
        guard let buf = src.handle,
              let vkImage = image.image else { return }
        CVKS_cmdCopyBufferToImage(commandBuffer.handle,
                                   buf, vkImage,
                                   UInt32(width), UInt32(height))
    }

    // MARK: - copy(from:sourceSlice:sourceLevel:sourceOrigin:sourceSize:to:destinationSlice:destinationLevel:destinationOrigin:)

    /// Mirrors `MTLBlitCommandEncoder.copy(from:sourceSlice:sourceLevel:sourceOrigin:sourceSize:to:destinationSlice:destinationLevel:destinationOrigin:)`.
    ///
    /// Copies a region of `source` into `destination` using `vkCmdBlitImage`.
    /// Performs the required layout transitions:
    ///   - source:      current layout → `TRANSFER_SRC_OPTIMAL` → restored
    ///   - destination: `UNDEFINED`    → `TRANSFER_DST_OPTIMAL` → `PRESENT_SRC_KHR`
    ///
    /// For destination textures that are not swapchain images (e.g. intermediate render
    /// targets), the final layout used is `SHADER_READ_ONLY_OPTIMAL`.
    public func copy(from source: MTLTexture,
                     sourceSlice: Int,
                     sourceLevel: Int,
                     sourceOrigin: MTLOrigin,
                     sourceSize: MTLSize,
                     to destination: MTLTexture,
                     destinationSlice: Int,
                     destinationLevel: Int,
                     destinationOrigin: MTLOrigin) {
        guard let srcImage  = source.image,
              let dstImage  = destination.image else { return }

        let cmd = commandBuffer.handle

        // ── Transition source → TRANSFER_SRC_OPTIMAL ──────────────────────────
        // Assume source was last written by a compute shader (GENERAL or SHADER_READ_ONLY).
        let srcOldLayout: VkImageLayout = source.usage.contains(.shaderWrite)
            ? VK_IMAGE_LAYOUT_GENERAL
            : VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        imageBarrier(cmd:       cmd,
                     image:     srcImage,
                     oldLayout: srcOldLayout,
                     newLayout: VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                     srcAccess: UInt32(bitPattern: VK_ACCESS_SHADER_WRITE_BIT.rawValue),
                     dstAccess: UInt32(bitPattern: VK_ACCESS_TRANSFER_READ_BIT.rawValue),
                     srcStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT.rawValue),
                     dstStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                     aspectMask: source.pixelFormat.aspectMask)

        // ── Transition destination → TRANSFER_DST_OPTIMAL ─────────────────────
        imageBarrier(cmd:       cmd,
                     image:     dstImage,
                     oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
                     newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     srcAccess: 0,
                     dstAccess: UInt32(bitPattern: VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                     srcStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT.rawValue),
                     dstStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                     aspectMask: destination.pixelFormat.aspectMask)

        // ── vkCmdBlitImage ─────────────────────────────────────────────────────
        var region = VkImageBlit()
        region.srcSubresource.aspectMask     = source.pixelFormat.aspectMask
        region.srcSubresource.mipLevel       = UInt32(sourceLevel)
        region.srcSubresource.baseArrayLayer = UInt32(sourceSlice)
        region.srcSubresource.layerCount     = 1
        region.srcOffsets.0.x = Int32(sourceOrigin.x)
        region.srcOffsets.0.y = Int32(sourceOrigin.y)
        region.srcOffsets.0.z = Int32(sourceOrigin.z)
        region.srcOffsets.1.x = Int32(sourceOrigin.x + sourceSize.width)
        region.srcOffsets.1.y = Int32(sourceOrigin.y + sourceSize.height)
        region.srcOffsets.1.z = Int32(sourceOrigin.z + sourceSize.depth)

        region.dstSubresource.aspectMask     = destination.pixelFormat.aspectMask
        region.dstSubresource.mipLevel       = UInt32(destinationLevel)
        region.dstSubresource.baseArrayLayer = UInt32(destinationSlice)
        region.dstSubresource.layerCount     = 1
        region.dstOffsets.0.x = Int32(destinationOrigin.x)
        region.dstOffsets.0.y = Int32(destinationOrigin.y)
        region.dstOffsets.0.z = Int32(destinationOrigin.z)
        region.dstOffsets.1.x = Int32(destinationOrigin.x + sourceSize.width)
        region.dstOffsets.1.y = Int32(destinationOrigin.y + sourceSize.height)
        region.dstOffsets.1.z = Int32(destinationOrigin.z + sourceSize.depth)

        withUnsafePointer(to: region) { regionPtr in
            vkCmdBlitImage(cmd,
                           srcImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                           dstImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                           1, regionPtr,
                           VK_FILTER_LINEAR)
        }

        // ── Restore source layout ──────────────────────────────────────────────
        imageBarrier(cmd:       cmd,
                     image:     srcImage,
                     oldLayout: VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                     newLayout: srcOldLayout,
                     srcAccess: UInt32(bitPattern: VK_ACCESS_TRANSFER_READ_BIT.rawValue),
                     dstAccess: UInt32(bitPattern: VK_ACCESS_SHADER_READ_BIT.rawValue),
                     srcStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                     dstStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT.rawValue),
                     aspectMask: source.pixelFormat.aspectMask)

        // ── Transition destination to its final layout ─────────────────────────
        // Swapchain images go to PRESENT_SRC; all others to SHADER_READ_ONLY.
        let dstFinalLayout: VkImageLayout = destination.usage.contains(.renderTarget)
            ? VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
            : VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        imageBarrier(cmd:       cmd,
                     image:     dstImage,
                     oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     newLayout: dstFinalLayout,
                     srcAccess: UInt32(bitPattern: VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                     dstAccess: 0,
                     srcStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                     dstStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT.rawValue),
                     aspectMask: destination.pixelFormat.aspectMask)
    }

    // MARK: - copy(from:MTLBuffer, ...)

    /// Mirrors `MTLBlitCommandEncoder.copy(from:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:to:destinationSlice:destinationLevel:destinationOrigin:)`.
    ///
    /// Copies pixel data from a (shared/staging) `MTLBuffer` into a mip level of `texture`.
    ///
    /// Metal has no image-layout concept — textures are always accessible from any stage.
    /// In Vulkan every image must be in the correct `VkImageLayout` before use, so this
    /// method records two barriers around the copy:
    ///   UNDEFINED → TRANSFER_DST_OPTIMAL  (allow the copy)
    ///   TRANSFER_DST_OPTIMAL → SHADER_READ_ONLY_OPTIMAL  (make it shader-readable)
    public func copy(from buffer: MTLBuffer,
                     sourceOffset: Int,
                     sourceBytesPerRow: Int,
                     sourceBytesPerImage: Int,
                     sourceSize: MTLSize,
                     to texture: MTLTexture,
                     destinationSlice: Int,
                     destinationLevel: Int,
                     destinationOrigin: MTLOrigin) {
        guard let buf = buffer.handle, let img = texture.image else { return }
        let cmd = commandBuffer.handle

        imageBarrier(cmd:       cmd,
                     image:     img,
                     oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
                     newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     srcAccess: 0,
                     dstAccess: UInt32(bitPattern: VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                     srcStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT.rawValue),
                     dstStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                     aspectMask: texture.pixelFormat.aspectMask)

        var region = VkBufferImageCopy()
        region.bufferOffset                    = VkDeviceSize(sourceOffset)
        region.bufferRowLength                 = UInt32(sourceBytesPerRow / max(texture.pixelFormat.bytesPerPixel, 1))
        region.bufferImageHeight               = 0
        region.imageSubresource.aspectMask     = texture.pixelFormat.aspectMask
        region.imageSubresource.mipLevel       = UInt32(destinationLevel)
        region.imageSubresource.baseArrayLayer = UInt32(destinationSlice)
        region.imageSubresource.layerCount     = 1
        region.imageOffset.x                   = Int32(destinationOrigin.x)
        region.imageOffset.y                   = Int32(destinationOrigin.y)
        region.imageOffset.z                   = Int32(destinationOrigin.z)
        region.imageExtent.width               = UInt32(sourceSize.width)
        region.imageExtent.height              = UInt32(sourceSize.height)
        region.imageExtent.depth               = UInt32(max(sourceSize.depth, 1))

        withUnsafePointer(to: region) { regionPtr in
            vkCmdCopyBufferToImage(cmd, buf, img,
                                   VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, regionPtr)
        }

        imageBarrier(cmd:       cmd,
                     image:     img,
                     oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                     srcAccess: UInt32(bitPattern: VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                     dstAccess: UInt32(bitPattern: VK_ACCESS_SHADER_READ_BIT.rawValue),
                     srcStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                     dstStage:  UInt32(bitPattern: VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT.rawValue),
                     aspectMask: texture.pixelFormat.aspectMask)
    }

    // MARK: - copy(from:MTLTexture, sliceCount:levelCount:) — stub

    /// Texture-to-texture copy used by the legacy `blitUpload` path.
    /// Not called in the active `blitBufferToTexture` path; stub for compilation parity.
    public func copy(from source: MTLTexture,
                     sourceSlice: Int, sourceLevel: Int,
                     to destination: MTLTexture,
                     destinationSlice: Int, destinationLevel: Int,
                     sliceCount: Int, levelCount: Int) {
        // TODO: implement full texture→texture copy if blitUpload path is ever needed
    }

    // MARK: - generateMipmaps — stub

    /// Mirrors `MTLBlitCommandEncoder.generateMipmaps(for:)`.
    ///
    /// Metal issues one GPU command; the driver adds barriers between mip levels.
    /// Vulkan requires N−1 `vkCmdBlitImage` calls plus an explicit barrier per level —
    /// stubbed for now; textures will work without mipmaps.
    public func generateMipmaps(for texture: MTLTexture) {
        // TODO: implement per-level vkCmdBlitImage loop with barriers
    }

    // MARK: - endEncoding

    public func endEncoding() {
        // Nothing to flush — commands are recorded directly into the command buffer.
    }
}
