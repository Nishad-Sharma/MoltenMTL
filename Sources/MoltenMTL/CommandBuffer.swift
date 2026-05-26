import CVulkan

public final class MTLCommandBuffer {

    public var label: String?

    public let handle: VkCommandBuffer

    /// Internal (not private) so encoders can access vkDevice/queue via the queue.
    let commandQueue: MTLCommandQueue

    private var fence: VkFence?

    /// Descriptor pools created by `ComputeCommandEncoder` during encoding.
    /// Owned here so they outlive the encoder and are freed after GPU completion.
    var ownedPools: [VkDescriptorPool?] = []

    /// Buffers transferred from the encoder at `endEncoding()` so their `VkBuffer`
    /// handles remain valid through GPU completion.
    var ownedBuffers: [MTLBuffer] = []

    /// Acceleration structures retained from the encoder until GPU completion.
    var ownedAccelerationStructures: [MTLAccelerationStructure] = []

    /// Textures retained from the encoder until GPU completion.
    var ownedTextures: [MTLTexture] = []

    /// Set by `present(_:)`. When non-nil, commit() submits with semaphores + presents.
    private var pendingDrawable: CAMetalDrawable?

    init(handle: VkCommandBuffer, commandQueue: MTLCommandQueue) {
        self.handle       = handle
        self.commandQueue = commandQueue
    }

    deinit {
        guard let dev  = commandQueue.vkDevice,
              let pool = commandQueue.commandPool else { return }

        // If waitUntilCompleted() was never called, stall now so we don't free
        // a command buffer the GPU is still reading.
        var fCopy: VkFence? = fence
        if fCopy != nil {
            vkWaitForFences(dev, 1, &fCopy, 1 /* VK_TRUE */, UInt64.max)
            vkDestroyFence(dev, fCopy, nil)
        }

        var h: VkCommandBuffer? = handle
        vkFreeCommandBuffers(dev, pool, 1, &h)

        for p in ownedPools { vkDestroyDescriptorPool(dev, p, nil) }
    }

    /// Ends recording and submits to the GPU queue.
    /// If `present(_:)` was called beforehand, submission uses semaphore sync and presents automatically.
    public func commit() {
        guard let dev   = commandQueue.vkDevice,
              let queue = commandQueue.queue else { return }

        // End recording
        guard vkEndCommandBuffer(handle) == VK_SUCCESS else {
            print("[VulkanSwift] vkEndCommandBuffer failed")
            return
        }

        // Create fence (unsignaled)
        var fenceCI = VkFenceCreateInfo()
        fenceCI.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
        var f: VkFence?
        guard vkCreateFence(dev, &fenceCI, nil, &f) == VK_SUCCESS else {
            print("[VulkanSwift] vkCreateFence failed")
            return
        }
        self.fence = f

        // Submit (+ present if a drawable was registered)
        if let drawable = pendingDrawable {
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

    public func present(_ drawable: CAMetalDrawable) {
        pendingDrawable = drawable
    }

    public func makeBlitCommandEncoder() -> MTLBlitCommandEncoder? {
        MTLBlitCommandEncoder(commandBuffer: self)
    }

    /// Call `endEncoding()` on the encoder before creating another or calling `commit()`.
    public func makeComputeCommandEncoder() -> MTLComputeCommandEncoder? {
        MTLComputeCommandEncoder(commandBuffer: self)
    }

    /// Call `endEncoding()` before calling `commit()`.
    public func makeAccelerationStructureCommandEncoder()
        -> MTLAccelerationStructureCommandEncoder?
    {
        MTLAccelerationStructureCommandEncoder(
            commandBuffer: handle,
            device:        commandQueue.device)
    }

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
