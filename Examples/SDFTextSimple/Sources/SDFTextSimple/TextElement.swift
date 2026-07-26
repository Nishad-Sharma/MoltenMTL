/// One string to draw: its text, baseline pen position (pixels, top-left origin
/// — the vertex shader offsets each glyph above/below the baseline by its
/// bearing), em size, and font.
struct TextElement {
    var text: String
    var position: SIMD2<Float>
    var sizePx: Float
    var font: String
}
