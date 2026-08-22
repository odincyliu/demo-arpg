shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, skip_vertex_transform;

group_uniforms Animation;
uniform float progress : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float sweep_direction : hint_range(-1.0, 1.0, 1.0) = 1.0;
uniform float dissolve_progress : hint_range(0.0, 1.0, 0.01) = 0.0;
group_uniforms Shape;
uniform sampler2D base_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D width_gradient_mask : hint_default_transparent;
uniform sampler2D length_gradient_mask : hint_default_transparent, repeat_enable;
uniform sampler2D highlight : hint_default_transparent;
uniform float zoom : hint_range(0.1, 2.0, 0.01) = 0.62;
uniform float rotate_all : hint_range(-720.0, 720.0, 0.1) = 285.0;
uniform float animation_rotation : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float phase = 0.0;
group_uniforms Coloring;
uniform sampler2D color_lookup : source_color, hint_default_white;
uniform vec4 body_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 ash_color : source_color = vec4(0.28, 0.28, 0.28, 1.0);
uniform vec4 rim_color : source_color = vec4(0.68, 0.68, 0.68, 1.0);
uniform float emission_strength : hint_range(0.0, 2.0, 0.01) = 0.18;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;


vec2 polar_coordinates(vec2 uv, vec2 center, float radial_zoom) {
    vec2 direction = uv - center;
    float radius = length(direction) * 2.0;
    float angle = atan(direction.y, direction.x) / TAU;
    return mod(vec2(radius * radial_zoom, angle), 1.0);
}


vec2 rotate_uv(vec2 uv, vec2 pivot, float angle) {
    float sine = sin(angle);
    float cosine = cos(angle);
    mat2 rotation = mat2(vec2(cosine, -sine), vec2(sine, cosine));
    return (uv - pivot) * rotation + pivot;
}


float ease_in_out_circ(float value) {
    if (value < 0.5) {
        return (1.0 - sqrt(1.0 - pow(2.0 * value, 2.0))) * 0.5;
    }
    return (sqrt(1.0 - pow(-2.0 * value + 2.0, 2.0)) + 1.0) * 0.5;
}


// CC0 Material Maker material 376 uses circle-mapped FBM, an emphasized
// outer ring and slope blur. This runtime form keeps those ideas procedural
// while sharing the same polar space as the cyclic slash.
float circular_erosion(vec2 polar_uv, float phase_offset) {
    vec2 noise_uv = polar_uv * vec2(1.15, 2.0) + vec2(phase_offset, 0.0);
    float noise_center = texture(base_noise, noise_uv).r;
    float noise_inner = texture(base_noise, noise_uv - vec2(0.018, 0.0)).r;
    float noise_outer = texture(base_noise, noise_uv + vec2(0.018, 0.0)).r;
    float slope_blur = mix(noise_center, max(noise_center, max(noise_inner, noise_outer)), 0.48);
    float ring_band = smoothstep(0.20, 0.255, polar_uv.x)
        * (1.0 - smoothstep(0.63, 0.71, polar_uv.x));
    float outer_edge = smoothstep(0.51, 0.60, polar_uv.x)
        * (1.0 - smoothstep(0.69, 0.76, polar_uv.x));
    return clamp(slope_blur * mix(0.82, 1.0, ring_band) + outer_edge * 0.16, 0.0, 1.0);
}


void vertex() {
    vec3 world_center = MODEL_MATRIX[3].xyz;
    vec3 camera_right = INV_VIEW_MATRIX[0].xyz;
    vec3 camera_up = INV_VIEW_MATRIX[1].xyz;
    vec3 world_position = world_center + camera_right * VERTEX.x + camera_up * VERTEX.y;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_position, 1.0);
}


void fragment() {
    float p = clamp(progress, 0.0, 1.0);
    float signed_progress = p * sweep_direction;
    vec2 rotated_uv = rotate_uv(UV, vec2(0.5), radians(rotate_all));
    vec2 polar_uv = polar_coordinates(rotated_uv, vec2(0.5), zoom);
    vec4 noise_sample = texture(base_noise, polar_uv - vec2(phase, signed_progress));
    float width_cut = texture(width_gradient_mask, polar_uv).r;
    vec2 length_uv = polar_uv - vec2(0.0, ease_in_out_circ(p) * animation_rotation * sweep_direction);
    length_uv = rotate_uv(length_uv, vec2(0.5), PI);
    float length_cut = texture(length_gradient_mask, length_uv).r;
    float shape_field = noise_sample.r - width_cut - length_cut;
    float color_index = clamp(shape_field * rotated_uv.x, 0.0, 1.0);
    vec3 lookup_color = texture(color_lookup, vec2(color_index, 0.5)).rgb;
    float highlight_field = clamp(texture(highlight, polar_uv).r - length_cut, 0.0, 1.0);

    float arc_center = fract(0.5 + signed_progress * 0.16);
    float arc_distance = abs(polar_uv.y - arc_center);
    arc_distance = min(arc_distance, 1.0 - arc_distance);
    float arc_mask = 1.0 - smoothstep(0.205, 0.255, arc_distance);

    float threshold = abs(cos(p * PI));
    float shape_alpha = smoothstep(threshold - 0.045, threshold + 0.045, shape_field) * arc_mask;
    float highlight_alpha = smoothstep(
        clamp(threshold - 0.13, 0.0, 1.0),
        clamp(threshold + 0.02, 0.001, 1.0),
        highlight_field * 0.24
    ) * arc_mask;
    float dissolve_noise = circular_erosion(polar_uv, phase);
    float survives_dissolve = smoothstep(
        dissolve_progress - 0.08,
        dissolve_progress + 0.08,
        dissolve_noise
    );
    float alpha_mask = clamp(shape_alpha + highlight_alpha, 0.0, 1.0) * survives_dissolve;
    vec3 tonal_color = mix(body_color.rgb, lookup_color, clamp(shape_field * 1.8, 0.0, 1.0));
    tonal_color = mix(tonal_color, ash_color.rgb, highlight_field * 0.56);
    tonal_color = mix(tonal_color, rim_color.rgb, highlight_alpha * 0.38);

    ALBEDO = tonal_color;
    EMISSION = tonal_color * emission_strength;
    ALPHA = alpha_mask * opacity;
}
