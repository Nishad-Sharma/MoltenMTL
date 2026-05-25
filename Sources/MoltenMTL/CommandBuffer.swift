import CVulkan

// MARK: - CommandBuffer

/// Mirrors MTLCommandBuffer.
/// Create via `commandQueue.makeCommandBuffer()` — never instantiate directly.
public final class MTLCommandBuffer {

    // MARK: Public properties

    /// Mirrors `MTLCommandBuffer.label` — used by GPU debuggers.
    public var label: String?

    // MARK: Public handles

    /// Raw VkCommandBuffer — available to command encoders for recording.
    public let handle: VkCommandBuffer

    // MARK: Private

    /// Strong reference keeps the CommandQueue (and its pool) alive
    /// for as long as this buffer exists.
    /// Internal (not private) so ComputeCommandEncoder can access vkDevice/queue.
    let commandQueue: MTLCommandQueue

    /// Fence signaled by `commit()`, waited on by `waitUntilCompleted()`.
    private var fence: VkFence?

    /// Descriptor pools created by `ComputeCommandEncoder` during encoding.
    /// Owned here so they outlive the encoder and are freed after GPU completion.
    var ownedPools: [VkDescriptorPool?] = []

    /// Buffers transferred from the encoder at `endEncoding()` so their `VkBuffer`
    /// handles remain valid until after `vkEndCommandBuffer` (and GPU completion).
    /// Mirrors Metal's implicit resource retention during command encoding.
    var ownedBuffers: [MTLBuffer] = []

    /// Acceleration structures retained from the encoder until GPU completion.
    var ownedAccelerationStructures: [MTLAccelerationStructure] = []

    /// Textures retained from the encoder until GPU completion.
    var ownedTextures: [MTLTexture] = []

    /// Set by `present(_:)`. When non-nil, commit() submits with semaphores + presents.
    private var pendingDrawable: CAMetalDrawable?

    // MARK: Init / deinit

    init(handle: VkCommandBuffer, commandQueue: MTLCommandQueue) {
        self.handle       = handle
        self.commandQueue = commandQueue
    }

    deinit {
        guard let dev  = commandQueue.vkDevice,
              let pool = commandQueue.commandPool else { return }

        // If committed but waitUntilCompleted() was never called, stall now
        // so we don't free a command buffer the GPU is still reading.
        // Keep fCopy as VkFence? — vkWaitForFences expects UnsafePointer<VkFence?>.
        var fCopy: VkFence? = fence
        if fCopy != nil {
            vkWaitForFences(dev, 1, &fCopy, 1 /* VK_TRUE */, UInt64.max)
            vkDestroyFence(dev, fCopy, nil)
        }

        // Return the command buffer to the pool.
        var h: VkCommandBuffer? = handle
        vkFreeCommandBuffers(dev, pool, 1, &h)

        // Destroy descriptor pools accumulated during encoding.
        for p in ownedPools { vkDestroyDescriptorPool(dev, p, nil) }
    }

    // MARK: - commit

    /// Mirrors `MTLCommandBuffer.commit()`.
    ///
    /// Ends recording and submits the buffer to the GPU queue.
    /// If `present(_:)` was called, submission uses semaphore sync and
    /// `vkQueuePresentKHR` is called automatically.
    /// Call `waitUntilCompleted()` afterward to block until the GPU finishes.
    public func commit() {
        guard let dev   = commandQueue.vkDevice,
              let queue = commandQueue.queue else { return }

        // ── End recording ──────────────────────────────────────────────────────
        guard vkEndCommandBuffer(handle) == VK_SUCCESS else {
            print("[VulkanSwift] vkEndCommandBuffer failed")
            return
        }

        // ── Create fence (unsignaled) ──────────────────────────────────────────
        var fenceCI = VkFenceCreateInfo()
        fenceCI.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
        var f: VkFence?
        guard vkCreateFence(dev, &fenceCI, nil, &f) == VK_SUCCESS else {
            print("[VulkanSwift] vkCreateFence failed")
            return
        }
        self.fence = f

        // ── Submit (+ present if a drawable was registered) ────────────────────
        if let drawable = pendingDrawable {
            // Semaphore-aware submit + vkQueuePresentKHR in one call.
            let result = CVKS_submitAndPresent(
                queue, handle,
                drawable.imageAvailableSemaphore,
                drawable.renderFinishedSemaphore,
                f!,
                drawable.swapchainHandle,
                drawable.imageIndex)
            if result != VK_SUCCESS && result.rawValue != 1000001003 /* VK_SUBOPTIMAL_KHR */ {
                print("[VulkanSwift] CVKS_submitAndPresent failed (VkResult \(result.rawValue))")
            }
        } else {
            // Plain submit — no present needed.
            var h: VkCommandBuffer? = handle
            withUnsafePointer(to: &h) { cmdPtr in
                var submitInfo = VkSubmitInfo()
                submitInfo.sType              = VK_STRUCTURE_TYPE_SUBMIT_INFO
                submitInfo.commandBufferCount = 1
                submitInfo.pCommandBuffers    = cmdPtr
                if vkQueueSubmit(queue, 1, &submitInfo, f) != VK_SUCCESS {
                    print("[VulkanSwift] vkQueueSubmit failed")
                }
            }
        }
    }

    // MARK: - present

    /// Mirrors `MTLCommandBuffer.present(_:)`.
    ///
    /// Schedules the swapchain image for presentation after `commit()`.
    /// Must be called before `commit()`.
    public func present(_ drawable: CAMetalDrawable) {
        pendingDrawable = drawable
    }

    // MARK: - makeBlitCommandEncoder

    /// Mirrors `MTLCommandBuffer.makeBlitCommandEncoder()`.
    public func makeBlitCommandEncoder() -> MTLBlitCommandEncoder? {
        MTLBlitCommandEncoder(commandBuffer: self)
    }

    // MARK: - makeComputeCommandEncoder

    /// Mirrors `MTLCommandBuffer.makeComputeCommandEncoder()`.
    ///
    /// Returns an encoder that records compute commands into this buffer.
    /// Call `endEncoding()` on the encoder before creating another or calling `commit()`.
    public func makeComputeCommandEncoder() -> MTLComputeCommandEncoder? {
        MTLComputeCommandEncoder(commandBuffer: self)
    }

    // MARK: - makeAccelerationStructureCommandEncoder

    /// Mirrors `MTLCommandBuffer.makeAccelerationStructureCommandEncoder()`.
    ///
    /// Returns an encoder that records acceleration structure build commands.
    /// Call `endEncoding()` before calling `commit()`.
    public func makeAccelerationStructureCommandEncoder()
        -> MTLAccelerationStructureCommandEncoder?
    {
        MTLAccelerationStructureCommandEncoder(
            commandBuffer: handle,
            device:        commandQueue.device)
    }

    // MARK: - waitUntilCompleted

    /// Mirrors `MTLCommandBuffer.waitUntilCompleted()`.
    ///
    /// Blocks the CPU until the GPU finishes executing this command buffer.
    /// Must be called after `commit()`.
    public func waitUntilCompleted() {
        guard let dev = commandQueue.vkDevice, fence != nil else { return }
        var fCopy: VkFence? = fence
        vkWaitForFences(dev, 1, &fCopy, 1 /* VK_TRUE */, UInt64.max)
        vkDestroyFence(dev, fCopy, nil)
        self.fence = nil
    }
}
