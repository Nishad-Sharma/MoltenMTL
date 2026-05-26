import CVulkan

/// Records acceleration structure build commands.
/// Create via `commandBuffer.makeAccelerationStructureCommandEncoder()`.
public final class MTLAccelerationStructureCommandEncoder {

    private let cmdBuf: VkCommandBuffer
    private let device: MTLDevice

    /// Temporary host-visible buffers created during TLAS builds.
    /// Kept alive until `endEncoding()` / deinit so the GPU can read them.
    private var temporaryBuffers: [(VkBuffer, VmaAllocation)] = []

    init(commandBuffer: VkCommandBuffer, device: MTLDevice) {
        self.cmdBuf = commandBuffer
        self.device = device
    }

    deinit {
        freeTemporaryBuffers()
    }

    /// Records a GPU command to build `accelerationStructure` from the given descriptor.
    /// - For `PrimitiveAccelerationStructureDescriptor`: builds a BLAS.
    /// - For `InstanceAccelerationStructureDescriptor`:  builds a TLAS.
    ///   The instance descriptor buffer must use `.shared` storage mode so its
    ///   contents can be read and converted to Vulkan's instance format.
    public func build(accelerationStructure: MTLAccelerationStructure,
                      descriptor:            MTLAccelerationStructureDescriptor,
                      scratchBuffer:         MTLBuffer,
                      scratchBufferOffset:   Int) {
        guard let vkDev = device.device,
              let asDst = accelerationStructure.handle,
              let scratchHandle = scratchBuffer.handle else { return }

        let scratchAddr = CVKAS_getBufferDeviceAddress(vkDev, scratchHandle)
                        + VkDeviceAddress(scratchBufferOffset)

        if let blas = descriptor as? MTLPrimitiveAccelerationStructureDescriptor {
            buildBLAS(accelerationStructure: asDst,
                      descriptor: blas,
                      scratchAddr: scratchAddr,
                      vkDev: vkDev)
        } else if let tlas = descriptor as? MTLInstanceAccelerationStructureDescriptor {
            buildTLAS(accelerationStructure: asDst,
                      descriptor: tlas,
                      scratchAddr: scratchAddr,
                      vkDev: vkDev)
        }
    }

     public func endEncoding() {
        // No Vulkan call needed - the encoder doesn't own a sub-command buffer.
        // Temporary Vulkan buffers (e.g. TLAS instance data) must remain valid
        // until GPU execution completes. Cleanup is handled by deinit, which runs
        // after buf.waitUntilCompleted() returns at the call site.
    }

    private func buildBLAS(accelerationStructure: VkAccelerationStructureKHR,
                           descriptor:            MTLPrimitiveAccelerationStructureDescriptor,
                           scratchAddr:           VkDeviceAddress,
                           vkDev:                 VkDevice)
    {
        let geoms = descriptor.geometryDescriptors
        guard !geoms.isEmpty else { return }

        var vkGeoms    = [VkAccelerationStructureGeometryKHR]()
        var buildRanges = [VkAccelerationStructureBuildRangeInfoKHR]()

        for geom in geoms {
            guard let vbHandle = geom.vertexBuffer?.handle,
                  let ibHandle = geom.indexBuffer?.handle else {
                print("[VulkanSwift] BLAS build: missing vertex or index buffer")
                return
            }

            let vAddr = CVKAS_getBufferDeviceAddress(vkDev, vbHandle)
                      + VkDeviceAddress(geom.vertexBufferOffset)
            let iAddr = CVKAS_getBufferDeviceAddress(vkDev, ibHandle)
                      + VkDeviceAddress(geom.indexBufferOffset)

            var triangles = VkAccelerationStructureGeometryTrianglesDataKHR()
            triangles.sType              = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR
            triangles.vertexFormat       = VK_FORMAT_R32G32B32_SFLOAT
            triangles.vertexData.deviceAddress = vAddr
            triangles.vertexStride       = VkDeviceSize(geom.vertexStride)
            triangles.maxVertex          = geom.vertexCount > 0
                                         ? UInt32(geom.vertexCount - 1) : 0
            triangles.indexType          = geom.indexType.vkIndexType
            triangles.indexData.deviceAddress  = iAddr

            var geomData = VkAccelerationStructureGeometryDataKHR()
            geomData.triangles = triangles

            var vkGeom = VkAccelerationStructureGeometryKHR()
            vkGeom.sType        = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR
            vkGeom.geometryType = VK_GEOMETRY_TYPE_TRIANGLES_KHR
            vkGeom.geometry     = geomData
            vkGeom.flags        = UInt32(bitPattern: VK_GEOMETRY_OPAQUE_BIT_KHR.rawValue)
            vkGeoms.append(vkGeom)

            var range = VkAccelerationStructureBuildRangeInfoKHR()
            range.primitiveCount  = UInt32(geom.triangleCount)
            range.primitiveOffset = 0
            range.firstVertex     = 0
            range.transformOffset = 0
            buildRanges.append(range)
        }

        var buildInfo = VkAccelerationStructureBuildGeometryInfoKHR()
        buildInfo.sType                   = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR
        buildInfo.type                    = VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR
        buildInfo.flags                   = UInt32(bitPattern:
            VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR.rawValue)
        buildInfo.mode                    = VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR
        buildInfo.dstAccelerationStructure = accelerationStructure
        buildInfo.geometryCount           = UInt32(vkGeoms.count)
        buildInfo.scratchData.deviceAddress = scratchAddr

        vkGeoms.withUnsafeBufferPointer { geomsBuf in
            buildInfo.pGeometries = geomsBuf.baseAddress
            buildRanges.withUnsafeBufferPointer { rangesBuf in
                CVKAS_cmdBuildAccelerationStructures(cmdBuf, &buildInfo,
                                                    rangesBuf.baseAddress)
            }
        }
    }

