shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 body_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 rim_color : source_color = vec4(0.68, 0.68, 0.68, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.62;
uniform float wobble_strength : hint_range(0.0, 0.2) = 0.02;
uniform float phase = 0.0;

void vertex() {
    float wave = sin(TIME * 7.0 + VERTEX.y * 5.0 + VERTEX.x * 3.0 + phase);
    VERTEX += NORMAL * wave * wobble_strength;
}

void fragment() {
    float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.35);
    float pulse = 0.88 + sin(TIME * 9.0 + phase) * 0.08;
    float rim = clamp(fresnel * rim_strength * pulse, 0.0, 1.0);
    ALBEDO = mix(body_color.rgb, rim_color.rgb, rim);
    EMISSION = rim_color.rgb * rim * 0.55;
    ALPHA = body_color.a * opacity;
}
