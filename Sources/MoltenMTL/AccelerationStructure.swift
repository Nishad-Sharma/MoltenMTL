internal import CVulkan

/// An opaque GPU acceleration structure.
/// Create via `device.makeAccelerationStructure(size:)`.
public final class MTLAccelerationStructure {

    public var label: String?

    /// The byte size of this acceleration structure's backing buffer, as returned by
    /// `device.accelerationStructureSizes(descriptor:).accelerationStructureSize`.
    public let size: Int

    let handle: VkAccelerationStructureKHR?
    let buffer:     VkBuffer?
    let allocation: VmaAllocation?

    /// GPU device address - used when referencing this BLAS from a TLAS instance buffer.
    let deviceAddress: VkDeviceAddress

    /// Strong reference keeps the Device (and its allocator) alive.
    private let device: MTLDevice

    init(size:          Int,
         handle:        VkAccelerationStructureKHR?,
         buffer:        VkBuffer?,
         allocation:    VmaAllocation?,
         deviceAddress: VkDeviceAddress,
         device:        MTLDevice) {
        self.size          = size
        self.handle        = handle
        self.buffer        = buffer
        self.allocation    = allocation
        self.deviceAddress = deviceAddress
        self.device        = device
    }

    deinit {
        guard let vkDev = device.device else { return }
        // Destroy the VkAccelerationStructureKHR first, then the backing buffer.
        CVKAS_destroyAccelerationStructure(vkDev, handle)
        if let vmaAlloc = device.allocator, let buf = buffer, let memAlloc = allocation {
            CVMA_destroyBuffer(vmaAlloc, buf, memAlloc)
        }
    }
}
