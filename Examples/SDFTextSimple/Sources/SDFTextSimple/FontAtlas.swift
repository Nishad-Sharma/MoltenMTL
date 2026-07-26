import Foundation
import MoltenMTL

struct FontAtlas {
    let distanceRange: Float   // sdf band width in atlas texels
    let atlasTexture: MTLTexture
    let glyphQuadBuffer: MTLBuffer

    let glyphUnicodeToIndices: [UInt32: UInt32] // unicode to index map for glpyhQuadBuffer and glyphAdvances
    let glyphAdvances: [Float] // per-glyph advance - used by pen walk

    let fallbackIndex: UInt32

    init(device: MTLDevice, jsonData: Data, binData: Data) throws {
        // These structs are uploaded as raw bytes and read as std430 structs in
        // TextRaster.vert — the Swift strides must match the GLSL layout.
        assert(MemoryLayout<GlyphQuad>.stride == 32 && MemoryLayout<GlyphInstance>.stride == 16)

        let (info, glyphs) = try decodeAtlas(jsonData: jsonData, binData: binData)
        let width = info.width
        let height = info.height
        self.distanceRange = info.distanceRange
        self.glyphAdvances = glyphs.map(\.advance)

        var indices: [UInt32: UInt32] = [:]
        indices.reserveCapacity(glyphs.count)
        for (i, g) in glyphs.enumerated() {
            indices[g.unicode] = UInt32(i)
        }
        self.glyphUnicodeToIndices = indices
        self.fallbackIndex = indices[0x3F] ?? 0

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height,
            mipmapped: false)
        desc.usage = .shaderRead
        let texture = device.makeTexture(descriptor: desc)!
        binData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            texture.replace(region: .make2D(width: width, height: height),
                            mipmapLevel: 0, withBytes: raw.baseAddress!,
                            bytesPerRow: width * 4)
        }
        self.atlasTexture = texture

        // Build the dense glyph table, one slot per atlas glyph in file order.
        let aw = Float(width)
        let ah = Float(height)
        var table = [GlyphQuad](repeating: GlyphQuad(bearing: .zero, size: .zero, atlasUVmin: .zero, atlasUVmax: .zero),
                                count: glyphs.count)
        for (i, g) in glyphs.enumerated() {
            if let pb = g.planeBounds, let ab = g.atlasBounds {
                table[i] = GlyphQuad(
                    bearing:    SIMD2(pb.left, pb.top),
                    size:       SIMD2(pb.right - pb.left, pb.bottom - pb.top),
                    atlasUVmin: SIMD2(ab.left / aw,  ab.top / ah),
                    atlasUVmax: SIMD2(ab.right / aw, ab.bottom / ah))
            }
        }
        self.glyphQuadBuffer = table.withUnsafeBytes {
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)!
        }
    }

    func getGlyphIndex(of scalar: Unicode.Scalar) -> UInt32 {
        glyphUnicodeToIndices[scalar.value] ?? fallbackIndex
    }
}
