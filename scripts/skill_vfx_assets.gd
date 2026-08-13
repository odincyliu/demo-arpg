class_name SkillVfxAssets
extends RefCounted


const KENNEY_CIRCLE := preload("res://assets/vfx/cc0/kenney_particle_pack/circle_04.png")
const KENNEY_MAGIC_CIRCLE := preload("res://assets/vfx/cc0/kenney_particle_pack/magic_01.png")
const KENNEY_MAGIC_CORE := preload("res://assets/vfx/cc0/kenney_particle_pack/magic_05.png")
const KENNEY_MUZZLE := preload("res://assets/vfx/cc0/kenney_particle_pack/muzzle_03.png")
const KENNEY_FIRE := preload("res://assets/vfx/cc0/kenney_particle_pack/fire_01.png")
const KENNEY_LIGHTNING := preload("res://assets/vfx/cc0/kenney_particle_pack/spark_05.png")
const KENNEY_FLARE := preload("res://assets/vfx/cc0/kenney_particle_pack/flare_01.png")
const KENNEY_SLASH := preload("res://assets/vfx/cc0/kenney_particle_pack/slash_01.png")
const KENNEY_STAR := preload("res://assets/vfx/cc0/kenney_particle_pack/star_06.png")

const FIREBALL_FOLDER := "res://assets/vfx/cc0/cethiel_fireball"
const ICE_NOVA_FOLDER := "res://assets/vfx/cc0/grahhhhh_blue_ring"
const BLADE_WAVE_FOLDER := "res://assets/vfx/cc0/cethiel_blade_wave"
const HEAVY_SLASH_FOLDER := "res://assets/vfx/cc0/cethiel_heavy_slash"
const LIGHTNING_ATLAS_PATH := "res://assets/vfx/cc0/13rice_radial_lightning/radial_lightning_atlas.png"

static var _frame_cache: Dictionary = {}


static func get_projectile_frames(active_skill_id: StringName) -> SpriteFrames:
    var cache_key := StringName("projectile:%s" % active_skill_id)
    if _frame_cache.has(cache_key):
        return _frame_cache[cache_key] as SpriteFrames
    var frames: SpriteFrames
    match active_skill_id:
        &"fireball":
            frames = _build_sequence(FIREBALL_FOLDER, 28, 32.0, true)
        &"thunder_orb":
            frames = _build_atlas_sequence(LIGHTNING_ATLAS_PATH, 4, 2, 8, 22.0, true)
        &"blade_wave":
            frames = _build_sequence(BLADE_WAVE_FOLDER, 6, 28.0, true)
        &"summon_core":
            frames = _build_single_frame(KENNEY_MAGIC_CORE)
        _:
            return null
    _frame_cache[cache_key] = frames
    return frames


static func get_cast_frames(active_skill_id: StringName) -> SpriteFrames:
    var cache_key := StringName("cast:%s" % active_skill_id)
    if _frame_cache.has(cache_key):
        return _frame_cache[cache_key] as SpriteFrames
    var frames: SpriteFrames
    match active_skill_id:
        &"ice_nova":
            frames = _build_sequence(ICE_NOVA_FOLDER, 19, 30.0, false)
        &"thunder_orb":
            frames = _build_atlas_sequence(LIGHTNING_ATLAS_PATH, 4, 2, 8, 24.0, false)
        &"blade_wave":
            frames = _build_sequence(BLADE_WAVE_FOLDER, 6, 28.0, false)
        &"heavy_slash":
            frames = _build_sequence(HEAVY_SLASH_FOLDER, 6, 25.0, false)
        _:
            return null
    _frame_cache[cache_key] = frames
    return frames


static func get_projectile_pixel_size(active_skill_id: StringName) -> float:
    match active_skill_id:
        &"fireball":
            return 0.007
        &"thunder_orb":
            return 0.0058
        &"blade_wave":
            return 0.015
        &"summon_core":
            return 0.004
    return 0.005


static func get_projectile_modulate(
        active_skill_id: StringName,
        skill_color: Color
) -> Color:
    if active_skill_id in [&"thunder_orb", &"summon_core"]:
        return skill_color.lightened(0.1)
    return Color.WHITE


static func _build_sequence(
        folder: String,
        frame_count: int,
        frames_per_second: float,
        loop: bool
) -> SpriteFrames:
    var frames := _new_frames(frames_per_second, loop)
    for frame_number: int in range(1, frame_count + 1):
        var path := "%s/frame_%02d.png" % [folder, frame_number]
        var texture := load(path) as Texture2D
        if texture == null:
            push_error("Missing CC0 VFX frame: %s" % path)
            continue
        frames.add_frame(&"default", texture)
    return frames


static func _build_atlas_sequence(
        path: String,
        columns: int,
        rows: int,
        frame_count: int,
        frames_per_second: float,
        loop: bool
) -> SpriteFrames:
    var atlas := load(path) as Texture2D
    var frames := _new_frames(frames_per_second, loop)
    if atlas == null:
        push_error("Missing CC0 VFX atlas: %s" % path)
        return frames
    var frame_size := Vector2(
        float(atlas.get_width()) / float(columns),
        float(atlas.get_height()) / float(rows)
    )
    for frame_index: int in frame_count:
        var atlas_frame := AtlasTexture.new()
        atlas_frame.atlas = atlas
        atlas_frame.region = Rect2(
            Vector2(frame_index % columns, frame_index / columns) * frame_size,
            frame_size
        )
        frames.add_frame(&"default", atlas_frame)
    return frames


static func _build_single_frame(texture: Texture2D) -> SpriteFrames:
    var frames := _new_frames(1.0, true)
    frames.add_frame(&"default", texture)
    return frames


static func _new_frames(frames_per_second: float, loop: bool) -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.clear(&"default")
    frames.set_animation_speed(&"default", frames_per_second)
    frames.set_animation_loop(&"default", loop)
    return frames
