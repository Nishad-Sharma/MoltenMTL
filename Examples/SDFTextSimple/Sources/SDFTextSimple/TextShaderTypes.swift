// CPU-side mirrors of the std430/std140 structs in TextRaster.vert/.frag.
// These are uploaded as raw bytes, so field order, alignment, and stride must
// match the GLSL declarations exactly (asserted in FontAtlas.init).

struct GlyphInstance {         // std430 `GlyphInstance` in TextRaster.vert, stride 16
    var glyphIndex: UInt32     // dense glyph-table index (atlas file order)
    var sizePx: Float          // em size in pixels for this glyph
    var position: SIMD2<Float> // absolute pen position, pixels
}

struct GlyphQuad {                // std430 `GlyphQuad` in TextRaster.vert, stride 32
    var bearing: SIMD2<Float>     // offset of quad from pen position, EM units
    var size: SIMD2<Float>        // quad size, EM units
    var atlasUVmin: SIMD2<Float>  // glyph rectangle in the atlas, normalized UV
    var atlasUVmax: SIMD2<Float>
}

struct TextPassParams {
    var screen: SIMD4<Float>         // .xy = render-target size, pixels
}

struct SDFDecodeParams {
    var distanceRange: SIMD4<Float>  // .x = SDF band width in atlas texels
}

/// Buffer binding indices — GLSL binding = Metal index, per stage.
enum TextBinding {
    // Vertex stage (descriptor set 0 in the shaders).
    static let chars      = 0
    static let glyphQuads = 1
    static let passParams = 2
    // Fragment stage (descriptor set 1); texture/sampler use index 0.
    static let sdfParams  = 1
}
