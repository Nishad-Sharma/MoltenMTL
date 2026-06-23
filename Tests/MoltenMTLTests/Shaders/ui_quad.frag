#version 450
// UI quad fragment shader for the render-encoder tests.
// Compile: glslc --target-env=vulkan1.3 ui_quad.frag -o ../Resources/ui_quad.frag.spv
//
// Fragment-stage resources live in descriptor set 1 (MoltenMTL convention:
// set 0 = vertex stage, set 1 = fragment stage; Metal index = GLSL binding).
// binding 0 ← setFragmentTexture/setFragmentSamplerState(index: 0)
// binding 1 ← setFragmentBuffer/setFragmentBytes(index: 1)

layout(set = 1, binding = 0) uniform sampler2D tex;
layout(set = 1, binding = 1) uniform TintParams { vec4 tint; } params;

layout(location = 0) in vec2 fragUV;
layout(location = 1) in vec4 fragColor;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = texture(tex, fragUV) * fragColor * params.tint;
}
