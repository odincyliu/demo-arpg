class_name ShadowVfxStyle
extends RefCounted

const SHADOW_MESH_SHADER := preload("res://assets/vfx/shadow_mesh.gdshader")
const SHADOW_SPRITE_SHADER := preload("res://assets/vfx/shadow_sprite.gdshader")

const BODY := Color(0.02, 0.02, 0.02, 1.0)
const SHADOW := Color(0.07, 0.07, 0.07, 1.0)
const ASH := Color(0.28, 0.28, 0.28, 1.0)
const RIM := Color(0.68, 0.68, 0.68, 1.0)
const FLASH := Color(0.9, 0.9, 0.9, 1.0)


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


static func is_neutral(color: Color, tolerance: float = 0.001) -> bool:
    return absf(color.r - color.g) <= tolerance and absf(color.g - color.b) <= tolerance
