import CVulkan

public extension MTLDevice {

    // MARK: - makeBuffer

    /// Mirrors `MTLDevice.makeBuffer(length:options:)`.
    ///
    /// Allocates a `VkBuffer` backed by VMA-managed `VkDeviceMemory`.
    /// - `.shared`  → `VMA_MEMORY_USAGE_AUTO` + persistent map + prefer ReBAR/HOST_VISIBLE.
    /// - `.private` → `VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE`, GPU-only, `contents()` returns `nil`.
    func makeBuffer(length: Int, options: MTLStorageMode) -> MTLBuffer? {
        makeBuffer(length: length, options: options == .private ? .storageModePrivate : [])
    }

    /// Primary API — mirrors `MTLDevice.makeBuffer(length:options:)`.
    ///
    /// Accepts `MTLResourceOptions` (an OptionSet), so all Metal array-literal call
    /// sites compile unchanged: `device.makeBuffer(length: n, options: [.storageModeShared])`.
    func makeBuffer(length: Int, options: MTLResourceOptions = []) -> MTLBuffer? {
        guard let vmaAlloc = allocator else {
            print("[VulkanSwift] makeBuffer: VMA allocator is nil")
            return nil
        }

        // ── Usage flags ────────────────────────────────────────────────────────
        // Always include SHADER_DEVICE_ADDRESS so buffers can be used in RT/BDA.
        let usage = UInt32(bitPattern: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue)
                  | UInt32(bitPattern: VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT.rawValue)
                  | UInt32(bitPattern: VK_BUFFER_USAGE_TRANSFER_SRC_BIT.rawValue)
                  | UInt32(bitPattern: VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue)
                  | UInt32(bitPattern: VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR.rawValue)

        // ── Call VMA wrapper ───────────────────────────────────────────────────
        // storageMode 0 = shared (CPU+GPU, persistently mapped)
        // storageMode 1 = private (GPU-only)
        var buf:    VkBuffer?
        var vmaBuf: VmaAllocation?
        var mapped: UnsafeMutableRawPointer?

        let mode   = Int32(options.storageMode == .private ? 1 : 0)
        let result = CVMA_createBuffer(vmaAlloc,
                                       VkDeviceSize(length),
                                       usage,
                                       mode,
                                       &buf,
                                       &vmaBuf,
                                       &mapped)

        guard result == VK_SUCCESS else {
            print("[VulkanSwift] CVMA_createBuffer failed (VkResult \(result.rawValue))")
            return nil
        }

        return MTLBuffer(handle:       buf,
                      allocation:   vmaBuf,
                      vmaAllocator: vmaAlloc,
                      vkDevice:     self.device,
                      contents:     mapped,
                      length:       length)
    }

    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: MTLResourceOptions = []) -> MTLBuffer? {
        guard let buf = makeBuffer(length: length, options: options) else { return nil }
        buf.contents().copyMemory(from: bytes, byteCount: length)
        return buf
    }
}
