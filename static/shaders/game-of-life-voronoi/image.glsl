// another variant of the Glow Life: https://www.shadertoy.com/view/3tSyWm
#include "common.glsl"

// Stable procedural hash. Inputs (integer cell coordinates) stay small,
// so precision issues don't show up.
vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)),
                         dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Decompose fragCoord into integer cell index (ip) and fractional
    // position within the cell (fp). Cells are CELL_SIZE pixels wide.
    vec2 x  = fragCoord / CELL_SIZE;
    vec2 ip = floor(x);
    vec2 fp = fract(x);

    float minDist = 1.0e6;
    float sumGlow = 0.0;

    // 5x5 cell neighbourhood is plenty: cells further than the
    // immediate neighbours contribute < 1 / (CELL_SIZE * sqrt(2)) to
    // sumGlow, which is negligible.
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 g  = vec2(float(i), float(j));
            vec2 o0 = hash2(ip + g);
            // Smooth slow animation: sin is C^infinitely continuous, no
            // kinks at multiples of pi. Each cell has its own phase.
            vec2 o  = 0.5 + 0.5 * sin(iTime * 0.05 + 6.28318 * o0);

            // r is the offset from fragCoord to the cell centre, in
            // cell units. Length scaled by CELL_SIZE gives pixels.
            vec2  r = g + o - fp;
            float d = length(r) * CELL_SIZE;

            // Sample buffer at the cell centre.
            vec2  cellCenterPx = (ip + g + o) * CELL_SIZE;
            vec2  cellUv       = cellCenterPx / iResolution.xy;
            float alive        = texture(iChannel0, cellUv).r;

            // Avoid division by zero at exact cell centres.
            sumGlow += alive * 0.5 / max(d, 0.001);

            if (d < minDist) {
                minDist = d;
            }
        }
    }

    float voron = 0.03 * minDist;

    float red   = voron;
    float green = voron + 1.2 * sumGlow;
    float blue  = voron;

    fragColor = vec4(red, green, blue, 1.0);
}