shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;

uniform vec4 body_color : source_color = vec4(0.008, 0.008, 0.008, 1.0);
uniform vec4 edge_color : source_color = vec4(0.24, 0.24, 0.24, 1.0);
uniform vec4 gloss_color : source_color = vec4(0.38, 0.38, 0.38, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float phase = 0.0;
uniform float micro_jitter : hint_range(0.0, 0.12) = 0.055;

float hash_21(vec2 point) {
    return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 local = fract(point);
    vec2 curve = local * local * (3.0 - 2.0 * local);
    float bottom = mix(hash_21(cell), hash_21(cell + vec2(1.0, 0.0)), curve.x);
    float top = mix(hash_21(cell + vec2(0.0, 1.0)), hash_21(cell + vec2(1.0, 1.0)), curve.x);
    return mix(bottom, top, curve.y);
}

float fbm_5(vec2 point) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 5; octave++) {
        value += value_noise(point) * amplitude;
        point = point * 2.03 + vec2(19.1, 7.7);
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    float endpoint_mask = smoothstep(-0.035, 0.025, UV.y) * smoothstep(-0.035, 0.025, 1.0 - UV.y);
    float contour_noise = fbm_5(vec2(UV.y * 12.0 + phase, phase * 1.73));
    float erosion_noise = fbm_5(vec2(UV.y * 34.0 - phase * 0.7, UV.x * 7.0 + phase));
    float center_shift = (contour_noise - 0.5) * micro_jitter * endpoint_mask;
    float distance_to_core = abs((UV.x - 0.5) * 2.0 - center_shift);
    float eroded_width = mix(0.79, 0.94, contour_noise) - (erosion_noise - 0.5) * 0.075;
    float core_mask = 1.0 - smoothstep(eroded_width * 0.79, eroded_width * 0.9, distance_to_core);
    float outer_mask = 1.0 - smoothstep(eroded_width * 0.91, eroded_width, distance_to_core);
    float edge_mask = max(outer_mask - core_mask, 0.0);
    float alpha = max(core_mask, edge_mask * 0.68) * endpoint_mask * opacity;
    float edge_mix = clamp(edge_mask * 1.35, 0.0, 1.0);
    float gloss_noise = fbm_5(vec2(UV.y * 21.0 + phase * 1.31, UV.x * 5.0 - phase));
    float gloss_mask = smoothstep(0.74, 0.91, gloss_noise)
        * core_mask
        * (1.0 - smoothstep(0.05, 0.58, distance_to_core));

    vec3 black_surface = mix(body_color.rgb, edge_color.rgb, edge_mix);
    ALBEDO = mix(black_surface, gloss_color.rgb, gloss_mask * 0.62);
    ALPHA = alpha;
    EMISSION = vec3(0.0);
}
