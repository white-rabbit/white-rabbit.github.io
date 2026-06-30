const int STEPS = 180; // roughly 1 / 0.0056
float stepSize = 0.00555555; // 1.0 / STEPS
                             //
vec2 nextZ(vec2 z, vec2 z0) {
    const float c = 0.0;
    return vec2(z.x * z.x - z.y * z.y + z0.x, 2.0 * z.x * z.y + z0.y); 
}

float mandelbrot(vec2 z, vec2 z0) {    
    const float R2 = 1200.0;
    vec2 r = vec2(0.0, 0.0);
    float res = 0.0;
    for (int i = 0; i < STEPS; i++) {
        float t = float(i) * stepSize;  // equivalent of float counter
        res = t;
        z = nextZ(z, z0);
        r = z - z0;
        float dist2 = r.x * r.x + r.y * r.y;
        if (dist2 > R2) {
            break;
        }
    }
    return res;
}

float red(float i) {
    i *= 0.2;
	return sin(i * 3.14 * 10.0);   
}

 float green(float i) {
    i *= 0.5;
	return sin(i * 3.14 * 3.0);   
}

 float blue(float i) {
    i *= 1.3;
	return sin(i * 3.14 * 4.0);   
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 size = vec2(iResolution.x, iResolution.y);
    
    //z coordinate x : -1.0 .. 1.0, y : -1.0 .. 1.0
    vec2 z = 0.2 * (2.0 * (fragCoord - 0.5 * size) / size);
    float aspect = size.y / size.x;
    // y coordinate from -aspect .. aspect
    z.y *= aspect;

    // scale calculation by time
    float zeroone = 0.5 * sin(iTime * 0.1);
    float arg = zeroone * 550.0;
    float scale = pow(1.029, -arg);
    
    // dirty hack for scale increasing slow down
    if(scale > 1.0) {
        scale = pow(scale, 0.63);
    }

    // apply scale
    z = z * scale;
    
    // rotation
    float alpha = iTime * 0.13;
    float cosa = cos(alpha);
    float sina = sin(alpha);
    
    z = vec2(z.x * cosa + z.y * sina, z.y * cosa - z.x * sina);
    
    //center :: from wiki
    vec2 center = vec2(-1.88488933694469, 0.00000000081387);
    z += center;
    
    // distance to mandelbrot set
	float d = mandelbrot(z, z);
    // Output to screen
    fragColor = vec4(red(d), green(d), blue(d), 1.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
