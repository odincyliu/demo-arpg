shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 body_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 ash_color : source_color = vec4(0.28, 0.28, 0.28, 1.0);
uniform vec4 rim_color : source_color = vec4(0.68, 0.68, 0.68, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.68;
uniform float sweep_progress : hint_range(0.0, 1.0) = 0.0;
uniform float sweep_direction : hint_range(-1.0, 1.0) = 1.0;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;

float hash_21(vec2 point) {
    return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 blend = fract(point);
    blend = blend * blend * (3.0 - 2.0 * blend);
    float bottom = mix(hash_21(cell), hash_21(cell + vec2(1.0, 0.0)), blend.x);
    float top = mix(hash_21(cell + vec2(0.0, 1.0)), hash_21(cell + vec2(1.0)), blend.x);
    return mix(bottom, top, blend.y);
}

void fragment() {
    float along = mix(UV.x, 1.0 - UV.x, step(sweep_direction, 0.0));
    float reveal = 1.0 - smoothstep(
        sweep_progress - 0.055,
        sweep_progress + 0.025,
        along
    );
    float tip_taper = pow(max(sin(UV.x * 3.14159265), 0.0), 0.42);
    float flow_noise = value_noise(vec2(
        UV.x * 12.0 - TIME * 2.8,
        UV.y * 5.0 + phase
    ));
    float trailing_fray = smoothstep(0.0, 0.2, UV.y + (flow_noise - 0.5) * 0.24);
    float front_feather = 1.0 - smoothstep(0.86, 1.0, UV.y);
    float inner_current = sin(UV.x * 18.0 - TIME * 15.0 + phase) * 0.5 + 0.5;
    float charcoal_current = inner_current * flow_noise * 0.32;
    float erosion_noise = value_noise(vec2(
        UV.x * 10.0 + phase,
        UV.y * 6.5 - phase * 0.31
    ));
    float erosion_field = erosion_noise * 0.72 + UV.y * 0.28;
    float erosion_threshold = dissolve_progress * 1.15 - 0.08;
    float survives_erosion = smoothstep(
        erosion_threshold - 0.06,
        erosion_threshold + 0.06,
        erosion_field
    );
    float erosion_edge = (
        1.0 - smoothstep(0.018, 0.075, abs(erosion_field - erosion_threshold))
    ) * step(0.002, dissolve_progress) * survives_erosion;
    float mask = tip_taper * reveal * survives_erosion * trailing_fray * front_feather;
    vec3 charcoal = ash_color.rgb * 0.16;
    vec3 blade_color = mix(body_color.rgb, charcoal, charcoal_current);
    blade_color = mix(blade_color, body_color.rgb, erosion_edge * 0.35);
    ALBEDO = blade_color;
    EMISSION = vec3(0.0);
    ALPHA = mask * opacity;
}
