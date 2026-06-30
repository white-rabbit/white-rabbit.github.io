#include "common.glsl"

float noise(vec2 st) {
    return fract(sin(st.x * st.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // just lazy trick to generate first state 
    // sorry
    if(iFrame == 0) { 
    	fragColor = vec4(0.0,0.0,noise(fragCoord) > 0.5,1.0);
    }
    else {
        vec4 mouse = iMouse;
        mouse.xy /= CELL_SIZE;
		
        vec2 uv = fragCoord / iResolution.xy;
        vec4 status = texture(iChannel0, uv);


        float was_alive = status.z;
        float is_alive = 0.0;
        vec2 diff = abs(fragCoord / CELL_SIZE - mouse.xy);
		
        // if left mouse button pressed
        // just freeze world and revive selected cells
        if(mouse.z > 0.0) {
            is_alive = was_alive;
            if(diff.x < 0.5 &&  diff.y < 0.5) {
                is_alive = 1.0;    
            }
        }
        else {
            if( iFrame % SLOWDOWN == 0) {
                int living_count = 0;
                for(int i = -1; i < 2; i = i + 1) {
                    for(int j = -1; j < 2; j = j + 1) {

                        float not_center = float((abs(i) + abs(j)) != 0);
                        vec2 uv_ij = (fragCoord + vec2(i, j)) / iResolution.xy;
                        vec4 status_ij = texture(iChannel0, uv_ij);

                        living_count += int(status_ij.z * not_center);
                    }
                }

                float keepAlive = float(living_count == 2 || living_count == 3);
                float revive = float(living_count == 3);

                is_alive = mix(revive, keepAlive, was_alive);
            }
            else {
                is_alive = was_alive;
            }
        }
        float delta = 0.034;
        float inertion = mix(status.r - delta, status.r + delta, is_alive);
        inertion = clamp(inertion, 0.0, 1.0);
        fragColor = vec4(inertion,was_alive,is_alive,1.0);
    }
}
