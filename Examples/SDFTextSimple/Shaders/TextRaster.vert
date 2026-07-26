#version 450


struct GlyphInstance {
    uint  glyphIndex;
    float sizePx;      // em size in pixels for this glyph
    vec2  position;
};

struct GlyphQuad {
    vec2 bearing;     // offset of quad from pen position, EM units
    vec2 size;        // quad size, EM units (zero = invisible: space / missing)
    vec2 atlasUVmin;  // glyph rectangle in the atlas, normalized UV
    vec2 atlasUVmax;
};

struct TextPassParams {
    vec4 screen;           // .xy = render-target size (px)
};

// binding 0 = TextBinding.chars      ← setVertexBuffer  (character records)
// binding 1 = TextBinding.glyphQuads ← setVertexBuffer  (glyph quads, indexed by glyphIndex)
// binding 2 = TextBinding.passParams ← setVertexBytes   (per-pass params, set once)
layout(set = 0, binding = 0, std430) readonly buffer Chars  { GlyphInstance chars[]; };
layout(set = 0, binding = 1, std430) readonly buffer Quads  { GlyphQuad quads[]; };
layout(set = 0, binding = 2) uniform PassParamsBlock { TextPassParams pass; };

layout(location = 0) out vec2 fragUV;

// Two triangles of a unit quad: (0,0)(1,0)(0,1) and (0,1)(1,0)(1,1).
const vec2 corners[6] = vec2[](
    vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 1.0),
    vec2(0.0, 1.0), vec2(1.0, 0.0), vec2(1.0, 1.0)
);

void main() {
    GlyphInstance c = chars[gl_InstanceIndex];
    GlyphQuad g     = quads[c.glyphIndex];
    vec2 corner  = corners[gl_VertexIndex];
    // Pixel snapping: round the assembled quad origin so the quad's left/top edges
    // land exactly on pixel boundaries — fractional origins give every stroke edge
    // a ~50% gray pixel and make each letter's sharpness a lottery. Round the SUM,
    // once per quad (rounding parts separately doesn't make the sum integer, and
    // rounding per corner would resize the glyph). Trade-off: snapped text steps
    // whole pixels when moved — right for static UI, skip for smooth animation.
    vec2 quadOrigin = round(c.position + g.bearing * c.sizePx);
    vec2 px         = quadOrigin + corner * g.size * c.sizePx;
    gl_Position  = vec4(2.0 * px.x / pass.screen.x - 1.0,
                        1.0 - 2.0 * px.y / pass.screen.y,
                        0.0, 1.0);
    fragUV = mix(g.atlasUVmin, g.atlasUVmax, corner);
}
