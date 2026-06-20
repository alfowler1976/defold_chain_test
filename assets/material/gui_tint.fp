#version 140

in mediump vec2 var_texcoord0;
in mediump vec4 var_color;

out vec4 out_fragColor;

uniform mediump sampler2D texture_sampler;

uniform fs_uniforms {
    mediump vec4 tint;
    mediump vec4 u_params;   // w = time, x/y = screen size
    mediump vec4 u_offset;  
};


// hash to pseudo-random gradient direction
vec2 grad2(vec2 p) {
    float x = fract(dot(p, vec2(127.1, 311.7)));
    float y = fract(dot(p, vec2(269.5, 183.3)));
    return normalize(vec2(x, y) * 2.0 - 1.0);
}

// smooth gradient noise
float gnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    // gradient vectors
    vec2 g00 = grad2(i);
    vec2 g10 = grad2(i + vec2(1.0, 0.0));
    vec2 g01 = grad2(i + vec2(0.0, 1.0));
    vec2 g11 = grad2(i + vec2(1.0, 1.0));

    // dot products with distance vectors
    float n00 = dot(g00, f);
    float n10 = dot(g10, f - vec2(1.0, 0.0));
    float n01 = dot(g01, f - vec2(0.0, 1.0));
    float n11 = dot(g11, f - vec2(1.0, 1.0));

    // mix
    return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y);
}

void main()
{
    // pre-multiply alpha
    mediump vec4 base = texture(texture_sampler, var_texcoord0) *
    vec4(tint.xyz * tint.w, tint.w);

  
    mediump vec2 screen_size = max(u_params.xy, vec2(1.0));
    mediump vec2 uv = gl_FragCoord.xy / screen_size;

    mediump float n = gnoise((uv * 14.0 + u_params.w * 0.25+u_offset.xy));

    mediump float strength = n * 0.40 + 0.80;

    out_fragColor = base * vec4(strength,strength,strength,1);
}
