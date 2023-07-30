//!HOOK OUTPUT
//!BIND OUTPUT
//!BIND MAIN

// Tunable parameters
#define BRIGHT_BOOST 1.5
#define DILATION 1.0
#define GAMMA_INPUT 2.4
#define GAMMA_OUTPUT 1.1
#define MASK_SIZE 1.0
#define MASK_STAGGER 0
#define MASK_STRENGTH 0.3
#define MASK_DOT_HEIGHT 1.0
#define MASK_DOT_WIDTH 1
#define SCANLINE_BEAM_WIDTH_MAX 1.5
#define SCANLINE_BEAM_WIDTH_MIN 1.5
#define SCANLINE_BRIGHT_MAX 0.65
#define SCANLINE_BRIGHT_MIN 0.35
#define SCANLINE_CUTOFF 400.0
#define SCANLINE_STRENGTH 1.0
#define SHARPNESS_H 0.5
#define SHARPNESS_V 1.0

#define PI 3.141592653589

const vec2 sharp = vec2(SHARPNESS_H, SHARPNESS_V);

vec4 hook()
{
    vec2 fcoord = fract(MAIN_pos * MAIN_size - vec2(0.5));
    vec2 base   = MAIN_pos - MAIN_pt * fcoord;

    // Apply half-circle S-Curve to distance for sharper interpolation
    vec2 fstep  = step(0.5, fcoord);
    vec2 fcurve = fcoord - fstep;
    fcurve = vec2(0.5) - sqrt(vec2(0.25) - fcurve * fcurve) * sign(vec2(0.5) - fcoord);
    fcoord = mix(fcoord, fcurve, sharp);

    vec4 color = MAIN_tex(base + MAIN_pt * fcoord);
    color.rgb = pow(color.rgb, vec3(GAMMA_INPUT / (DILATION + 1.0)));

    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float bright = (max(color.r, max(color.g, color.b)) + luma) / 2.0;
    float scan_bright = clamp(bright, SCANLINE_BRIGHT_MIN, SCANLINE_BRIGHT_MAX);
    float scan_beam = clamp(bright * SCANLINE_BEAM_WIDTH_MAX, SCANLINE_BEAM_WIDTH_MIN, SCANLINE_BEAM_WIDTH_MAX);
    float scan_weight = 1.0 - pow(cos(MAIN_pos.y * 2.0 * PI * MAIN_size.y) * 0.5 + 0.5, scan_beam) * SCANLINE_STRENGTH;

    if (MAIN_size.y >= SCANLINE_CUTOFF)
        scan_weight = 1.0;

    vec3 orig = color.rgb;
    color.rgb *= vec3(scan_weight);
    color.rgb = mix(color.rgb, orig, scan_bright);

    float mask = 1.0 - MASK_STRENGTH;
    ivec2 mod_fac = ivec2(MAIN_pos * OUTPUT_size / vec2(MASK_SIZE, MASK_DOT_HEIGHT * MASK_SIZE));
    int dot_no = (mod_fac.x + (mod_fac.y % 2) * MASK_STAGGER) / MASK_DOT_WIDTH % 3;

    vec3 mask_weight = vec3(mask);
    mask_weight[dot_no] = 1.0;
    color.rgb *= mask_weight;

    color.rgb = pow(color.rgb, vec3(1.0 / GAMMA_OUTPUT));
    color.rgb *= BRIGHT_BOOST;
    return color;
}