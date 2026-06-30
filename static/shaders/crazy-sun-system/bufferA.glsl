#include "common.glsl"

float noise(vec2 st) {
    return abs(fract(100.0 * sin(-130.0 + 0.0001 * -iTime * st.x * st.y)));
}


float calc_velocity(float dist, float star_mass) {
    return sqrt(star_mass * G / dist);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    if(iFrame == 0) {
        int index = int(fragCoord.y + TSHIFT);
        
        if(index < N) {
            int cindex = int(fragCoord.x + TSHIFT);
            
            vec2 crd = vec2(0.0, 0.0);
            vec2 vel = vec2(0.0, 0.0);
            
            // color + rad
            vec4 view = vec4(0.0, 1.0, 0.0, 1.0);
            vec4 data = vec4(1000.0, 0.0, 0.0, 0.0);
            
            
            
            float width = iResolution.x;
            float height = iResolution.y;
            
            float sun_mass = 1000000.0;
            float sun_x = 0.5 * width;
            float sun_y = 0.5 * height;
            
            // sun
            if(index == 0) {
                crd = vec2(sun_x, 0.5 * height);
                view = vec4(1.4, 0.95,0.675, 10.0);
                data.x = sun_mass;
            }
            
            float AU = width / 5.0;
            
            // mercury
            if(index == 1) {
                float planet_x = sun_x - AU * 0.3871;
                
                crd = vec2(planet_x, 0.5 * height);
                float dist = abs(sun_x - planet_x);
                vel = vec2(0.0, calc_velocity(dist, sun_mass));
                           
                view = vec4(1.0, 0.85, 0.675, 1.5);
            }
            
            // venus
            if(index == 2) {
                float planet_y = sun_y + AU * 0.7232;;
                crd = vec2(0.5 * width, planet_y);
                float dist = abs(sun_y - planet_y);
                vel = vec2(calc_velocity(dist, sun_mass), 0.0);
				
                data = vec4(2000.0, 0.0, 0.0, 0.0);
                view = vec4(0.6, 0.85, 0.675, 4.0);
            }
            
            // earth
            if(index == 3) {
                float planet_x = sun_x + AU;
                crd = vec2(planet_x, 0.5 * height);
                float dist = abs(sun_x - planet_x);
                vel = vec2(0.0, -calc_velocity(dist, sun_mass));
                
                view = vec4(0.0, 0.65, 0.975, 4.5);
                data = vec4(4000.0, 0.0, 0.0, 0.0);

            }
            
            // mars
            if(index == 4) {
                float planet_y = sun_y - AU * 1.5236;
                crd = vec2(0.5 * width, planet_y);
                float dist = abs(sun_y - planet_y);
                vel = vec2(-calc_velocity(dist, sun_mass), 0.0);
                
                view = vec4(1.0, 0.385, 0.375, 3.0);
                data = vec4(2000.0, 0.0, 0.0, 0.0);

            }
			
            
            // mercury 2
            if(index == 5) {
                float planet_x = sun_x - AU * 1.8871;
                
                crd = vec2(planet_x, 0.5 * height);
                float dist = abs(sun_x - planet_x);
                vel = vec2(0.0, calc_velocity(dist, sun_mass));
                           
                view = vec4(0.0, 0.85, 1.0, 1.5);
            }
            
             // venus 2
            if(index == 6) {
                float planet_y = sun_y + AU * 2.0;
                crd = vec2(0.5 * width, planet_y);
                float dist = abs(sun_y - planet_y);
                vel = vec2(calc_velocity(dist, sun_mass), 0.0);
				
                data = vec4(2000.0, 0.0, 0.0, 0.0);
                view = vec4(0.0, 0.85, 0.0, 4.0);
            }
            
            // earth 2
            if(index == 7) {
                float planet_x = sun_x + AU * 2.234;
                crd = vec2(planet_x, 0.5 * height);
                float dist = abs(sun_x - planet_x);
                vel = vec2(0.0, -calc_velocity(dist, sun_mass));
                
                view = vec4(1.0, 1.0, 1.0, 3.5);
                data = vec4(5000.0, 0.0, 0.0, 0.0);

            }
            
            // mars 2
            if(index == 8) {
                float planet_y = sun_y + AU * 2.2236;
                crd = vec2(0.5 * width, planet_y);
                float dist = abs(sun_y - planet_y);
                vel = vec2(-calc_velocity(dist, sun_mass), 0.0);
                
                view = vec4(0.3, 0.3, 0.3, 5.0);
                data = vec4(2000.0, 0.0, 0.0, 0.0);

            }
			
            
            view.w *= PLANET_SCALE;
            
            switch(cindex) {
                // coordinates
            	case 0: fragColor = vec4(crd ,vel); break;
                // prev coordinates
                case 1: fragColor = vec4(crd ,vel); break;
                // view
                case 2: fragColor = view;        break;
                // other data, mass etc
                case 3: fragColor = data;        break;

            }
            
        }
    }
    else {
        int index = int(fragCoord.y + TSHIFT);
        int cindex = int(fragCoord.x + TSHIFT);
                
        if(index < N && (cindex < 4)) {
			vec4 cur_planet = get_coords(index);
            vec4 cur_view = get_view(index);
            vec4 cur_data = get_data(index);
			
            // mouse control:
            // mouse xy - is the mouse current position
            // mouse zw - is the mouse last position before button pressing
            // mouse zw is negative while not pressing,
            // mouse z becomes positive when the left mouse is pressed
            // mouse w becomes positive when the right mouse is pressed
            // so abs(iMouze.zw) is the position before mouse is pressed!
            if( iMouse.z > 0.0) {
                 int mouse_on_index = -1;
                
                 // searching for covered plantet
                 for(int i = 0; i < N; i++) {
                     // prev planet position is the position before dragging
                     vec4 pi = get_prevc(i);
                 	 vec2 pos_i = pi.xy;
                     // abs(iMouse.zw) is the mouse position before dragging
                     vec2 diff = abs(iMouse.zw) - pos_i;
                     
                     if(dot(diff, diff) < 300.0) {
                     	mouse_on_index = i;    
                     }
                 }
                 
                // if there is no covered planets - move all
                // move only found one otherwise 
                if(cindex == 0 && (mouse_on_index == -1 || mouse_on_index == index)) {
                    vec2 dmouse = iMouse.xy - abs(iMouse.zw);
                    
                    // use prev coord to
                    vec4 prev_pos = get_prevc(index);
                  
                    prev_pos.xy += dmouse;

                    fragColor = prev_pos;
                    
                }
                else {
                	fragColor = texture(iChannel0, fragCoord / iResolution.xy); 
                }
            }
            else {
                // calcluate the next position
                // (prev is used only for correct mouse control)
                if(cindex < 2) {
                    cur_planet.xy += DT * cur_planet.zw;

                    for(int j = 0; j < N; j++) {
                        if(j != index) {
                            vec4 pj = get_coords(j);
                            vec2 pos_j = pj.xy;
							vec4 view_j = get_view(j);
							vec4 data_j = get_data(j);

                            float mass_j = data_j.x;

                            vec2 rij = pos_j - cur_planet.xy;

                            float dist = sqrt(dot(rij, rij));

                            vec2 accel = G * mass_j * rij / (dist * dist * dist);
							
                            // simple collision handling
                            float maxdist = 0.5 * (cur_view.w + view_j.w) * PLANET_SCALE;
                            float collision_factor = sign(dist - maxdist);

                            accel *= collision_factor;
                            
                            // apply calculated acceleration
                            cur_planet.zw += accel * DT;
                        }
                    }
                }
                
                // auto centering
                vec4 sun = get_coords(0);
                vec2 diff = iResolution.xy * 0.5 - sun.xy;
                
                vec2 shift = 0.005 * diff;
                
                cur_planet.xy += shift * USE_AUTO_CENTERING;
                
                // periodic boundary conditions
                float rx = iResolution.x;
                float ry = iResolution.y;
                cur_planet.x += rx * float(cur_planet.x < 0.0) * USE_PBC;
                cur_planet.y += ry * float(cur_planet.y < 0.0) * USE_PBC;
                cur_planet.x -= rx * float(cur_planet.x > rx) * USE_PBC;
                cur_planet.y -= ry * float(cur_planet.y > ry) * USE_PBC;

                switch(cindex) {
                    case 0: fragColor = cur_planet; break;
                    // copy the last calculated position
                    case 1: fragColor = cur_planet; break;
                    case 2: fragColor = cur_view; break;
                    case 3: fragColor = cur_data; break;
                }
            }
            
        }
        else {
       		fragColor = texture(iChannel0, fragCoord / iResolution.xy); 
        }        
    }
}
