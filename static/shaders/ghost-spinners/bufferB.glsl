
vec4 apply_world(vec4 next_state, vec2 crd) {
    
    vec4 world = texture(iChannel1, crd/iResolution.xy);
    float free = 1.0 - world.x;
    next_state.zw = mix(next_state.zw, world.yz, free);
    
    float rf = 0.002 *(crd.x - iResolution.x * 0.5) / (0.5 * iResolution.x);
    
    vec2 gravity = vec2(0.0, sign(-rf));
    
    next_state.zw = mix(next_state.zw, gravity, abs(rf));
    return next_state;
}

float noise(vec2 st) {
    return fract(sin(st.x + iTime) * st.y * iTime);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = vec4(0.0,0.0,1.0,1.0);
    
    vec4 next_state = vec4(0.0, 0.0, 0.0, 0.0);
    
    for(float shifti = -1.0; shifti < 1.01; shifti += 0.6) {
        for(float shiftj = -1.0; shiftj < 1.01; shiftj += 0.6) {
            vec2 crd = fragCoord + vec2(shifti, shiftj);
            crd = vec2(mod(crd.x, iResolution.x), mod(crd.y, iResolution.y));

            vec2 uv = crd / iResolution.xy;
            
            vec4 ng = texture(iChannel0, uv);
            
            vec2 cur_move = ng.xy + ng.zw;
            
            cur_move = vec2(mod(cur_move.x, iResolution.x), mod(cur_move.y, iResolution.y));
            
            vec2 diff = abs(fragCoord - cur_move);
            
            if(diff.x <= 1.0 && diff.y <= 1.0) {
                next_state.xy = cur_move; // coord
                next_state.zw = ng.zw;    // velocity
            }
        };
    }
    

    
// original: if(distance(fragCoord, iMouse.xy) < 10.0) {
//     vec2 dir = vec2(noise(fragCoord.yy) - 0.5, noise(fragCoord.xx) - 0.5);
//     dir = normalize(dir);
//     next_state = vec4(fragCoord.x, fragCoord.y, dir);
// }
// The "emitter" lives at iEmitter, which follows the mouse only while
// the button is held. So:
//   - The emitter always emits at iEmitter (its last click position, or
//     off-canvas before any click).
//   - Moving the mouse without pressing has no effect.
//   - Pressing the button relocates the emitter to the cursor; release
//     leaves it there.
    if(distance(fragCoord, iEmitter) < 10.0) {
        vec2 dir = vec2(noise(fragCoord.yy) - 0.5, noise(fragCoord.xx) - 0.5);
        dir = normalize(dir);
        next_state = vec4(fragCoord.x, fragCoord.y, dir);
    }

    next_state = apply_world(next_state, fragCoord);
	next_state.zw *= 0.996;

    fragColor = next_state;
    
}
