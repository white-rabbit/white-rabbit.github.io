// another variant of the Glow Life: https://www.shadertoy.com/view/3tSyWm
#include "common.glsl"

float getGlow(vec2 cell, vec2 point) {
    vec2 cell_uv = cell / (iResolution.xy * CELL_SIZE);
    vec4 status = texture(iChannel0, cell_uv);
    float alive = status.b;
    
    vec2 diff = point - cell;
    float invSqrDist = CELL_SIZE / dot(diff, diff);
    
    return mix(0.0, invSqrDist, alive);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float sumGlow = 0.0;
    float averageArea = CELL_SIZE * GLOW_RAD_FACTOR;
    
    vec2 cell = floor(fragCoord / CELL_SIZE) * CELL_SIZE;
    cell += CELL_SIZE * 0.5;
    for(float i = -averageArea; i < averageArea + 1.0; i = i + CELL_SIZE) {
        for(float j = -averageArea; j < averageArea + 1.0; j = j + CELL_SIZE) {
            vec2 cell_ij = cell + vec2(i, j);
            sumGlow += getGlow(cell_ij, fragCoord);
        }
    }
    
    // output color
	float red = sumGlow;
    float green = sumGlow;
    float blue = 2.0 * sumGlow;
    fragColor = vec4(red, green, blue, 1.0);
}