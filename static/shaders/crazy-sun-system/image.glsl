// another variant of the Glow Life: https://www.shadertoy.com/view/3tSyWm
#include "common.glsl"


vec4 getPlanetColor(vec2 sun, vec4 sun_view, int index, vec2 pixel) {
    vec4 planet = get_coords(index);
   	vec4 view = get_view(index);

    vec2 diff = planet.xy - pixel;
    float sqrdist = dot(diff, diff);
        
    float rad = view.w;

    float planet_factor = smoothstep(0.8, 1.1, rad * rad / sqrdist);
    vec4 color;
    color.xyz = view.xyz * planet_factor;
    
    vec2 psun = sun - pixel;
    vec2 pplan = planet.xy - pixel;
    
    float lenpsun = sqrt(dot(psun, psun));
    float lenpplan = sqrt(dot(pplan, pplan));
    
    float shadow_switch =  smoothstep(-0.3, 0.3, dot(psun, pplan) / lenpsun / lenpplan);
    
    float lighting = (1.0 - SHADOW_STRENGTH) - SHADOW_STRENGTH * shadow_switch;
    
    color.xyz *= lighting;
    
    color.xyz += planet_factor * max(0.0, lighting) * sun_view.xyz * 500.0 / dot(psun, psun);
    
	color.w = planet_factor;
    return color;
}


float noise(vec2 r) {
    float alpha = atan(r.x/r.y);
    alpha *= sin(3.3434 * alpha);
    alpha += iTime;
    return 0.55 * abs(fract(2.0 * cos(15.0 * alpha)));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    
    // draw sun
    vec4 sun = get_coords(0);
    
    vec4 sun_view = get_view(0);
    
    vec2 diff = sun.xy - fragCoord;
    float sqrdist = dot(diff, diff);
    float sun_rad = sun_view.w + noise(diff);
    vec4 color = vec4(sun_view.xyz * sun_rad * sun_rad / sqrdist, 1.0);
    
    float pixel_inside_planet = 0.0;	
    // draw planets
    for(int i = 1; i < N; ++i) {
        vec4 planet_data = getPlanetColor(sun.xy, sun_view, i, fragCoord);
        color.xyz += planet_data.xyz;
        pixel_inside_planet = max(pixel_inside_planet, planet_data.w);
    }
    
fragColor = color;
	
	vec2 uv = fragCoord / iResolution.xy;
    // Smooth mask: trails fade gradually into the planet instead of being
    // hard-clipped at the planet edge, so the halo around each planet
    // shows the trail blending into the planet body.
    // original: fragColor += texture(iChannel1, uv) * (1.0 - pixel_inside_planet);
    fragColor += texture(iChannel1, uv) * smoothstep(0.0, 0.3, 1.0 - pixel_inside_planet);
}
