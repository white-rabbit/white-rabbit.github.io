const float GLOW_RAD_FACTOR = 2.0;
const float CELL_SIZE_FACTOR = 75.0;
const float SIZE = 71.0;
const float GLOBAL_CRD = 100.0;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float CELL_SIZE = iResolution.y / CELL_SIZE_FACTOR;

    // move the image to the center of the framebuffer
    float center_x = iResolution.x * 0.5 - 36.5 * CELL_SIZE;
    float center_y = iResolution.y * 0.5 - 36.5 * CELL_SIZE;
    vec2 center = vec2(center_x, center_y);

    // The maze is anchored at the bottom-left of bufferA. Screen pixels
    // outside the centered maze rectangle would otherwise fall through
    // the clamp-to-edge sampler and pick up the maze's corner wall,
    // painting the bottom-left of the screen dark. Force the background
    // color for any pixel that isn't inside the maze.
    float halfMaze = 36.5 * CELL_SIZE;
    vec2 dev = abs(fragCoord - iResolution.xy * 0.5);
    if (dev.x > halfMaze || dev.y > halfMaze) {
        fragColor = vec4(0.6627, 0.8705, 0.9764, 1.0);
        return;
    }

    // UV for the input texture should be from 0 to 1 to use the sampler
    vec2 uv = (fragCoord - center) /(iResolution.xy * CELL_SIZE);
    
    vec4 maze = texture(iChannel0, uv);

    float wall = float(maze.x > 0.6);
    float isBFS = float(maze.w > 0.4);
    float isPath = float(maze.z > 0.8);
    fragColor = vec4(wall, isBFS, isPath, 1.0);
    
    vec4 bgColor = vec4(0.6627, 0.8705, 0.9764, 1.0); 
    vec4 wallColor = 0.1 * vec4(0.9882,  0.9647, 0.7411, 1.0);
    vec4 bfsColor = vec4(0.7156, 0.9568, 0.7705, 1.0);
    vec4 pathColor = vec4(1.0, 0.2, 0.2843, 1.0);
    
    fragColor = mix(bgColor, wallColor * wall * wall, wall);
    fragColor = mix(fragColor, bfsColor, isBFS);
    fragColor = mix(fragColor, pathColor, isPath);
}
