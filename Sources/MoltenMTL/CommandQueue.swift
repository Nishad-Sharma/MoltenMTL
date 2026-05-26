import CVulkan


/// Create via `device.makeCommandQueue()` - never instantiate directly.
public final class MTLCommandQueue {


    /// Borrowed from `MTLDevice` - not owned by this queue.
    let queue: VkQueue?
    let commandPool: VkCommandPool?
    let vkDevice: VkDevice?

    /// Internal so encoders can access the device through the queue.
    let device: MTLDevice


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

    /// Allocates a primary `VkCommandBuffer` and immediately begins recording (ONE_TIME_SUBMIT).
    public func makeCommandBuffer() -> MTLCommandBuffer? {
        guard let dev = vkDevice, let pool = commandPool else { return nil }

        // Allocate
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

        // Begin recording
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
