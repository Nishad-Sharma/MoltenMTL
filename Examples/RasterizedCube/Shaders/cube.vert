#version 450
// Vertex stage for RasterizedCube. Vertex-stage resources live in descriptor set 0
// (MoltenMTL convention: set 0 = vertex, set 1 = fragment). Per-vertex attributes come
// from three vertex buffers (position / normal / uv).

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;

// binding 3 ← setVertexBytes(index: 3); indices 0–2 are the vertex-input buffers.
layout(set = 0, binding = 3) uniform VertexUniforms {
    mat4 viewProj;
    mat4 model;
} u;

layout(location = 0) out vec3 fragWorldPos;
layout(location = 1) out vec3 fragNormal;
layout(location = 2) out vec2 fragUV;

void main() {
    vec4 worldPos = u.model * vec4(inPosition, 1.0);
    fragWorldPos  = worldPos.xyz;
    fragNormal    = mat3(u.model) * inNormal;   // translation-only here, so unchanged
    fragUV        = inUV;
    gl_Position   = u.viewProj * worldPos;
}
