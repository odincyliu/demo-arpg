class_name ShadowVfxStyle
extends RefCounted

const SHADOW_MESH_SHADER := preload("res://assets/vfx/shadow_mesh.gdshader")
const SHADOW_SPRITE_SHADER := preload("res://assets/vfx/shadow_sprite.gdshader")
const SHADOW_SLASH_WAVE_SHADER := preload("res://assets/vfx/shadow_slash_wave.gdshader")
const SHADOW_CYCLIC_SLASH_SHADER := preload("res://assets/vfx/shadow_cyclic_slash.gdshader")
const SHADOW_CHAIN_LIGHTNING_SHADER := preload("res://assets/vfx/shadow_chain_lightning.gdshader")
const SHADOW_METEOR_SHADER := preload("res://assets/vfx/shadow_meteor.gdshader")

const BODY := Color(0.02, 0.02, 0.02, 1.0)
const SHADOW := Color(0.07, 0.07, 0.07, 1.0)
const ASH := Color(0.28, 0.28, 0.28, 1.0)
const RIM := Color(0.68, 0.68, 0.68, 1.0)
const FLASH := Color(0.9, 0.9, 0.9, 1.0)

static var _cyclic_base_noise: NoiseTexture2D
static var _cyclic_width_mask: GradientTexture1D
static var _cyclic_length_mask: GradientTexture1D
static var _cyclic_highlight: GradientTexture1D
static var _cyclic_color_lookup: GradientTexture1D


static func tone(role: StringName) -> Color:
    match role:
        &"body":
            return BODY
        &"shadow":
            return SHADOW
        &"ash":
            return ASH
        &"flash":
            return FLASH
        _:
            return RIM


static func neutralize(source: Color, role: StringName = &"rim") -> Color:
    var base := tone(role)
    var intensity := clampf((source.r + source.g + source.b) / 3.0, 0.25, 1.0)
    return Color(base.r * intensity, base.g * intensity, base.b * intensity, source.a)


static func mesh_material(
        role: StringName = &"body",
        alpha: float = 1.0,
        wobble: float = 0.02,
        rim_strength: float = 0.62
) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = SHADOW_MESH_SHADER
    material.set_shader_parameter("body_color", tone(role))
    material.set_shader_parameter("rim_color", RIM)
    material.set_shader_parameter("opacity", alpha)
    material.set_shader_parameter("wobble_strength", wobble)
    material.set_shader_parameter("rim_strength", rim_strength)
    material.set_shader_parameter("phase", randf_range(0.0, TAU))
    return material


static func sprite_material(
        texture: Texture2D,
        role: StringName = &"body",
        alpha: float = 1.0,
        rim_strength: float = 0.72
) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = SHADOW_SPRITE_SHADER
    material.set_shader_parameter("source_texture", texture)
    material.set_shader_parameter("body_color", tone(role))
    material.set_shader_parameter("ash_color", ASH)
    material.set_shader_parameter("rim_color", RIM)
    material.set_shader_parameter("opacity", alpha)
    material.set_shader_parameter("rim_strength", rim_strength)
    material.set_shader_parameter("phase", randf_range(0.0, TAU))
    return material


static func slash_wave_material(
        alpha: float = 1.0,
        rim_strength: float = 0.0
) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = SHADOW_SLASH_WAVE_SHADER
    material.set_shader_parameter("body_color", BODY)
    material.set_shader_parameter("ash_color", ASH)
    material.set_shader_parameter("rim_color", RIM)
    material.set_shader_parameter("opacity", alpha)
    material.set_shader_parameter("rim_strength", rim_strength)
    material.set_shader_parameter("sweep_progress", 0.0)
    material.set_shader_parameter("sweep_direction", 1.0)
    material.set_shader_parameter("dissolve_progress", 0.0)
    material.set_shader_parameter("phase", randf_range(0.0, TAU))
    return material


