
/// Mirrors `MTLResourceUsage` - declares how a resource is accessed inside an encoder.
///
/// On Vulkan, residency is managed automatically through descriptor bindings,
/// so `useResource` and `useHeap` calls are no-ops. This type exists purely
/// for source-level API parity with Metal.
public struct MTLResourceUsage: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let read   = MTLResourceUsage(rawValue: 1 << 0)
    public static let write  = MTLResourceUsage(rawValue: 1 << 1)
    public static let sample = MTLResourceUsage(rawValue: 1 << 2)
}

/// Convenience constructor for `MTLOrigin` (defined in Texture.swift).
public func MTLOriginMake(_ x: Int, _ y: Int, _ z: Int) -> MTLOrigin {
    MTLOrigin(x: x, y: y, z: z)
}

/// Convenience constructor for `MTLSize`.
public func MTLSizeMake(_ width: Int, _ height: Int, _ depth: Int) -> MTLSize {
    MTLSize(width: width, height: height, depth: depth)
}

/// Convenience constructor for a 1-D `MTLRegion` (defined in Texture.swift).
public func MTLRegionMake1D(_ x: Int, _ width: Int) -> MTLRegion {
    MTLRegion(origin: MTLOrigin(x: x, y: 0, z: 0),
              size:   MTLSize(width: width, height: 1, depth: 1))
}

/// Convenience constructor for a 2-D `MTLRegion`.
public func MTLRegionMake2D(_ x: Int, _ y: Int, _ width: Int, _ height: Int) -> MTLRegion {
    MTLRegion(origin: MTLOrigin(x: x, y: y, z: 0),
              size:   MTLSize(width: width, height: height, depth: 1))
}

/// Convenience constructor for a 3-D `MTLRegion`.
public func MTLRegionMake3D(_ x: Int, _ y: Int, _ z: Int,
                            _ width: Int, _ height: Int, _ depth: Int) -> MTLRegion {
    MTLRegion(origin: MTLOrigin(x: x, y: y, z: z),
              size:   MTLSize(width: width, height: height, depth: depth))
}
