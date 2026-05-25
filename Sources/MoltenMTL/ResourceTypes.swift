// MARK: - MTLResourceUsage

/// Mirrors `MTLResourceUsage` — declares how a resource is accessed inside an encoder.
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

// MARK: - MTLOriginMake

/// Mirrors `MTLOriginMake` — convenience constructor for `MTLOrigin`.
/// (`MTLOrigin` itself is defined in Texture.swift.)
public func MTLOriginMake(_ x: Int, _ y: Int, _ z: Int) -> MTLOrigin {
    MTLOrigin(x: x, y: y, z: z)
}

// MARK: - MTLSizeMake

/// Mirrors `MTLSizeMake` — convenience constructor for `MTLSize`.
public func MTLSizeMake(_ width: Int, _ height: Int, _ depth: Int) -> MTLSize {
    MTLSize(width: width, height: height, depth: depth)
}
