#version 450


struct SDFDecodeParams {
    vec4 distanceRange;   // range in .x
};

// binding 0 ← setFragmentTexture/setFragmentSamplerState(index: 0)
// binding 1 = TextBinding.sdfParams ← setFragmentBytes
layout(set = 1, binding = 0) uniform sampler2D atlasTexture;
layout(set = 1, binding = 1) uniform SDFDecodeParamsBlock { SDFDecodeParams params; };

layout(location = 0) in vec2 fragUV;
layout(location = 0) out vec4 outColor;

const vec3 textColor = vec3(1.0);

float median3(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

float screenPxRange() {
    vec2 unitRange     = vec2(params.distanceRange.x) / vec2(textureSize(atlasTexture, 0));
    vec2 screenTexSize = vec2(1.0) / fwidth(fragUV);
    return max(0.5 * dot(unitRange, screenTexSize), 1.0);
}

void main() {
    vec3  msd     = texture(atlasTexture, fragUV).rgb;
    float sd      = median3(msd.r, msd.g, msd.b);
    float opacity = clamp(screenPxRange() * (sd - 0.5) + 0.5, 0.0, 1.0);
    outColor = vec4(textColor, opacity);
}