    private func buildTLAS(accelerationStructure: VkAccelerationStructureKHR,
                           descriptor:            MTLInstanceAccelerationStructureDescriptor,
                           scratchAddr:           VkDeviceAddress,
                           vkDev:                 VkDevice)
    {
        let instanceCount = descriptor.instanceCount
        guard instanceCount > 0,
              let vmaAlloc = device.allocator,
              let srcPtr = descriptor.instanceDescriptorBuffer?.contents() else {
            print("[VulkanSwift] TLAS build: instanceCount=0 or missing instance buffer")
            return
        }

        let stride = MemoryLayout<CVkInstanceData>.stride  // 64 bytes
        let instBufSize = VkDeviceSize(instanceCount * stride)

        // Allocate host-visible buffer for Vulkan-format instance data
        let instUsage = UInt32(bitPattern:
            VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR.rawValue) |
            UInt32(bitPattern: VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT.rawValue)

        var instBuf:    VkBuffer?
        var instAlloc:  VmaAllocation?
        var instMapped: UnsafeMutableRawPointer?

        guard CVMA_createBuffer(vmaAlloc, instBufSize, instUsage,
                                0 /* shared */,
                                &instBuf, &instAlloc, &instMapped) == VK_SUCCESS,
              let instBuf, let instAlloc, let instMapped else {
            print("[VulkanSwift] TLAS build: instance buffer allocation failed")
            return
        }

        // Convert MTLAccelerationStructureInstanceDescriptor to CVkInstanceData
        let srcInstances = srcPtr.bindMemory(
            to: MTLAccelerationStructureInstanceDescriptor.self, capacity: instanceCount)
        let dstInstances = instMapped.bindMemory(
            to: CVkInstanceData.self, capacity: instanceCount)

        for i in 0..<instanceCount {
            let src = srcInstances[i]
            var dst = CVkInstanceData()

            // Transform: Metal column-major (4 cols of float3) to Vulkan row-major (float[3][4])
            // vk.matrix[row][col] = metal.columns[col][row]
            let (c0, c1, c2, c3) = src.transformationMatrix.columns
            dst.transform.0.0 = c0.x; dst.transform.0.1 = c1.x
            dst.transform.0.2 = c2.x; dst.transform.0.3 = c3.x
            dst.transform.1.0 = c0.y; dst.transform.1.1 = c1.y
            dst.transform.1.2 = c2.y; dst.transform.1.3 = c3.y
            dst.transform.2.0 = c0.z; dst.transform.2.1 = c1.z
            dst.transform.2.2 = c2.z; dst.transform.2.3 = c3.z

            dst.customIndexAndMask = (src.mask & 0xFF) << 24

            let flags = src.options.rawValue & 0xFF
            dst.sbtOffsetAndFlags = (flags << 24) |
                (src.intersectionFunctionTableOffset & 0x00FFFFFF)

            let blasIdx = Int(src.accelerationStructureIndex)
            if blasIdx < descriptor.instancedAccelerationStructures.count {
                dst.blasAddress = descriptor.instancedAccelerationStructures[blasIdx].deviceAddress
            } else {
                print("[VulkanSwift] TLAS build: accelerationStructureIndex \(blasIdx) out of range")
                dst.blasAddress = 0
            }

            dstInstances[i] = dst
        }

        // Keep the instance buffer alive until endEncoding() / commit().
        temporaryBuffers.append((instBuf, instAlloc))

        // Build the TLAS
        let instBufAddr = CVKAS_getBufferDeviceAddress(vkDev, instBuf)

        var instancesData = VkAccelerationStructureGeometryInstancesDataKHR()
        instancesData.sType           = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR
        instancesData.arrayOfPointers = 0  // VK_FALSE — flat array
        instancesData.data.deviceAddress = instBufAddr
    
        var geomData = VkAccelerationStructureGeometryDataKHR()
        geomData.instances = instancesData

        var vkGeom = VkAccelerationStructureGeometryKHR()
        vkGeom.sType        = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR
        vkGeom.geometryType = VK_GEOMETRY_TYPE_INSTANCES_KHR
        vkGeom.geometry     = geomData

        var range = VkAccelerationStructureBuildRangeInfoKHR()
        range.primitiveCount  = UInt32(instanceCount)
        range.primitiveOffset = 0
        range.firstVertex     = 0
        range.transformOffset = 0

        var buildInfo = VkAccelerationStructureBuildGeometryInfoKHR()
        buildInfo.sType                    = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR
        buildInfo.type                     = VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR
        buildInfo.flags                    = UInt32(bitPattern:
            VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR.rawValue)
        buildInfo.mode                     = VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR
        buildInfo.dstAccelerationStructure = accelerationStructure
        buildInfo.geometryCount            = 1
        buildInfo.scratchData.deviceAddress = scratchAddr

        withUnsafePointer(to: vkGeom) { geomPtr in
            buildInfo.pGeometries = geomPtr
            withUnsafePointer(to: range) { rangePtr in
                CVKAS_cmdBuildAccelerationStructures(cmdBuf, &buildInfo, rangePtr)
            }
        }
    }

    private func freeTemporaryBuffers() {
        guard let vmaAlloc = device.allocator else { return }
        for (buf, alloc) in temporaryBuffers {
            CVMA_destroyBuffer(vmaAlloc, buf, alloc)
        }
        temporaryBuffers.removeAll()
    }
}