static func cyclic_slash_material(alpha: float = 1.0) -> ShaderMaterial:
    _ensure_cyclic_slash_textures()
    var material := ShaderMaterial.new()
    material.shader = SHADOW_CYCLIC_SLASH_SHADER
    material.set_shader_parameter("base_noise", _cyclic_base_noise)
    material.set_shader_parameter("width_gradient_mask", _cyclic_width_mask)
    material.set_shader_parameter("length_gradient_mask", _cyclic_length_mask)
    material.set_shader_parameter("highlight", _cyclic_highlight)
    material.set_shader_parameter("color_lookup", _cyclic_color_lookup)
    material.set_shader_parameter("body_color", BODY)
    material.set_shader_parameter("ash_color", ASH)
    material.set_shader_parameter("rim_color", RIM)
    material.set_shader_parameter("emission_strength", 0.18)
    material.set_shader_parameter("opacity", alpha)
    material.set_shader_parameter("progress", 0.0)
    material.set_shader_parameter("dissolve_progress", 0.0)
    material.set_shader_parameter("phase", randf_range(0.0, 1.0))
    return material


static func chain_lightning_material(alpha: float = 1.0, phase: float = 0.0) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = SHADOW_CHAIN_LIGHTNING_SHADER
    material.set_shader_parameter("body_color", Color(0.008, 0.008, 0.008, 1.0))
    material.set_shader_parameter("edge_color", Color(0.24, 0.24, 0.24, 1.0))
    material.set_shader_parameter("gloss_color", Color(0.38, 0.38, 0.38, 1.0))
    material.set_shader_parameter("opacity", alpha)
    material.set_shader_parameter("phase", phase)
    material.set_shader_parameter("micro_jitter", 0.055)
    return material


static func meteor_material(
        alpha: float = 1.0,
        phase: float = 0.0,
        rim_strength: float = 0.58,
        fissure_strength: float = 0.42
) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = SHADOW_METEOR_SHADER
    material.set_shader_parameter("body_color", Color(0.004, 0.004, 0.004, 1.0))
    material.set_shader_parameter("fissure_color", Color(0.13, 0.13, 0.13, 1.0))
    material.set_shader_parameter("rim_color", Color(0.46, 0.46, 0.46, 1.0))
    material.set_shader_parameter("opacity", alpha)
    material.set_shader_parameter("phase", phase)
    material.set_shader_parameter("rim_strength", rim_strength)
    material.set_shader_parameter("fissure_strength", fissure_strength)
    return material


static func standard_material(
        role: StringName = &"rim",
        alpha: float = 1.0,
        emission_energy: float = 0.0
) -> StandardMaterial3D:
    var color := tone(role)
    color.a = alpha
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if alpha < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if emission_energy > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = emission_energy
    return material


static func _ensure_cyclic_slash_textures() -> void:
    if _cyclic_base_noise != null:
        return

    var noise := FastNoiseLite.new()
    noise.seed = 17357
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.032
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 5
    noise.fractal_lacunarity = 2.0
    noise.fractal_gain = 0.75
    _cyclic_base_noise = NoiseTexture2D.new()
    _cyclic_base_noise.width = 512
    _cyclic_base_noise.height = 128
    _cyclic_base_noise.seamless = true
    _cyclic_base_noise.generate_mipmaps = true
    _cyclic_base_noise.noise = noise

    _cyclic_width_mask = _gradient_texture(
        PackedFloat32Array([0.12, 0.3, 0.56, 0.74]),
        PackedColorArray([Color.WHITE, Color.BLACK, Color.BLACK, Color.WHITE])
    )
    _cyclic_length_mask = _gradient_texture(
        PackedFloat32Array([0.25, 0.4, 0.6, 0.65, 0.7]),
        PackedColorArray([
            Color.WHITE,
            Color(0.5, 0.5, 0.5),
            Color.BLACK,
            Color(0.5, 0.5, 0.5),
            Color.WHITE,
        ])
    )
    _cyclic_highlight = _gradient_texture(
        PackedFloat32Array([0.5, 0.52, 0.54]),
        PackedColorArray([Color.BLACK, Color.WHITE, Color.BLACK])
    )
    _cyclic_color_lookup = _gradient_texture(
        PackedFloat32Array([0.0, 0.28, 0.58, 0.82, 1.0]),
        PackedColorArray([BODY, SHADOW, ASH, RIM, FLASH])
    )


static func _gradient_texture(
        offsets: PackedFloat32Array,
        colors: PackedColorArray
) -> GradientTexture1D:
    var gradient := Gradient.new()
    gradient.offsets = offsets
    gradient.colors = colors
    var texture := GradientTexture1D.new()
    texture.width = 256
    texture.gradient = gradient
    return texture


static func is_neutral(color: Color, tolerance: float = 0.001) -> bool:
    return absf(color.r - color.g) <= tolerance and absf(color.g - color.b) <= tolerance
