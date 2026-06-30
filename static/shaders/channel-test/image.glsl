// Channel test - image pass.
// Just samples bufferA through iChannel0 and writes the result to
// the canvas. If this displays a colored gradient (green vertical,
// blue horizontal, red animated), the cross-pass channel binding
// from bufferA into image's iChannel0 is working.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);
}