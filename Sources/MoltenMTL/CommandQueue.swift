import CVulkan

// MARK: - CommandQueue

/// Mirrors MTLCommandQueue.
/// Create via `device.makeCommandQueue()` — never instantiate directly.
public final class MTLCommandQueue {

    // MARK: Internal Vulkan handles

    /// The VkQueue used for submission — borrowed from Device, not owned.
    let queue: VkQueue?

    /// Pool from which command buffers are allocated.
    let commandPool: VkCommandPool?

    /// Raw logical device handle — used by CommandBuffer for Vulkan calls.
    let vkDevice: VkDevice?

    /// Strong reference to the parent Device.
    /// Ensures `vkDestroyDevice` is not called while the pool is still alive.
    /// Internal so CommandBuffer can pass it to encoders that need Device access.
    let device: MTLDevice

    // MARK: Init / deinit

    init(queue: VkQueue?, commandPool: VkCommandPool?, vkDevice: VkDevice?, device: MTLDevice) {
        self.queue       = queue
        self.commandPool = commandPool
        self.vkDevice    = vkDevice
        self.device      = device
    }

    deinit {
        // Destroying the pool implicitly frees every command buffer allocated from it.
        if let dev = vkDevice, let pool = commandPool {
            vkDestroyCommandPool(dev, pool, nil)
        }
    }

    // MARK: - makeCommandBuffer

    /// Mirrors `MTLCommandQueue.makeCommandBuffer()`.
    ///
    /// Allocates a primary `VkCommandBuffer` from the pool and immediately
    /// begins recording (ONE_TIME_SUBMIT semantics — same as a fresh MTLCommandBuffer).
    public func makeCommandBuffer() -> MTLCommandBuffer? {
        guard let dev = vkDevice, let pool = commandPool else { return nil }

        // ── Allocate ───────────────────────────────────────────────────────────
        var allocInfo = VkCommandBufferAllocateInfo()
        allocInfo.sType              = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
        allocInfo.commandPool        = pool
        allocInfo.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY
        allocInfo.commandBufferCount = 1

        var cmdBuf: VkCommandBuffer?
        guard vkAllocateCommandBuffers(dev, &allocInfo, &cmdBuf) == VK_SUCCESS,
              let cmdBuf else {
            print("[VulkanSwift] vkAllocateCommandBuffers failed")
            return nil
        }

        // ── Begin recording ────────────────────────────────────────────────────
        var beginInfo = VkCommandBufferBeginInfo()
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
        beginInfo.flags = UInt32(bitPattern: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.rawValue)

        guard vkBeginCommandBuffer(cmdBuf, &beginInfo) == VK_SUCCESS else {
            print("[VulkanSwift] vkBeginCommandBuffer failed")
            var h: VkCommandBuffer? = cmdBuf
            vkFreeCommandBuffers(dev, pool, 1, &h)
            return nil
        }

        return MTLCommandBuffer(handle: cmdBuf, commandQueue: self)
    }
}
