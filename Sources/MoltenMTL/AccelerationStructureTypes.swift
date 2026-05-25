import CVulkan

// MARK: - MTLPackedFloat3

/// Mirrors MTLPackedFloat3 — three tightly packed floats with no padding.
public struct MTLPackedFloat3 {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x; self.y = y; self.z = z
    }

    public init() { x = 0; y = 0; z = 0 }
}

/// Mirrors MTLPackedFloat3Make.
public func MTLPackedFloat3Make(_ x: Float, _ y: Float, _ z: Float) -> MTLPackedFloat3 {
    MTLPackedFloat3(x, y, z)
}

// MARK: - MTLPackedFloat4x3

/// Mirrors MTLPackedFloat4x3 — four columns of MTLPackedFloat3 (column-major 3×4 matrix).
///
/// Used to represent TLAS instance transforms. The four columns correspond to:
///   - `columns.0` = x-axis direction
///   - `columns.1` = y-axis direction
///   - `columns.2` = z-axis direction
///   - `columns.3` = translation
public struct MTLPackedFloat4x3 {
    public var columns: (MTLPackedFloat3, MTLPackedFloat3, MTLPackedFloat3, MTLPackedFloat3)

    public init() {
        let zero = MTLPackedFloat3()
        columns = (zero, zero, zero, zero)
    }

    public init(_ c0: MTLPackedFloat3, _ c1: MTLPackedFloat3,
                _ c2: MTLPackedFloat3, _ c3: MTLPackedFloat3) {
        columns = (c0, c1, c2, c3)
    }
}

// MARK: - MTLAccelerationStructureInstanceOptions

/// Mirrors MTLAccelerationStructureInstanceOptions.
/// Raw values match the corresponding VkGeometryInstanceFlagBitsKHR values.
public struct MTLAccelerationStructureInstanceOptions: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Disables back-face culling. (VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR)
    public static let disableFaceCulling = MTLAccelerationStructureInstanceOptions(rawValue: 0x1)
    /// Forces all intersection tests to be treated as opaque. (VK_GEOMETRY_INSTANCE_FORCE_OPAQUE_BIT_KHR)
    public static let opaque             = MTLAccelerationStructureInstanceOptions(rawValue: 0x4)
    /// Forces all intersection tests to be treated as non-opaque. (VK_GEOMETRY_INSTANCE_FORCE_NO_OPAQUE_BIT_KHR)
    public static let nonOpaque          = MTLAccelerationStructureInstanceOptions(rawValue: 0x8)
}

// MARK: - MTLAccelerationStructureInstanceDescriptor

/// Mirrors MTLAccelerationStructureInstanceDescriptor — one entry in a TLAS instance buffer.
public struct MTLAccelerationStructureInstanceDescriptor {
    /// Index into `MTLInstanceAccelerationStructureDescriptor.instancedAccelerationStructures`.
    public var accelerationStructureIndex:      UInt32 = 0
    public var options:                         MTLAccelerationStructureInstanceOptions = .opaque
    /// Visibility mask — only instances with (mask & rayMask) != 0 are tested.
    public var mask:                            UInt32 = 0xFF
    public var intersectionFunctionTableOffset: UInt32 = 0
    public var transformationMatrix:            MTLPackedFloat4x3 = MTLPackedFloat4x3()

    public init() {}
}

// MARK: - MTLIndexType

/// Mirrors MTLIndexType — index buffer element size.
public enum MTLIndexType {
    case uint16
    case uint32

    var vkIndexType: VkIndexType {
        switch self {
        case .uint16: return VK_INDEX_TYPE_UINT16
        case .uint32: return VK_INDEX_TYPE_UINT32
        }
    }
}

// MARK: - MTLAttributeFormat

/// Vertex attribute format for acceleration structure geometry.
public enum MTLAttributeFormat {
    /// Three packed 32-bit floats. Maps to VK_FORMAT_R32G32B32_SFLOAT.
    case float3
}

// MARK: - MTLAccelerationStructureSizes

/// Mirrors MTLAccelerationStructureSizes — buffer sizes required to build an AS.
public struct MTLAccelerationStructureSizes {
    /// Byte size needed for the acceleration structure itself.
    public var accelerationStructureSize: Int = 0
    /// Byte size of the scratch buffer required for a full build.
    public var buildScratchBufferSize: Int    = 0
    /// Byte size of the scratch buffer required for a refit (update).
    public var refitScratchBufferSize: Int    = 0
}

// MARK: - MTLAccelerationStructureDescriptor (protocol)

/// Conformance marker — passed to `device.accelerationStructureSizes(descriptor:)`.
public protocol MTLAccelerationStructureDescriptor: AnyObject {}

// MARK: - MTLAccelerationStructureTriangleGeometryDescriptor

/// Mirrors MTLAccelerationStructureTriangleGeometryDescriptor — triangle geometry for a BLAS.
/// NOTE: Difference in API, Vulkan requires vertexCount explicitly, MTL infers it.
public final class MTLAccelerationStructureTriangleGeometryDescriptor {
    public var vertexBuffer:       MTLBuffer?          = nil
    public var vertexBufferOffset: Int                 = 0
    /// Stride between vertices in bytes.
    public var vertexStride:       Int                 = 12   // packed float3 = 12 bytes
    public var vertexFormat:       MTLAttributeFormat  = .float3
    /// Total number of vertices referenced. Used by Vulkan for bounds checking.
    public var vertexCount:        Int                 = 0
    public var indexBuffer:        MTLBuffer?          = nil
    public var indexBufferOffset:  Int                 = 0
    public var indexType:          MTLIndexType        = .uint32
    public var triangleCount:      Int                 = 0

    public init() {}
}

// MARK: - MTLPrimitiveAccelerationStructureDescriptor

/// Mirrors MTLPrimitiveAccelerationStructureDescriptor — describes a BLAS build.
public final class MTLPrimitiveAccelerationStructureDescriptor: MTLAccelerationStructureDescriptor {
    public var geometryDescriptors: [MTLAccelerationStructureTriangleGeometryDescriptor] = []
    public init() {}
}

// MARK: - MTLInstanceAccelerationStructureDescriptor

/// Mirrors MTLInstanceAccelerationStructureDescriptor — describes a TLAS build.
public final class MTLInstanceAccelerationStructureDescriptor: MTLAccelerationStructureDescriptor {
    /// Host-visible buffer containing `MTLAccelerationStructureInstanceDescriptor` entries.
    /// Must be `.shared` storage mode so the encoder can read and convert the instances.
    public var instanceDescriptorBuffer:        MTLBuffer?                 = nil
    public var instanceCount:                   Int                        = 0
    /// BLAS array — indexed by `MTLAccelerationStructureInstanceDescriptor.accelerationStructureIndex`.
    public var instancedAccelerationStructures: [MTLAccelerationStructure] = []

    public init() {}
}
