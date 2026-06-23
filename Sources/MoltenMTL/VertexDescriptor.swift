internal import CVulkan

/// Format of a single vertex attribute.
/// Each case maps to a specific `VkFormat`.
public enum MTLVertexFormat {
    case float
    case float2
    case float3
    case float4
    case uchar4Normalized
    case ushort2
    case uint

    var vkFormat: VkFormat {
        switch self {
        case .float:            return VK_FORMAT_R32_SFLOAT
        case .float2:           return VK_FORMAT_R32G32_SFLOAT
        case .float3:           return VK_FORMAT_R32G32B32_SFLOAT
        case .float4:           return VK_FORMAT_R32G32B32A32_SFLOAT
        case .uchar4Normalized: return VK_FORMAT_R8G8B8A8_UNORM
        case .ushort2:          return VK_FORMAT_R16G16_UINT
        case .uint:             return VK_FORMAT_R32_UINT
        }
    }
}

/// How vertex data advances: per vertex or per instance.
public enum MTLVertexStepFunction {
    case perVertex
    case perInstance

    var vkInputRate: VkVertexInputRate {
        switch self {
        case .perVertex:   return VK_VERTEX_INPUT_RATE_VERTEX
        case .perInstance: return VK_VERTEX_INPUT_RATE_INSTANCE
        }
    }
}

/// One vertex attribute: its format, byte offset within the vertex, and which
/// vertex buffer (set via `setVertexBuffer(_:offset:index:)`) it reads from.
public final class MTLVertexAttributeDescriptor {
    public var format:      MTLVertexFormat = .float4
    public var offset:      Int = 0
    public var bufferIndex: Int = 0

    public init() {}
}

/// Layout of one vertex buffer: stride between elements and step function.
public final class MTLVertexBufferLayoutDescriptor {
    public var stride:       Int = 0
    public var stepFunction: MTLVertexStepFunction = .perVertex

    public init() {}
}

/// Sparse array that creates elements on first access, mirroring the subscript
/// behaviour of Metal's descriptor-array types (vertex attributes/layouts,
/// render-pass and pipeline color attachments).
public final class MTLDescriptorArray<Element> {
    private var storage: [Int: Element] = [:]
    private let makeElement: () -> Element

    init(makeElement: @escaping () -> Element) {
        self.makeElement = makeElement
    }

    public subscript(index: Int) -> Element {
        if let existing = storage[index] { return existing }
        let element = makeElement()
        storage[index] = element
        return element
    }

    /// Indices that have been touched via the subscript.
    var definedIndices: [Int] { storage.keys.sorted() }
}

/// Describes the vertex input layout for `MTLRenderPipelineDescriptor.vertexDescriptor`.
/// Only attributes/layouts actually accessed via subscript are emitted into the pipeline.
public final class MTLVertexDescriptor {

    public let attributes = MTLDescriptorArray { MTLVertexAttributeDescriptor() }
    public let layouts    = MTLDescriptorArray { MTLVertexBufferLayoutDescriptor() }

    public init() {}
}
