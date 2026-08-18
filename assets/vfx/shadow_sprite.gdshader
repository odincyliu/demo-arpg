shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform vec4 body_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 ash_color : source_color = vec4(0.28, 0.28, 0.28, 1.0);
uniform vec4 rim_color : source_color = vec4(0.68, 0.68, 0.68, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.72;
uniform float phase = 0.0;

void vertex() {
    float sway = sin(TIME * 8.0 + VERTEX.y * 8.0 + phase) * 0.012;
    VERTEX.x += sway;
}

void fragment() {
    vec4 source = texture(source_texture, UV);
    float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
    float ash_mix = smoothstep(0.18, 0.78, luminance) * 0.58;
    float rim = pow(clamp(luminance, 0.0, 1.0), 3.0) * rim_strength;
    ALBEDO = mix(body_color.rgb, ash_color.rgb, ash_mix);
    EMISSION = rim_color.rgb * rim * 0.72;
    ALPHA = source.a * opacity;
}
