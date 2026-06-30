// Smoke-test shader: a slow-moving radial gradient using the shared
// `iqPalette` helper from /shaders/_common.glsl. Demonstrates the
// `#include` pre-processor.

#include "../_common.glsl"

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float r = length(uv - 0.5);
    float t = iTime * 0.15;
    vec3 col = iqPalette(r + t) * smoothstep(0.7, 0.0, r);
    fragColor = vec4(col, 1.0);
}