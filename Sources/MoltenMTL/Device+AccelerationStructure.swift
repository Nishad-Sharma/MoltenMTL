internal import CVulkan

public extension MTLDevice {

    /// Queries the buffer sizes needed to build the acceleration structure.
    /// Pass `accelerationStructureSize` to `makeAccelerationStructure(size:)` and
    /// allocate a `.private` buffer of `buildScratchBufferSize` for the build.
    func accelerationStructureSizes(descriptor: MTLAccelerationStructureDescriptor)
        -> MTLAccelerationStructureSizes
    {
        guard let vkDev = device else { return MTLAccelerationStructureSizes() }

        if let blas = descriptor as? MTLPrimitiveAccelerationStructureDescriptor {
            return blasSizes(blas, vkDev: vkDev)
        } else if let tlas = descriptor as? MTLInstanceAccelerationStructureDescriptor {
            return tlasSizes(tlas, vkDev: vkDev)
        }
        return MTLAccelerationStructureSizes()
    }

    /// Allocates a VMA-backed buffer, creates a `VkAccelerationStructureKHR`, and queries its device address.
    func makeAccelerationStructure(size: Int) -> MTLAccelerationStructure? {
        guard let vkDev = device, let vmaAlloc = allocator else { return nil }

        // Allocate backing buffer
        // Must have ACCELERATION_STRUCTURE_STORAGE_BIT + SHADER_DEVICE_ADDRESS_BIT.
        let usageFlags = UInt32(bitPattern:
            VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR.rawValue) |
            UInt32(bitPattern: VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT.rawValue)

        var buf:   VkBuffer?
        var alloc: VmaAllocation?
        guard CVMA_createBuffer(vmaAlloc,
                                VkDeviceSize(size),
                                usageFlags,
                                1 /* private */,
                                &buf,
                                &alloc,
                                nil) == VK_SUCCESS,
              let buf else {
            print("[MoltenMTL] makeAccelerationStructure: buffer allocation failed")
            return nil
        }

        //  Create VkAccelerationStructureKHR
        var createInfo = VkAccelerationStructureCreateInfoKHR()
        createInfo.sType  = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_KHR
        createInfo.buffer = buf
        createInfo.offset = 0
        createInfo.size   = VkDeviceSize(size)
        // GENERIC allows use as either BLAS or TLAS; actual type is fixed at build time.
        createInfo.type   = VK_ACCELERATION_STRUCTURE_TYPE_GENERIC_KHR

        var handle: VkAccelerationStructureKHR?
        guard CVKAS_createAccelerationStructure(vkDev, &createInfo, &handle) == VK_SUCCESS,
              let handle else {
            print("[MoltenMTL] makeAccelerationStructure: vkCreateAccelerationStructureKHR failed")
            if let a = allocator, let al = alloc { CVMA_destroyBuffer(a, buf, al) }
            return nil
        }

        // Query device address
        let deviceAddress = CVKAS_getAccelerationStructureDeviceAddress(vkDev, handle)

        return MTLAccelerationStructure(size:          size,
                                     handle:        handle,
                                     buffer:        buf,
                                     allocation:    alloc,
                                     deviceAddress: deviceAddress,
                                     device:        self)
    }


