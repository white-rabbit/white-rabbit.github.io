// Shared shader helpers. Included via `#include "../_common.glsl"`
// from any .glsl file inside /shaders/<name>/.
//
// Rules:
//   * Do NOT define `void mainImage(...)` or `void main()` here.
//   * Keep everything `precision highp float;`-clean (no declarations
//     that conflict with the engine preamble).
//   * Functions may be top-level; constants and helpers only.

// Iñigo Quílez-style palette: https://iquilezles.org/articles/palettes/
vec3 iqPalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318530718 * (c * t + d));
}

vec3 iqPalette(float t) {
    return iqPalette(
        t,
        vec3(0.5, 0.5, 0.5),
        vec3(0.5, 0.5, 0.5),
        vec3(1.0, 1.0, 1.0),
        vec3(0.0, 0.33, 0.67)
    );
}

// Cheap value noise based on fract(sin(...)). Good enough for procedural
// textures; not suitable for production work.
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}