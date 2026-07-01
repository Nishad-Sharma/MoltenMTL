#version 450
// Fragment stage for RasterizedCube. Bindings mirror the ExampleSupport Swift struct layouts
// so the host can pass Material, PointLight, and Camera directly without repacking.

layout(set = 1, binding = 0) uniform sampler2D tex;

layout(set = 1, binding = 1) uniform Material {
    layout(offset =  0) vec3  diffuseColor;
    layout(offset = 16) int   textureIndex;   // -1 = solid colour, >= 0 = sample tex
    layout(offset = 20) float shininess;
    layout(offset = 24) float specStrength;
} mat;

layout(set = 1, binding = 2) uniform PointLight {
    layout(offset =  0) vec3  position;
    layout(offset = 16) vec3  color;
    layout(offset = 32) float intensity;
    layout(offset = 36) float ambient;
} light;

// Only eye is read here; the full Camera struct is passed so the binding matches the
// Swift type's memory layout (eye / target / up / fovYDegrees / aspect).
layout(set = 1, binding = 3) uniform Camera {
    layout(offset =  0) vec3  eye;
    layout(offset = 16) vec3  target;
    layout(offset = 32) vec3  up;
    layout(offset = 48) float fovYDegrees;
    layout(offset = 52) float aspect;
} cam;

layout(location = 0) in vec3 fragWorldPos;
layout(location = 1) in vec3 fragNormal;
layout(location = 2) in vec2 fragUV;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 albedo = (mat.textureIndex >= 0) ? texture(tex, fragUV).rgb : mat.diffuseColor;

    vec3  N = normalize(fragNormal);
    vec3  P = fragWorldPos;

    vec3  toLight = light.position - P;
    float dist2   = max(dot(toLight, toLight), 1e-4);
    vec3  L       = toLight * inversesqrt(dist2);
    vec3  V       = normalize(cam.eye - P);
    vec3  H       = normalize(L + V);

    float atten = light.intensity / dist2;
    float diff  = max(dot(N, L), 0.0);
    float spec  = (diff > 0.0) ? pow(max(dot(N, H), 0.0), mat.shininess) * mat.specStrength : 0.0;

    vec3 color = albedo * light.ambient
               + (albedo * diff + vec3(spec)) * atten * light.color;

    outColor = vec4(color, 1.0);
}
