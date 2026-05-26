
/// Thread counts for compute dispatch.
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
