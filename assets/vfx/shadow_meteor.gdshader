shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

uniform vec4 body_color : source_color = vec4(0.004, 0.004, 0.004, 1.0);
uniform vec4 fissure_color : source_color = vec4(0.13, 0.13, 0.13, 1.0);
uniform vec4 rim_color : source_color = vec4(0.46, 0.46, 0.46, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.58;
uniform float fissure_strength : hint_range(0.0, 1.0) = 0.42;
uniform float wobble_strength : hint_range(0.0, 0.2) = 0.055;
uniform float phase = 0.0;

float hash_31(vec3 value) {
    value = fract(value * 0.1031);
    value += dot(value, value.yzx + 33.33);
    return fract((value.x + value.y) * value.z);
}

float value_noise(vec3 value) {
    vec3 cell = floor(value);
    vec3 local = fract(value);
    local = local * local * (3.0 - 2.0 * local);
    float n000 = hash_31(cell + vec3(0.0, 0.0, 0.0));
    float n100 = hash_31(cell + vec3(1.0, 0.0, 0.0));
    float n010 = hash_31(cell + vec3(0.0, 1.0, 0.0));
    float n110 = hash_31(cell + vec3(1.0, 1.0, 0.0));
    float n001 = hash_31(cell + vec3(0.0, 0.0, 1.0));
    float n101 = hash_31(cell + vec3(1.0, 0.0, 1.0));
    float n011 = hash_31(cell + vec3(0.0, 1.0, 1.0));
    float n111 = hash_31(cell + vec3(1.0, 1.0, 1.0));
    float near_z = mix(mix(n000, n100, local.x), mix(n010, n110, local.x), local.y);
    float far_z = mix(mix(n001, n101, local.x), mix(n011, n111, local.x), local.y);
    return mix(near_z, far_z, local.z);
}

float fbm(vec3 value) {
    float result = 0.0;
    float amplitude = 0.52;
    for (int octave = 0; octave < 5; octave++) {
        result += value_noise(value) * amplitude;
        value = value * 2.03 + vec3(9.2, 4.7, 7.1);
        amplitude *= 0.48;
    }
    return result;
}

void vertex() {
    float macro_wobble = sin(VERTEX.x * 4.7 + phase) * sin(VERTEX.y * 5.3 - phase * 0.7);
    macro_wobble += sin(VERTEX.z * 6.1 + phase * 1.3) * 0.55;
    VERTEX += NORMAL * macro_wobble * wobble_strength;
}

void fragment() {
    vec3 normal_direction = normalize(NORMAL);
    vec3 view_direction = normalize(VIEW);
    float surface_noise = fbm(VERTEX * 2.9 + vec3(phase, phase * 0.37, -phase * 0.61));
    float second_noise = fbm(VERTEX.zyx * 5.6 - vec3(phase * 0.4));
    float fissure = 1.0 - smoothstep(0.035, 0.13, abs(surface_noise - second_noise * 0.58 - 0.22));
    float fresnel = pow(1.0 - max(dot(normal_direction, view_direction), 0.0), 2.4);
    float wet_gloss = pow(max(dot(normal_direction, normalize(vec3(0.35, 0.82, 0.45))), 0.0), 18.0);
    vec3 color = mix(body_color.rgb, fissure_color.rgb, fissure * fissure_strength);
    color = mix(color, rim_color.rgb, clamp(fresnel * rim_strength + wet_gloss * 0.18, 0.0, 0.72));
    ALBEDO = color;
    EMISSION = vec3(0.0);
    ALPHA = body_color.a * opacity;
}
