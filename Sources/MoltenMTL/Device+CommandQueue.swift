internal import CVulkan

public extension MTLDevice {

    /// Creates a new command queue for submitting work to this device.
    /// - Returns: A new `MTLCommandQueue`, or `nil` if the underlying Vulkan command pool could not be created.
    func makeCommandQueue() -> MTLCommandQueue? {
        guard let vkDev = device, let q = queue else { return nil }

        var poolCI = VkCommandPoolCreateInfo()
        poolCI.sType            = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
        poolCI.queueFamilyIndex = computeQueueFamily
        poolCI.flags            = UInt32(bitPattern: VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT.rawValue)

        var pool: VkCommandPool?
        guard vkCreateCommandPool(vkDev, &poolCI, nil, &pool) == VK_SUCCESS,
              let pool else {
            print("[MoltenMTL] vkCreateCommandPool failed")
            return nil
        }

        return MTLCommandQueue(queue: q, commandPool: pool, vkDevice: vkDev, device: self)
    }
}
