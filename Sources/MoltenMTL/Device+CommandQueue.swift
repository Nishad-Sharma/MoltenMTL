import CVulkan

public extension MTLDevice {

    // MARK: - makeCommandQueue

    /// Mirrors `MTLDevice.makeCommandQueue()`.
    ///
    /// Creates a `VkCommandPool` tied to the compute queue family and returns
    /// a `CommandQueue` that allocates command buffers from it.
    func makeCommandQueue() -> MTLCommandQueue? {
        guard let vkDev = device, let q = queue else { return nil }

        // RESET_COMMAND_BUFFER_BIT lets individual command buffers be reset
        // independently of one another (not strictly required here, but good practice).
        var poolCI = VkCommandPoolCreateInfo()
        poolCI.sType            = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
        poolCI.queueFamilyIndex = computeQueueFamily
        poolCI.flags            = UInt32(bitPattern: VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT.rawValue)

        var pool: VkCommandPool?
        guard vkCreateCommandPool(vkDev, &poolCI, nil, &pool) == VK_SUCCESS,
              let pool else {
            print("[VulkanSwift] vkCreateCommandPool failed")
            return nil
        }

        return MTLCommandQueue(queue: q, commandPool: pool, vkDevice: vkDev, device: self)
    }
}