    private func blasSizes(_ desc: MTLPrimitiveAccelerationStructureDescriptor,
                           vkDev: VkDevice) -> MTLAccelerationStructureSizes
    {
        let geoms = desc.geometryDescriptors
        guard !geoms.isEmpty else { return MTLAccelerationStructureSizes() }

        // Build a geometry array (device addresses left zeroed — only structure
        // matters for the size query).
        var vkGeoms = geoms.map { geom -> VkAccelerationStructureGeometryKHR in
            var triangles = VkAccelerationStructureGeometryTrianglesDataKHR()
            triangles.sType        = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR
            triangles.vertexFormat = VK_FORMAT_R32G32B32_SFLOAT
            triangles.vertexStride = VkDeviceSize(geom.vertexStride)
            triangles.maxVertex    = geom.vertexCount > 0 ? UInt32(geom.vertexCount - 1) : 0
            triangles.indexType    = geom.indexType.vkIndexType

            var geomData = VkAccelerationStructureGeometryDataKHR()
            geomData.triangles = triangles

            var vkGeom = VkAccelerationStructureGeometryKHR()
            vkGeom.sType        = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR
            vkGeom.geometryType = VK_GEOMETRY_TYPE_TRIANGLES_KHR
            vkGeom.geometry     = geomData
            vkGeom.flags        = UInt32(bitPattern: VK_GEOMETRY_OPAQUE_BIT_KHR.rawValue)
            return vkGeom
        }

        var maxPrimCounts = geoms.map { UInt32($0.triangleCount) }
        return querySizes(vkDev:          vkDev,
                          type:           VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR,
                          geometries:     &vkGeoms,
                          maxPrimCounts:  &maxPrimCounts)
    }

    private func tlasSizes(_ desc: MTLInstanceAccelerationStructureDescriptor,
                            vkDev: VkDevice) -> MTLAccelerationStructureSizes
    {
        var instancesData = VkAccelerationStructureGeometryInstancesDataKHR()
        instancesData.sType            = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR
        instancesData.arrayOfPointers  = 0 // VK_FALSE — flat array, not array of pointers

        var geomData = VkAccelerationStructureGeometryDataKHR()
        geomData.instances = instancesData

        var vkGeom = VkAccelerationStructureGeometryKHR()
        vkGeom.sType        = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR
        vkGeom.geometryType = VK_GEOMETRY_TYPE_INSTANCES_KHR
        vkGeom.geometry     = geomData

        var maxPrimCount = UInt32(max(desc.instanceCount, 0))
        var geoms = [vkGeom]
        return querySizes(vkDev:         vkDev,
                          type:          VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR,
                          geometries:    &geoms,
                          maxPrimCounts: &maxPrimCount)
    }

    private func querySizes(vkDev:         VkDevice,
                            type:          VkAccelerationStructureTypeKHR,
                            geometries:    inout [VkAccelerationStructureGeometryKHR],
                            maxPrimCounts: inout [UInt32]) -> MTLAccelerationStructureSizes
    {
        var buildInfo = VkAccelerationStructureBuildGeometryInfoKHR()
        buildInfo.sType         = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR
        buildInfo.type          = type
        buildInfo.flags         = UInt32(bitPattern:
            VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR.rawValue)
        buildInfo.mode          = VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR
        buildInfo.geometryCount = UInt32(geometries.count)

        var result = MTLAccelerationStructureSizes()
        geometries.withUnsafeBufferPointer { geomsBuf in
            buildInfo.pGeometries = geomsBuf.baseAddress
            maxPrimCounts.withUnsafeBufferPointer { countsBuf in
                var sizeInfo = VkAccelerationStructureBuildSizesInfoKHR()
                sizeInfo.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_SIZES_INFO_KHR
                CVKAS_getAccelerationStructureBuildSizes(
                    vkDev,
                    VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
                    &buildInfo,
                    countsBuf.baseAddress,
                    &sizeInfo)
                result = MTLAccelerationStructureSizes(
                    accelerationStructureSize: Int(sizeInfo.accelerationStructureSize),
                    buildScratchBufferSize:    Int(sizeInfo.buildScratchSize),
                    refitScratchBufferSize:    Int(sizeInfo.updateScratchSize))
            }
        }
        return result
    }

    private func querySizes(vkDev:         VkDevice,
                            type:          VkAccelerationStructureTypeKHR,
                            geometries:    inout [VkAccelerationStructureGeometryKHR],
                            maxPrimCounts: inout UInt32) -> MTLAccelerationStructureSizes
    {
        var array = [maxPrimCounts]
        return querySizes(vkDev: vkDev, type: type, geometries: &geometries,
                          maxPrimCounts: &array)
    }
}
