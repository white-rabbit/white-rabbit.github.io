void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec4 prevValue = texture(iChannel1, fragCoord / iResolution.xy);
    
    float lightness = 0.0;
    
    float vel = 0.0;
    for(float shifti = -1.0; shifti < 1.01; shifti += 1.0) {
        for(float shiftj = -1.0; shiftj < 1.01; shiftj += 1.0) {
            vec2 uv = (fragCoord + vec2(shifti, shiftj)) / iResolution.xy;
            vec4 photon = texture(iChannel0, uv);
            float cur_vel = length(photon.zw);
            lightness += cur_vel * 0.1 / distance(fragCoord, photon.xy);
            
            vel = max(vel, cur_vel);
        }
    }
	
    vel = min(vel, 1.0);
    float no_ball = texture(iChannel2, fragCoord / iResolution.xy).r;
    fragColor = prevValue + lightness *  vec4(vel, 0.5 * vel, (1.0 - vel), 1.0);
    
    fragColor -= vec4(0.04);
    fragColor = max(vec4(0.0), fragColor);
    fragColor = min(vec4(1.0), fragColor);
    
    fragColor = mix(vec4(0.3, 0.5, 0.6, 1.0), fragColor, 1.0);

}
