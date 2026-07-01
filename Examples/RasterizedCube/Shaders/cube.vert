#version 450
// Vertex stage for RasterizedCube. Camera is passed as raw scene data (eye/target/up/fov/aspect)
// and view + projection matrices are computed here, matching the ray tracer's approach.

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;

// binding 3 ← setVertexBytes(index: 3); matches Swift Camera struct layout
layout(set = 0, binding = 3) uniform Camera {
    layout(offset =  0) vec3  eye;
    layout(offset = 16) vec3  target;
    layout(offset = 32) vec3  up;
    layout(offset = 48) float fovYDegrees;
    layout(offset = 52) float aspect;
} cam;

// binding 4 ← setVertexBytes(index: 4); full Instance struct (160B), offsets match Swift layout
layout(set = 0, binding = 4) uniform Instance {
    layout(offset =   0) mat4  modelMatrix;
    layout(offset =  64) uvec2 meshIndex;       // Swift Int (8B)
    layout(offset =  72) vec4  transform[3];    // MTLPackedFloat4x3 placeholder (48B)
    layout(offset = 128) vec3  diffuseColor;    // Material.diffuseColor (SIMD3=16B in Swift)
    layout(offset = 144) int   textureIndex;    // Material.textureIndex
    layout(offset = 148) float shininess;       // Material.shininess
    layout(offset = 152) float specStrength;    // Material.specStrength
} inst;

layout(location = 0) out vec3 fragWorldPos;
layout(location = 1) out vec3 fragNormal;
layout(location = 2) out vec2 fragUV;

mat4 lookAt(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4( s.x,  u.x, -f.x, 0),
        vec4( s.y,  u.y, -f.y, 0),
        vec4( s.z,  u.z, -f.z, 0),
        vec4(-dot(s, eye), -dot(u, eye), dot(f, eye), 1));
}

mat4 perspective(float fovYDeg, float aspect, float near, float far) {
    float f = 1.0 / tan(radians(fovYDeg) * 0.5);
    return mat4(
        vec4(f / aspect, 0,  0,                          0),
        vec4(0,          f,  0,                          0),
        vec4(0,          0,  far / (near - far),        -1),
        vec4(0,          0,  (near * far) / (near - far), 0));
}

void main() {
    mat4 view     = lookAt(cam.eye, cam.target, cam.up);
    mat4 proj     = perspective(cam.fovYDegrees, cam.aspect, 0.1, 100.0);
    vec4 worldPos = inst.modelMatrix * vec4(inPosition, 1.0);
    fragWorldPos  = worldPos.xyz;
    fragNormal    = mat3(inst.modelMatrix) * inNormal;
    fragUV        = inUV;
    gl_Position   = proj * view * worldPos;
}
