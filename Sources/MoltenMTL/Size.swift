
/// Thread counts for a compute dispatch, or texel dimensions for a region.
/// `height` and `depth` default to 1, so 1-D dispatches can be expressed as `MTLSize(width: N)`.
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
