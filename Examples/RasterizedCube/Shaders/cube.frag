#version 450
// Fragment stage for RasterizedCube. Fragment-stage resources live in descriptor set 1.
// Point-light Blinn-Phong — the same shading math as RayTracedCube's raytrace.comp — so
// the two examples match. The cube texture is sampled with a real sampler (filtered),
// where the ray example used a nearest imageLoad.

layout(set = 1, binding = 0) uniform sampler2D tex;

// binding 1 ← setFragmentBytes(index: 1)
layout(set = 1, binding = 1) uniform FragUniforms {
    vec4 albedo;             // base colour for solid materials
    vec4 props;              // x = mode (0 solid, 1 textured), y = shininess, z = specStrength
    vec4 lightPosIntensity;  // xyz = light pos,   w = intensity
    vec4 lightColorAmbient;  // xyz = light color, w = ambient
    vec4 eye;                // xyz = camera eye
} u;

layout(location = 0) in vec3 fragWorldPos;
layout(location = 1) in vec3 fragNormal;
layout(location = 2) in vec2 fragUV;

layout(location = 0) out vec4 outColor;

void main() {
    float mode      = u.props.x;
    float shininess = u.props.y;
    float specStr   = u.props.z;

    vec3 albedo = (mode > 0.5) ? texture(tex, fragUV).rgb : u.albedo.rgb;

    vec3  N = normalize(fragNormal);
    vec3  P = fragWorldPos;

    vec3  lightPos   = u.lightPosIntensity.xyz;
    float intensity  = u.lightPosIntensity.w;
    vec3  lightColor = u.lightColorAmbient.xyz;
    float ambient    = u.lightColorAmbient.w;

    vec3  toLight = lightPos - P;
    float dist2   = max(dot(toLight, toLight), 1e-4);
    vec3  L       = toLight * inversesqrt(dist2);
    vec3  V       = normalize(u.eye.xyz - P);
    vec3  H       = normalize(L + V);

    float atten = intensity / dist2;
    float diff  = max(dot(N, L), 0.0);
    float spec  = (diff > 0.0) ? pow(max(dot(N, H), 0.0), shininess) * specStr : 0.0;

    vec3 color = albedo * ambient
               + (albedo * diff + vec3(spec)) * atten * lightColor;

    outColor = vec4(color, 1.0);
}
