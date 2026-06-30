#include "common.glsl"

// track handling

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    
    if(iMouse.z > 0.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 0.0);
    }
    else {
        fragColor = texture(iChannel1, uv);
        fragColor.xyz -= vec3(TRACK_DIFF) * (fragColor.x + fragColor.y + fragColor.z);
        fragColor.xyz = max(fragColor.xyz, vec3(0.0, 0.0, 0.0));
        for(int i = 1; i < N; ++i) {
            vec4 p = get_coords(i);
            vec4 view = get_view(i);
            vec2 pos = p.xy;
            vec2 diff = abs(pos - fragCoord);
            float dist = dot(diff, diff);
            // Wider, smoother trails: sqrt(dist) instead of dist makes the
            // intensity fall off as 1/r rather than 1/r², so the trails
            // remain visible for many more pixels around each planet.
            // original: float intensity = min(1.0 / (18.0 * max(0.2, dist)), 1.0);
            float intensity = min(1.0 / (2.0 * max(0.2, sqrt(dist))), 1.0);
            fragColor.xyz += view.xyz * intensity;
        }
        fragColor.xyz = min(vec3(1.0), fragColor.xyz);

    }
}
