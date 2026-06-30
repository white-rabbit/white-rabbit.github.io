const int N = 9;

const float USE_AUTO_CENTERING = 1.0; // 0.0 for disable this
const float USE_PBC = 1.0; // 0.0 for disable this

const float SHADOW_STRENGTH = 0.2;
const float TRACK_STRENGTH = 0.5;
const float TRACK_TIME = 1000.0;
const float TRACK_DIFF = 1.0 / TRACK_TIME;

const float DT = 0.025;
const float PLANET_SCALE = 2.4;
const float G = 1.0;

const float TSHIFT = 0.1;


#define get_coords(index) texture(iChannel0,vec2(TSHIFT,float(index)+TSHIFT)/iResolution.xy);
#define get_prevc(index) texture(iChannel0,vec2(1.0 + TSHIFT,float(index)+TSHIFT)/iResolution.xy);
#define get_view(index) texture(iChannel0,vec2(2.0 + TSHIFT,float(index)+TSHIFT)/iResolution.xy);
#define get_data(index) texture(iChannel0,vec2(3.0 + TSHIFT,float(index)+TSHIFT)/iResolution.xy);
