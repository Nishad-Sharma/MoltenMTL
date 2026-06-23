#version 450
// UI quad vertex shader for the render-encoder tests.
// Compile: glslc --target-env=vulkan1.3 ui_quad.vert -o ../Resources/ui_quad.vert.spv
//
// NDC follows Metal's +Y-up convention — MTLRenderCommandEncoder records a
// negative-height viewport, so write positions as you would for Metal.

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec4 inColor;

layout(location = 0) out vec2 fragUV;
layout(location = 1) out vec4 fragColor;

void main() {
    gl_Position = vec4(inPosition, 0.0, 1.0);
    fragUV      = inUV;
    fragColor   = inColor;
}
