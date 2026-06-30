// Channel test - buffer pass.
//
// This shader is structured to give clear, distinct visual feedback
// for each engine feature being tested:
//
//   R channel: self-feedback test. We mix the previous frame's red
//              with a fresh time+space wave (5% per frame). If
//              self-feedback works, R will visibly track the wave
//              after a second or so; if broken, R stays near 0.
//
//   G channel: static vertical gradient (purely spatial, 0..1).
//
//   B channel: static horizontal gradient (purely spatial, 0..1).

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 prev = texture(iChannel0, uv);

    float newR = 0.5 + 0.5 * sin(iTime * 2.0 + uv.x * 12.566);
    float r    = mix(prev.r, newR, 0.05);

    fragColor = vec4(r, uv.y, uv.x, 1.0);
}