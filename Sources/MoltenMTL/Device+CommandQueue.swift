import CVulkan

public extension MTLDevice {

    func makeCommandQueue() -> MTLCommandQueue? {
        guard let vkDev = device, let q = queue else { return nil }

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
