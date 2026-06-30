// based on : https://www.youtube.com/watch?v=l-07BXzNdPw

float N(vec2 st) {
    float t = iTime * 0.0001;
    return fract(sin(st.x * st.x + t*t));
}

vec2 noise(vec2 st) {
    vec3 a = fract(vec3(st.xyx * vec3(123.3, 234.32, 343.21)));
    a += dot(a, a + 34.45);
    return fract(vec2(a.x * a.y, a.y * a.z));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    
    vec2 uv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    float t = iTime * 0.93;
    
    uv *= 0.6;
        
    vec2 gv = fract(uv) - 0.5;
    vec2 id = floor(uv);
    
    float minDist = 1.0e6;
    vec2 cellIndex;
    
    vec2 direction = vec2(0.0);
    
    for(float y = -1.0; y <= 1.0; y++) {
        for(float x = -1.0; x <= 1.0; x++) {
            vec2 offset = vec2(x, y);
            vec2 n = noise(id + offset);
            vec2 p = offset + sin(n * t) * 0.5;
            
            vec2 diff = gv - p;
            float d = length(diff);
            if(d < minDist) {
                minDist = d;
                cellIndex = id;
                direction = vec2(diff.y, -diff.x);
                
            }
        }
    }
    direction = normalize(direction);
    float free_space = float(minDist >= 0.1);
    
    fragColor.rgba = vec4(free_space, direction * sin(0.1 * iTime), 1.0);
    
}
