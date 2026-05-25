// MARK: - Size

/// Mirrors MTLSize — thread counts for compute dispatch.
///
/// Used in `dispatchThreadgroups(_:threadsPerThreadgroup:)` to specify
/// the number of threadgroups per grid and threads per threadgroup.
public struct MTLSize {
    public var width:  Int
    public var height: Int
    public var depth:  Int

    public init(width: Int, height: Int = 1, depth: Int = 1) {
        self.width  = width
        self.height = height
        self.depth  = depth
    }
}
