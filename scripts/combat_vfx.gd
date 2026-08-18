class_name CombatVfx
extends RefCounted


const SKILL_VFX_ASSETS := preload("res://scripts/skill_vfx_assets.gd")
const SHADOW_STYLE := preload("res://scripts/shadow_vfx_style.gd")


static func spawn_cast_layers(
        parent: Node,
        definition: SkillDefinition,
        world_position: Vector3,
        direction: Vector3
) -> void:
    if parent == null or definition == null:
        return
    var flat_direction := direction
    flat_direction.y = 0.0
    flat_direction = flat_direction.normalized() if flat_direction.length_squared() > 0.01 else Vector3.FORWARD
    _spawn_skill_identity(parent, definition, world_position, flat_direction)
    _spawn_trigger_cue(parent, definition.trigger_type, world_position, flat_direction)
    _spawn_core_cue(parent, definition.core_behavior, world_position, flat_direction, definition.color)
    _spawn_shape_cue(parent, definition.shape_type, world_position, flat_direction, definition.color)
    for modifier_type: StringName in definition.modifier_types:
        _spawn_modifier_cue(parent, modifier_type, world_position, flat_direction, definition.color)
    for effect_type: StringName in definition.effect_types:
        _spawn_effect_cue(parent, effect_type, world_position, definition.color)


static func spawn_hit_layers(
        parent: Node,
        definition: SkillDefinition,
        target_position: Vector3,
        source_position: Vector3,
        direction: Vector3
) -> void:
    if parent == null or definition == null:
        return
    _spawn_skill_hit_identity(parent, definition, target_position, direction)
    for modifier_type: StringName in definition.modifier_types:
        _spawn_modifier_hit(
            parent,
            modifier_type,
            target_position,
            direction,
            definition.color
        )
    for effect_type: StringName in definition.effect_types:
        _spawn_effect_hit(
            parent,
            effect_type,
            target_position,
            source_position,
            definition.color
        )


static func spawn_flight_accent(
        parent: Node,
        definition: SkillDefinition,
        world_position: Vector3,
        direction: Vector3
) -> void:
    if parent == null or definition == null:
        return
    if definition.has_modifier(&"accelerate"):
        _spawn_streak(
            parent,
            world_position - direction * 0.75,
            world_position + direction * 0.12,
            Color("fff0a8"),
            0.045,
            0.1,
            &"vfx_modifier"
        )
    if definition.shape_type == &"rotate":
        _spawn_ring(parent, world_position, definition.color, 0.32, 0.11, &"vfx_shape")
    elif definition.shape_type == &"tracking":
        _spawn_motes(
            parent,
            world_position,
            Color("bfeaff"),
            2,
            0.18,
            0.12,
            &"vfx_shape",
            false
        )


static func _spawn_skill_identity(
        parent: Node,
        definition: SkillDefinition,
        world_position: Vector3,
        direction: Vector3
) -> void:
    match definition.active_skill_id:
        &"slash":
            _spawn_animated_skill_sprite(
                parent,
                SKILL_VFX_ASSETS.get_cast_frames(definition.active_skill_id),
                world_position + direction * 0.9 + Vector3.UP * 0.82,
                SHADOW_STYLE.BODY,
                0.027,
                0.5,
                1.08,
                0.3,
                false,
                direction,
                &"vfx_skill_identity",
                -0.16,
                &"body"
            )
            var slash_side := Vector3(-direction.z, 0.0, direction.x)
            _spawn_streak(parent, world_position - slash_side * 0.75 + Vector3.UP, world_position + slash_side * 0.9 + direction * 1.6 + Vector3.UP, SHADOW_STYLE.BODY, 0.12, 0.24, &"vfx_skill_identity", &"body")
            _spawn_streak(parent, world_position + slash_side * 0.65 + Vector3.UP * 1.06, world_position - slash_side * 0.8 + direction * 1.4 + Vector3.UP * 1.06, SHADOW_STYLE.ASH, 0.055, 0.18, &"vfx_skill_identity", &"ash")
        &"whirlblade":
            _spawn_orbit(parent, world_position + Vector3.UP * 0.72, SHADOW_STYLE.BODY, 8, 1.5 * definition.size_multiplier, 0.42, &"vfx_skill_identity", &"body")
            _spawn_ring(parent, world_position, SHADOW_STYLE.BODY, 1.55 * definition.size_multiplier, 0.36, &"vfx_skill_identity", &"body")
            _spawn_ring(parent, world_position + Vector3.UP * 0.08, SHADOW_STYLE.RIM, 1.2 * definition.size_multiplier, 0.24, &"vfx_skill_identity", &"rim")
            _spawn_motes(parent, world_position, SHADOW_STYLE.ASH, 8, 1.25, 0.34, &"vfx_skill_identity", true, &"ash")
        &"dash_strike":
            var dash_side := Vector3(-direction.z, 0.0, direction.x)
            for offset: float in [-0.4, 0.0, 0.4]:
                _spawn_streak(parent, world_position + dash_side * offset - direction * 0.8 + Vector3.UP, world_position + dash_side * offset + direction * 2.6 + Vector3.UP, SHADOW_STYLE.BODY, 0.09, 0.28, &"vfx_skill_identity", &"body")
            _spawn_streak(parent, world_position - dash_side + direction * 2.2 + Vector3.UP, world_position + dash_side + direction * 2.7 + Vector3.UP, SHADOW_STYLE.RIM, 0.05, 0.19, &"vfx_skill_identity", &"rim")
        &"flame_orb":
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_MUZZLE,
                world_position + direction * 0.52 + Vector3.UP * 0.72,
                Color("ffad54"),
                0.0035,
                0.55,
                1.05,
                0.22,
                false,
                direction,
                &"vfx_skill_identity",
                0.3
            )
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_FIRE,
                world_position + direction * 0.25 + Vector3.UP * 0.65,
                Color("ff7b45"),
                0.0022,
                0.3,
                0.82,
                0.24,
                false,
                direction,
                &"vfx_skill_identity",
                -0.45
            )
        &"frost_nova":
            _spawn_animated_skill_sprite(
                parent,
                SKILL_VFX_ASSETS.get_cast_frames(definition.active_skill_id),
                world_position + Vector3.UP * 0.05,
                Color.WHITE,
                0.052,
                0.28,
                1.0,
                0.68,
                true,
                direction,
                &"vfx_skill_identity",
                -0.35
            )
        &"chain_lightning":
            _spawn_animated_skill_sprite(
                parent,
                SKILL_VFX_ASSETS.get_cast_frames(definition.active_skill_id),
                world_position + Vector3.UP * 0.08,
                definition.color.lightened(0.22),
                0.0055,
                0.18,
                0.62,
                0.18,
                false,
                direction,
                &"vfx_skill_identity",
                0.48
            )
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_LIGHTNING,
                world_position + Vector3.UP * 0.06,
                definition.color.lightened(0.12),
                0.0034,
                0.2,
                0.64,
                0.18,
                false,
                direction,
                &"vfx_skill_identity",
                -0.28
            )
        &"shockwave":
            _spawn_animated_skill_sprite(
                parent,
                SKILL_VFX_ASSETS.get_cast_frames(definition.active_skill_id),
                world_position + direction * 0.72 + Vector3.UP * 0.72,
                Color.WHITE,
                0.014,
                0.58,
                1.12,
                0.26,
                false,
                direction,
                &"vfx_skill_identity",
                0.0,
                &"body"
            )
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_SLASH,
                world_position + direction * 0.9 + Vector3.UP * 0.72,
                definition.color.lightened(0.18),
                0.0068,
                0.38,
                0.88,
                0.27,
                false,
                direction,
                &"vfx_skill_identity",
                0.0,
                &"ash"
            )
        &"ground_burst":
            _spawn_ring(parent, world_position, SHADOW_STYLE.BODY, definition.area_radius * 0.78, 0.34, &"vfx_skill_identity", &"body")
            _spawn_radial_lines(parent, world_position, SHADOW_STYLE.RIM, 10, definition.area_radius * 0.72, &"vfx_skill_identity")
            _spawn_shards(parent, world_position, SHADOW_STYLE.BODY, 12, definition.area_radius * 0.72, &"vfx_skill_identity", &"body")
            _spawn_cloud(parent, world_position, SHADOW_STYLE.SHADOW, 8, definition.area_radius * 0.5, &"vfx_skill_identity", &"shadow")
        &"arrow_shot":
            _spawn_streak(parent, world_position + Vector3.UP * 0.78, world_position + direction * 2.5 + Vector3.UP * 0.78, SHADOW_STYLE.BODY, 0.075, 0.22, &"vfx_skill_identity", &"body")
            _spawn_streak(parent, world_position + direction * 0.2 + Vector3.UP * 0.82, world_position + direction * 2.0 + Vector3.UP * 0.82, SHADOW_STYLE.RIM, 0.025, 0.16, &"vfx_skill_identity", &"rim")
        &"frost_lance":
            _spawn_streak(parent, world_position + Vector3.UP * 0.8, world_position + direction * 2.8 + Vector3.UP * 0.8, SHADOW_STYLE.BODY, 0.11, 0.24, &"vfx_skill_identity", &"body")
            _spawn_streak(parent, world_position + direction * 0.3 + Vector3.UP * 0.82, world_position + direction * 2.55 + Vector3.UP * 0.82, SHADOW_STYLE.RIM, 0.035, 0.18, &"vfx_skill_identity", &"rim")
            _spawn_shards(parent, world_position + direction * 1.35, SHADOW_STYLE.ASH, 5, 0.55, &"vfx_skill_identity", &"ash")
        &"summon":
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_CIRCLE,
                world_position + Vector3.UP * 0.04,
                definition.color,
                0.008,
                0.42,
                1.05,
                0.66,
                true,
                direction,
                &"vfx_skill_identity",
                1.4
            )
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_MAGIC_CIRCLE,
                world_position + Vector3.UP * 0.07,
                Color("fff0a8"),
                0.0066,
                0.3,
                0.92,
                0.66,
                true,
                direction,
                &"vfx_skill_identity",
                -1.85
            )
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_MAGIC_CORE,
                world_position + Vector3.UP * 1.0,
                definition.color.lightened(0.18),
                0.0032,
                0.25,
                0.88,
                0.48,
                false,
                direction,
                &"vfx_skill_identity",
                0.5
            )
        &"meteor":
            _spawn_ring(parent, world_position, SHADOW_STYLE.BODY, definition.area_radius * 0.9, 0.55, &"vfx_skill_identity", &"body")
            _spawn_ring(parent, world_position + Vector3.UP * 0.05, SHADOW_STYLE.RIM, definition.area_radius * 0.62, 0.42, &"vfx_skill_identity", &"rim")
            _spawn_cloud(parent, world_position + Vector3.UP * 2.8, SHADOW_STYLE.SHADOW, 9, 1.4, &"vfx_skill_identity", &"shadow")
            _spawn_streak(parent, world_position + Vector3.UP * 5.0 - direction * 1.2, world_position + Vector3.UP * 0.5, SHADOW_STYLE.BODY, 0.28, 0.6, &"vfx_skill_identity", &"body")
        &"void_beam":
            _spawn_streak(parent, world_position + Vector3.UP * 0.82, world_position + direction * definition.target_range + Vector3.UP * 0.82, SHADOW_STYLE.BODY, 0.18 * definition.width_multiplier, 0.16, &"vfx_skill_identity", &"body")
            _spawn_streak(parent, world_position + Vector3.UP * 0.83, world_position + direction * definition.target_range + Vector3.UP * 0.83, SHADOW_STYLE.RIM, 0.04 * definition.width_multiplier, 0.12, &"vfx_skill_identity", &"rim")
            _spawn_motes(parent, world_position + direction * 1.1, SHADOW_STYLE.ASH, 6, 0.7, 0.18, &"vfx_skill_identity", false, &"ash")
        &"void_rift":
            _spawn_ring(parent, world_position, SHADOW_STYLE.BODY, definition.area_radius, 0.58, &"vfx_skill_identity", &"body")
            _spawn_orbit(parent, world_position + Vector3.UP * 0.18, SHADOW_STYLE.SHADOW, 10, definition.area_radius * 0.68, 0.62, &"vfx_skill_identity", &"shadow")
            _spawn_motes(parent, world_position, SHADOW_STYLE.BODY, 12, definition.area_radius * 0.75, 0.58, &"vfx_skill_identity", true, &"body")
        _:
            _spawn_ring(parent, world_position, definition.color, 0.9 + definition.size_multiplier * 0.35, 0.28, &"vfx_skill_identity")
            _spawn_motes(
                parent,
                world_position + direction * 0.35 + Vector3.UP * 0.55,
                definition.color.lightened(0.2),
                4 + absi(hash(definition.active_skill_id)) % 5,
                0.55 + definition.size_multiplier * 0.18,
                0.24,
                &"vfx_skill_identity",
                definition.element in [&"fire", &"physical"]
            )


static func _spawn_skill_hit_identity(
        parent: Node,
        definition: SkillDefinition,
        target_position: Vector3,
        direction: Vector3
) -> void:
    match definition.active_skill_id:
        &"slash", &"dash_strike":
            _spawn_texture_burst(parent, SKILL_VFX_ASSETS.KENNEY_SLASH, target_position + Vector3.UP * 0.72, SHADOW_STYLE.BODY, 0.0042, 0.32, 0.9, 0.22, false, direction, &"vfx_skill_identity", 0.28, &"body")
            _spawn_cross(parent, target_position + Vector3.UP * 0.46, SHADOW_STYLE.RIM, 0.7 * definition.size_multiplier, &"vfx_skill_identity")
        &"whirlblade":
            _spawn_ring(parent, target_position, SHADOW_STYLE.BODY, 0.78 * definition.size_multiplier, 0.22, &"vfx_skill_identity", &"body")
            _spawn_motes(parent, target_position, SHADOW_STYLE.ASH, 6, 0.75, 0.24, &"vfx_skill_identity", false, &"ash")
        &"flame_orb":
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_FIRE,
                target_position + Vector3.UP * 0.72,
                Color("ff8d42"),
                0.0032,
                0.32,
                0.92,
                0.28,
                false,
                direction,
                &"vfx_skill_identity",
                0.7
            )
        &"chain_lightning":
            _spawn_animated_skill_sprite(
                parent,
                SKILL_VFX_ASSETS.get_cast_frames(definition.active_skill_id),
                target_position + Vector3.UP * 0.08,
                definition.color.lightened(0.28),
                0.0046,
                0.2,
                0.62,
                0.2,
                false,
                direction,
                &"vfx_skill_identity",
                0.45
            )
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_LIGHTNING,
                target_position + Vector3.UP * 0.9,
                definition.color.lightened(0.25),
                0.0031,
                0.38,
                0.88,
                0.23,
                false,
                direction,
                &"vfx_skill_identity",
                -0.22
            )
        &"shockwave":
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_SLASH,
                target_position + Vector3.UP * 0.74,
                definition.color.lightened(0.2),
                0.0034,
                0.28,
                0.8,
                0.2,
                false,
                direction,
                &"vfx_skill_identity",
                0.4,
                &"body"
            )
            _spawn_streak(parent, target_position - direction * 0.8 + Vector3.UP * 0.65, target_position + direction * 0.8 + Vector3.UP * 0.65, SHADOW_STYLE.RIM, 0.055, 0.18, &"vfx_skill_identity", &"rim")
        &"ground_burst":
            _spawn_shards(parent, target_position, SHADOW_STYLE.BODY, 9, 1.0 * definition.size_multiplier, &"vfx_skill_identity", &"body")
            _spawn_cloud(parent, target_position, SHADOW_STYLE.SHADOW, 7, 0.85, &"vfx_skill_identity", &"shadow")
        &"arrow_shot":
            _spawn_streak(parent, target_position - direction * 0.7 + Vector3.UP * 0.6, target_position + direction * 0.45 + Vector3.UP * 0.6, SHADOW_STYLE.BODY, 0.08, 0.16, &"vfx_skill_identity", &"body")
            _spawn_cross(parent, target_position + Vector3.UP * 0.42, SHADOW_STYLE.FLASH, 0.28, &"vfx_skill_identity")
        &"frost_lance":
            _spawn_shards(parent, target_position, SHADOW_STYLE.BODY, 8, 0.9, &"vfx_skill_identity", &"body")
            _spawn_ring(parent, target_position, SHADOW_STYLE.RIM, 0.62, 0.18, &"vfx_skill_identity", &"rim")
        &"frost_nova":
            _spawn_shards(parent, target_position, SHADOW_STYLE.BODY, 7, 0.78, &"vfx_skill_identity", &"body")
            _spawn_ring(parent, target_position, SHADOW_STYLE.RIM, 0.72, 0.2, &"vfx_skill_identity", &"rim")
        &"summon":
            _spawn_texture_burst(
                parent,
                SKILL_VFX_ASSETS.KENNEY_STAR,
                target_position + Vector3.UP * 0.82,
                definition.color.lightened(0.24),
                0.003,
                0.2,
                0.72,
                0.24,
                false,
                direction,
                &"vfx_skill_identity",
                0.65
            )
        &"meteor":
            _spawn_ring(parent, target_position, SHADOW_STYLE.BODY, definition.area_radius, 0.34, &"vfx_skill_identity", &"body")
            _spawn_motes(parent, target_position, SHADOW_STYLE.BODY, 16, definition.area_radius * 0.8, 0.42, &"vfx_skill_identity", true, &"body")
            _spawn_shards(parent, target_position, SHADOW_STYLE.ASH, 12, definition.area_radius * 0.68, &"vfx_skill_identity", &"ash")
        &"void_beam":
            _spawn_cross(parent, target_position + Vector3.UP * 0.52, SHADOW_STYLE.FLASH, 0.48, &"vfx_skill_identity")
            _spawn_cloud(parent, target_position, SHADOW_STYLE.SHADOW, 5, 0.62, &"vfx_skill_identity", &"shadow")
        &"void_rift":
            _spawn_ring(parent, target_position, SHADOW_STYLE.BODY, 0.65, 0.22, &"vfx_skill_identity", &"body")
            _spawn_motes(parent, target_position, SHADOW_STYLE.SHADOW, 6, 0.65, 0.28, &"vfx_skill_identity", true, &"shadow")
        _:
            _spawn_cross(parent, target_position + Vector3.UP * 0.55, definition.color.lightened(0.18), 0.58 * definition.size_multiplier, &"vfx_skill_identity")
            _spawn_ring(parent, target_position, definition.color, 0.48 * definition.size_multiplier, 0.18, &"vfx_skill_identity")


static func _spawn_trigger_cue(
        parent: Node,
        trigger_type: StringName,
        world_position: Vector3,
        direction: Vector3
) -> void:
    if trigger_type == &"":
        return
    match trigger_type:
        &"critical":
            _spawn_ring(parent, world_position, Color("fff7a8"), 1.4, 0.28, &"vfx_trigger")
            _spawn_ring(parent, world_position + Vector3.UP * 0.08, Color.WHITE, 0.82, 0.2, &"vfx_trigger")
        &"damaged":
            _spawn_ring(parent, world_position, Color("ff496f"), 1.75, 0.32, &"vfx_trigger")
            _spawn_motes(parent, world_position, Color("ff6b79"), 8, 1.15, 0.3, &"vfx_trigger", true)
        &"kill":
            _spawn_motes(parent, world_position, Color("c48cff"), 10, 1.35, 0.48, &"vfx_trigger", true)
            _spawn_ring(parent, world_position, Color("a86cff"), 1.25, 0.34, &"vfx_trigger")
        &"dash":
            for offset: float in [-0.38, 0.0, 0.38]:
                var side := Vector3(-direction.z, 0.0, direction.x) * offset
                _spawn_streak(
                    parent,
                    world_position + side - direction * 1.1 + Vector3.UP,
                    world_position + side + direction * 0.55 + Vector3.UP,
                    Color("61dcff"),
                    0.045,
                    0.22,
                    &"vfx_trigger"
                )
        _:
            var trigger_colors: Dictionary = {
                &"hit": Color("dce9f3"),
                &"stun": Color("ffd36a"),
                &"freeze": Color("78e2ff"),
                &"ignite": Color("ff7b45"),
                &"electrified": Color("91dcff"),
                &"damage_taken": Color("ff496f"),
                &"channel": Color("bd83ff"),
                &"return": Color("d5f0b6"),
            }
            var cue_color := trigger_colors.get(trigger_type, Color("b9ecff")) as Color
            _spawn_streak(
                parent,
                world_position - Vector3(direction.z, 0.0, -direction.x) * 0.65 + Vector3.UP,
                world_position + Vector3(direction.z, 0.0, -direction.x) * 0.65 + Vector3.UP,
                cue_color,
                0.06,
                0.17,
                &"vfx_trigger"
            )
            _spawn_ring(parent, world_position, cue_color, 0.85, 0.2, &"vfx_trigger")


static func _spawn_core_cue(
        parent: Node,
        core_behavior: StringName,
        world_position: Vector3,
        direction: Vector3,
        color: Color
) -> void:
    match core_behavior:
        &"melee", &"dash":
            var side := Vector3(-direction.z, 0.0, direction.x)
            _spawn_streak(parent, world_position - side + Vector3.UP, world_position + side + direction * 1.25 + Vector3.UP, color, 0.1, 0.2, &"vfx_core")
            _spawn_streak(parent, world_position + side + Vector3.UP, world_position - side + direction * 1.25 + Vector3.UP, Color.WHITE, 0.065, 0.16, &"vfx_core")
        &"summon":
            _spawn_orbit(parent, world_position + Vector3.UP * 0.65, color, 3, 1.1, 0.5, &"vfx_core")
            _spawn_ring(parent, world_position, color, 1.45, 0.38, &"vfx_core")
        _:
            _spawn_motes(parent, world_position + direction * 0.45, color, 6, 0.65, 0.2, &"vfx_core", false)


static func _spawn_shape_cue(
        parent: Node,
        shape_type: StringName,
        world_position: Vector3,
        direction: Vector3,
        color: Color
) -> void:
    match shape_type:
        &"circle":
            _spawn_ring(parent, world_position, color, 3.0, 0.36, &"vfx_shape")
            _spawn_radial_lines(parent, world_position, color, 8, 2.2, &"vfx_shape")
        &"cone":
            for angle: float in [-28.0, -14.0, 0.0, 14.0, 28.0]:
                var ray_direction := direction.rotated(Vector3.UP, deg_to_rad(angle))
                _spawn_streak(parent, world_position + Vector3.UP * 0.25, world_position + ray_direction * 4.1 + Vector3.UP * 0.25, color, 0.025, 0.24, &"vfx_shape")
        &"rotate":
            _spawn_orbit(parent, world_position + Vector3.UP * 0.5, color, 6, 1.65, 0.58, &"vfx_shape")
            _spawn_ring(parent, world_position, color, 1.75, 0.42, &"vfx_shape")
        &"tracking":
            _spawn_orbit(parent, world_position + direction * 0.65 + Vector3.UP * 0.6, Color("bcecff"), 3, 0.55, 0.36, &"vfx_shape")
            _spawn_streak(parent, world_position + Vector3.UP * 0.6, world_position + direction * 2.4 + Vector3.UP * 0.6, color, 0.035, 0.25, &"vfx_shape")
        _:
            _spawn_streak(parent, world_position + Vector3.UP * 0.35, world_position + direction * 4.8 + Vector3.UP * 0.35, color, 0.05, 0.24, &"vfx_shape")


static func _spawn_modifier_cue(
        parent: Node,
        modifier_type: StringName,
        world_position: Vector3,
        direction: Vector3,
        color: Color
) -> void:
    match modifier_type:
        &"fork":
            for angle: float in [-22.0, 0.0, 22.0]:
                var split_direction := direction.rotated(Vector3.UP, deg_to_rad(angle))
                _spawn_streak(parent, world_position + Vector3.UP * 0.55, world_position + split_direction * 2.25 + Vector3.UP * 0.55, color, 0.035, 0.22, &"vfx_modifier")
        &"pierce":
            for distance: float in [0.75, 1.35, 1.95]:
                _spawn_ring(parent, world_position + direction * distance + Vector3.UP * 0.45, Color("e7f3ff"), 0.48, 0.25, &"vfx_modifier")
        &"chain":
            var side := Vector3(-direction.z, 0.0, direction.x)
            var center := world_position + direction * 0.8 + Vector3.UP * 0.55
            _spawn_streak(parent, world_position + Vector3.UP * 0.55, center, color, 0.035, 0.25, &"vfx_modifier")
            _spawn_streak(parent, center, center + direction * 0.7 + side * 0.65, color, 0.035, 0.25, &"vfx_modifier")
            _spawn_streak(parent, center, center + direction * 0.7 - side * 0.65, color, 0.035, 0.25, &"vfx_modifier")
        &"return":
            _spawn_ring(parent, world_position - direction * 0.5, Color("d5f0b6"), 0.62, 0.22, &"vfx_modifier")
        &"homing":
            _spawn_orbit(parent, world_position + direction * 0.5 + Vector3.UP * 0.4, color, 3, 0.46, 0.28, &"vfx_modifier")
        &"giant", &"expanded":
            _spawn_ring(parent, world_position, color, 1.55, 0.3, &"vfx_modifier")
        &"compressed":
            _spawn_ring(parent, world_position, Color.WHITE, 0.34, 0.16, &"vfx_modifier")
        _:
            _spawn_ring(parent, world_position, Color(0.65, 0.75, 0.85, 0.7), 0.52, 0.18, &"vfx_modifier")


static func _spawn_effect_cue(
        parent: Node,
        effect_type: StringName,
        world_position: Vector3,
        color: Color
) -> void:
    match effect_type:
        &"ignite":
            _spawn_motes(parent, world_position, Color("ff7b45"), 10, 1.05, 0.36, &"vfx_effect", true)
        &"poison":
            _spawn_cloud(parent, world_position, Color("79d958"), 7, 1.0, &"vfx_effect")
        &"freeze":
            _spawn_shards(parent, world_position, Color("8de7ff"), 8, 1.1, &"vfx_effect")
        &"electrified":
            _spawn_radial_lines(parent, world_position, Color("91dcff"), 8, 1.1, &"vfx_effect")
        _:
            _spawn_motes(parent, world_position, color, 5, 0.65, 0.22, &"vfx_effect", false)


static func _spawn_modifier_hit(
        parent: Node,
        modifier_type: StringName,
        target_position: Vector3,
        direction: Vector3,
        color: Color
) -> void:
    match modifier_type:
        &"pierce":
            _spawn_ring(parent, target_position, Color.WHITE, 0.9, 0.2, &"vfx_modifier")
            _spawn_streak(parent, target_position - direction, target_position + direction, color, 0.055, 0.18, &"vfx_modifier")
        &"chain":
            _spawn_ring(parent, target_position, Color("d9b8ff"), 0.78, 0.2, &"vfx_modifier")
        &"fork":
            _spawn_radial_lines(parent, target_position, color, 3, 0.75, &"vfx_modifier")
        _:
            _spawn_ring(parent, target_position, color, 0.5, 0.15, &"vfx_modifier")


static func _spawn_effect_hit(
        parent: Node,
        effect_type: StringName,
        target_position: Vector3,
        _source_position: Vector3,
        color: Color
) -> void:
    match effect_type:
        &"ignite":
            _spawn_motes(parent, target_position, Color("ff6b36"), 12, 1.2, 0.42, &"vfx_effect", true)
        &"poison":
            _spawn_cloud(parent, target_position, Color("7be05a"), 9, 1.25, &"vfx_effect")
        &"freeze":
            _spawn_shards(parent, target_position, Color("a6efff"), 10, 1.35, &"vfx_effect")
            _spawn_ring(parent, target_position, Color("75ddff"), 1.25, 0.3, &"vfx_effect")
        &"electrified":
            _spawn_radial_lines(parent, target_position, Color("91dcff"), 9, 1.2, &"vfx_effect")
        _:
            _spawn_cross(parent, target_position, color, 0.62, &"vfx_effect")


static func spawn_pulse(
        parent: Node,
        world_position: Vector3,
        color: Color,
        radius: float = 1.0
) -> void:
    if parent == null:
        return

    var pulse := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.28
    sphere.height = 0.56
    pulse.mesh = sphere
    pulse.material_override = _glowing_material(color)
    pulse.scale = Vector3.ONE * 0.15
    parent.add_child(pulse)
    pulse.add_to_group("combat_vfx")
    pulse.global_position = world_position

    var tween := pulse.create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(pulse, "scale", Vector3.ONE * radius, 0.18)
    tween.tween_callback(Callable(pulse, "queue_free"))


static func spawn_persistent_field(
        parent: Node,
        definition: SkillDefinition,
        world_position: Vector3,
        radius: float,
        duration: float,
        is_remnant: bool = false
) -> Node3D:
    if parent == null or definition == null:
        return null
    var root := Node3D.new()
    parent.add_child(root)
    _tag_vfx(root, &"vfx_persistent")
    root.add_to_group("vfx_skill_identity")
    root.set_meta("vfx_profile", definition.active_skill_id)
    root.global_position = Vector3(world_position.x, maxf(world_position.y, 0.04), world_position.z)

    var pool := MeshInstance3D.new()
    var pool_mesh := CylinderMesh.new()
    pool_mesh.top_radius = 1.0
    pool_mesh.bottom_radius = 0.84
    pool_mesh.height = 0.035
    pool.mesh = pool_mesh
    pool.scale = Vector3(radius, 1.0, radius)
    pool.material_override = SHADOW_STYLE.mesh_material(&"body", 0.76, 0.025, 0.52)
    root.add_child(pool)

    var rim := MeshInstance3D.new()
    var rim_mesh := TorusMesh.new()
    rim_mesh.inner_radius = 0.78
    rim_mesh.outer_radius = 0.94
    rim_mesh.rings = 12
    rim_mesh.ring_segments = 24
    rim.mesh = rim_mesh
    rim.scale = Vector3.ONE * radius
    rim.material_override = SHADOW_STYLE.standard_material(&"rim", 0.48, 0.32)
    root.add_child(rim)

    if not is_remnant:
        for index: int in 7:
            var tendril := MeshInstance3D.new()
            var tendril_mesh := PrismMesh.new()
            tendril_mesh.size = Vector3(0.08, randf_range(0.45, 0.95), 0.12)
            tendril.mesh = tendril_mesh
            tendril.material_override = SHADOW_STYLE.mesh_material(&"shadow", 0.8, 0.055, 0.38)
            var angle := TAU * float(index) / 7.0
            tendril.position = Vector3(cos(angle), 0.35, sin(angle)) * radius * 0.55
            tendril.rotation.y = -angle
            root.add_child(tendril)

    var motion := root.create_tween()
    motion.set_parallel(true)
    motion.tween_property(root, "rotation:y", root.rotation.y + TAU * (0.65 if is_remnant else 1.4), duration)
    motion.tween_property(root, "scale", Vector3.ONE * 0.82, duration)
    motion.set_parallel(false)
    motion.tween_callback(Callable(root, "queue_free"))
    return root


static func spawn_bolt(
        parent: Node,
        from_position: Vector3,
        to_position: Vector3,
        color: Color
) -> void:
    if parent == null:
        return

    var delta := to_position - from_position
    var length := delta.length()
    if length < 0.01:
        return

    var bolt := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.055
    cylinder.bottom_radius = 0.055
    cylinder.height = length
    bolt.mesh = cylinder
    bolt.material_override = _glowing_material(color)
    parent.add_child(bolt)
    bolt.add_to_group("combat_vfx")

    var y_axis := delta.normalized()
    var reference := Vector3.FORWARD
    if absf(y_axis.dot(reference)) > 0.95:
        reference = Vector3.RIGHT
    var x_axis := y_axis.cross(reference).normalized()
    var z_axis := x_axis.cross(y_axis).normalized()
    bolt.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), (from_position + to_position) * 0.5)

    var tween := bolt.create_tween()
    tween.tween_interval(0.11)
    tween.tween_callback(Callable(bolt, "queue_free"))


static func spawn_chain_lightning(
        parent: Node,
        from_position: Vector3,
        to_position: Vector3,
        color: Color,
        visual_seed: int = 0
) -> void:
    if parent == null:
        return
    var delta := to_position - from_position
    var length := delta.length()
    if length < 0.05:
        return

    var root := Node3D.new()
    parent.add_child(root)
    _tag_vfx(root, &"vfx_chain_lightning")
    root.set_meta("from_position", from_position)
    root.set_meta("to_position", to_position)

    var segment_count := clampi(int(ceil(length / 1.15)) + 3, 7, 9)
    root.set_meta("segment_count", segment_count)
    var forward := delta / length
    var side := forward.cross(Vector3.UP)
    if side.length_squared() < 0.01:
        side = Vector3.RIGHT
    else:
        side = side.normalized()
    var lift := side.cross(forward).normalized()
    var random := RandomNumberGenerator.new()
    random.seed = absi(hash([from_position, to_position, visual_seed]))
    var jitter_radius := minf(0.46, length * 0.085)
    var points: Array[Vector3] = [from_position]
    for point_index: int in range(1, segment_count):
        var weight := float(point_index) / float(segment_count)
        var envelope := sin(PI * weight)
        var jitter := (
            side * random.randf_range(-jitter_radius, jitter_radius)
            + lift * random.randf_range(-jitter_radius * 0.38, jitter_radius * 0.38)
        ) * envelope
        points.append(from_position.lerp(to_position, weight) + jitter)
    points.append(to_position)

    var outer_material := SHADOW_STYLE.standard_material(&"body", 0.82)
    var core_material := SHADOW_STYLE.standard_material(&"rim", 0.98, 1.8)
    for segment_index: int in segment_count:
        _add_lightning_segment(root, points[segment_index], points[segment_index + 1], outer_material, 0.105)
        _add_lightning_segment(root, points[segment_index], points[segment_index + 1], core_material, 0.034)

    var direction := forward
    var endpoint_frames := SKILL_VFX_ASSETS.get_cast_frames(&"chain_lightning")
    _spawn_animated_skill_sprite(
        parent, endpoint_frames, from_position, color.lightened(0.24),
        0.0038, 0.16, 0.5, 0.18, false, direction,
        &"vfx_chain_lightning", -0.35
    )
    _spawn_animated_skill_sprite(
        parent, endpoint_frames, to_position, Color("e8fbff"),
        0.0044, 0.2, 0.62, 0.2, false, -direction,
        &"vfx_chain_lightning", 0.42
    )

    var flicker := root.create_tween()
    flicker.tween_interval(0.035)
    flicker.tween_callback(Callable(root, "hide"))
    flicker.tween_interval(0.018)
    flicker.tween_callback(Callable(root, "show"))
    var fade := root.create_tween()
    fade.tween_interval(0.09)
    fade.set_parallel(true)
    fade.tween_property(outer_material, "albedo_color:a", 0.0, 0.07)
    fade.tween_property(core_material, "albedo_color:a", 0.0, 0.07)
    fade.set_parallel(false)
    fade.tween_callback(Callable(root, "queue_free"))


static func _add_lightning_segment(
        parent: Node3D,
        from_position: Vector3,
        to_position: Vector3,
        material: StandardMaterial3D,
        width: float
) -> void:
    var delta := to_position - from_position
    var length := delta.length()
    if length < 0.01:
        return
    var segment := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = width
    cylinder.bottom_radius = width
    cylinder.height = length
    segment.mesh = cylinder
    segment.material_override = material
    parent.add_child(segment)
    var y_axis := delta / length
    var reference := Vector3.FORWARD
    if absf(y_axis.dot(reference)) > 0.95:
        reference = Vector3.RIGHT
    var x_axis := y_axis.cross(reference).normalized()
    var z_axis := x_axis.cross(y_axis).normalized()
    segment.global_transform = Transform3D(
        Basis(x_axis, y_axis, z_axis),
        (from_position + to_position) * 0.5
    )


static func spawn_damage_number(
        parent: Node,
        world_position: Vector3,
        amount: float,
        color: Color,
        critical: bool = false
) -> void:
    if parent == null:
        return

    var lane_index := _next_damage_number_lane(parent)
    var column := lane_index % 4
    var row := floori(float(lane_index) / 4.0)
    var horizontal_axis := Vector3.RIGHT
    var viewport := parent.get_viewport()
    if viewport != null:
        var camera := viewport.get_camera_3d()
        if camera != null:
            horizontal_axis = camera.global_transform.basis.x.normalized()
    var horizontal_offset := (float(column) - 1.5) * 0.72
    var vertical_offset := float(row) * 0.52 + (0.18 if column % 2 == 1 else 0.0)
    if critical:
        vertical_offset += 0.62

    var label := Label3D.new()
    label.text = "%s%.0f" % ["CRIT " if critical else "", amount]
    label.font_size = 64 if critical else 48
    label.outline_size = 12 if critical else 9
    label.outline_modulate = Color(0.015, 0.015, 0.015, 0.98)
    label.pixel_size = 0.012
    label.modulate = SHADOW_STYLE.FLASH if critical else SHADOW_STYLE.RIM
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    parent.add_child(label)
    label.add_to_group("combat_vfx")
    label.add_to_group("damage_number_vfx")
    label.set_meta("damage_number_lane", lane_index)
    label.global_position = (
        world_position
        + horizontal_axis * horizontal_offset
        + Vector3.UP * vertical_offset
    )
    label.scale = Vector3.ONE * (0.48 if critical else 0.58)

    var start_position := label.position
    var pop_position := start_position + Vector3.UP * (0.46 if critical else 0.34)
    var end_position := start_position + Vector3.UP * (1.85 if critical else 1.5)
    var tween := label.create_tween()
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.set_parallel(true)
    tween.tween_property(label, "position", pop_position, 0.12)
    tween.tween_property(label, "scale", Vector3.ONE * 1.12, 0.12)
    tween.set_parallel(false)
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector3.ONE, 0.1)
    tween.tween_interval(0.24 if critical else 0.18)
    tween.set_parallel(true)
    tween.tween_property(label, "position", end_position, 0.46)
    tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.04)
    tween.set_parallel(false)
    tween.tween_callback(Callable(label, "queue_free"))


static func _next_damage_number_lane(parent: Node) -> int:
    var occupied_lanes: Dictionary = {}
    for child: Node in parent.get_children():
        if child.has_meta("damage_number_lane"):
            occupied_lanes[int(child.get_meta("damage_number_lane"))] = true
    var lane_index := 0
    while occupied_lanes.has(lane_index):
        lane_index += 1
    return lane_index


static func spawn_projectile_trail(
        parent: Node,
        world_position: Vector3,
        color: Color,
        size: float = 0.22
) -> void:
    if parent == null:
        return

    var ghost := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = size
    sphere.height = size * 2.0
    ghost.mesh = sphere

    var material := _transparent_material(color, 0.42)
    ghost.material_override = material
    parent.add_child(ghost)
    ghost.add_to_group("combat_vfx")
    ghost.global_position = world_position

    var tween := ghost.create_tween()
    tween.set_parallel(true)
    tween.tween_property(ghost, "scale", Vector3.ONE * 0.18, 0.16)
    tween.tween_property(material, "albedo_color:a", 0.0, 0.16)
    tween.set_parallel(false)
    tween.tween_callback(Callable(ghost, "queue_free"))


static func spawn_core_projectile_trail(
        parent: Node,
        definition: SkillDefinition,
        world_position: Vector3,
        direction: Vector3,
        size: float = 0.22
) -> void:
    if parent == null or definition == null:
        return
    match definition.active_skill_id:
        &"arrow_shot":
            _spawn_streak(parent, world_position - direction * 0.65, world_position + direction * 0.08, SHADOW_STYLE.BODY, 0.035, 0.12, &"vfx_projectile_trail", &"body")
        &"frost_lance":
            _spawn_streak(parent, world_position - direction * 0.58, world_position + direction * 0.06, SHADOW_STYLE.ASH, 0.055, 0.14, &"vfx_projectile_trail", &"ash")
        &"shockwave":
            var side := Vector3(-direction.z, 0.0, direction.x) * 0.62 * definition.width_multiplier
            _spawn_streak(parent, world_position - side + Vector3.UP * 0.18, world_position + side + Vector3.UP * 0.18, SHADOW_STYLE.BODY, 0.08, 0.14, &"vfx_projectile_trail", &"body")
        &"flame_orb":
            _spawn_motes(parent, world_position, SHADOW_STYLE.SHADOW, 2, 0.24, 0.16, &"vfx_projectile_trail", true, &"shadow")
        _:
            spawn_projectile_trail(parent, world_position, definition.color, size)


static func spawn_core_end(
        parent: Node,
        definition: SkillDefinition,
        world_position: Vector3,
        direction: Vector3
) -> void:
    if parent == null or definition == null:
        return
    match definition.active_skill_id:
        &"flame_orb":
            _spawn_skill_hit_identity(parent, definition, world_position, direction)
        &"shockwave":
            var side := Vector3(-direction.z, 0.0, direction.x) * definition.width_multiplier
            _spawn_streak(parent, world_position - side + Vector3.UP * 0.35, world_position + side + Vector3.UP * 0.35, SHADOW_STYLE.ASH, 0.065, 0.22, &"vfx_skill_identity", &"ash")
            _spawn_motes(parent, world_position, SHADOW_STYLE.SHADOW, 7, 0.9, 0.28, &"vfx_skill_identity", true, &"shadow")
        &"frost_lance":
            _spawn_shards(parent, world_position, SHADOW_STYLE.BODY, 7, 0.72, &"vfx_skill_identity", &"body")
            _spawn_ring(parent, world_position, SHADOW_STYLE.RIM, 0.5, 0.18, &"vfx_skill_identity", &"rim")
        &"arrow_shot":
            _spawn_cross(parent, world_position + Vector3.UP * 0.2, SHADOW_STYLE.RIM, 0.26, &"vfx_skill_identity")
            _spawn_motes(parent, world_position, SHADOW_STYLE.ASH, 4, 0.38, 0.18, &"vfx_skill_identity", false, &"ash")
        _:
            _spawn_ring(parent, world_position, SHADOW_STYLE.RIM, 0.42, 0.2, &"vfx_skill_identity", &"rim")


static func spawn_channel_end(
        parent: Node,
        definition: SkillDefinition,
        origin: Vector3,
        target_position: Vector3
) -> void:
    if parent == null or definition == null:
        return
    if definition.active_skill_id == &"void_beam":
        _spawn_cross(parent, target_position + Vector3.UP * 0.45, SHADOW_STYLE.FLASH, 0.52, &"vfx_skill_identity")
        _spawn_cloud(parent, target_position, SHADOW_STYLE.SHADOW, 7, 0.68, &"vfx_skill_identity", &"shadow")
    else:
        _spawn_ring(parent, origin, SHADOW_STYLE.BODY, definition.area_radius * 0.9, 0.3, &"vfx_skill_identity", &"body")
        _spawn_motes(parent, origin, SHADOW_STYLE.ASH, 9, definition.area_radius * 0.55, 0.34, &"vfx_skill_identity", true, &"ash")


static func spawn_dash_ghost(
        parent: Node,
        world_position: Vector3,
        rotation_y: float,
        color: Color
) -> void:
    if parent == null:
        return

    var ghost := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.46
    capsule.height = 1.65
    ghost.mesh = capsule
    var material := _transparent_material(color, 0.28)
    ghost.material_override = material
    parent.add_child(ghost)
    ghost.add_to_group("combat_vfx")
    ghost.global_position = world_position + Vector3.UP * 0.95
    ghost.rotation.y = rotation_y

    var tween := ghost.create_tween()
    tween.set_parallel(true)
    tween.tween_property(ghost, "scale", Vector3(0.65, 0.8, 0.65), 0.2)
    tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
    tween.set_parallel(false)
    tween.tween_callback(Callable(ghost, "queue_free"))


static func spawn_dash_sequence(
        parent: Node,
        from_position: Vector3,
        to_position: Vector3,
        rotation_y: float
) -> void:
    if parent == null:
        return
    var direction := to_position - from_position
    direction.y = 0.0
    if direction.length_squared() < 0.01:
        return
    direction = direction.normalized()
    var side := Vector3(-direction.z, 0.0, direction.x)
    _spawn_streak(parent, from_position + Vector3.UP, to_position + Vector3.UP, SHADOW_STYLE.BODY, 0.13, 0.28, &"vfx_skill_identity", &"body")
    for index: int in 4:
        spawn_dash_ghost(parent, from_position.lerp(to_position, float(index + 1) / 5.0), rotation_y, SHADOW_STYLE.SHADOW)
    _spawn_streak(parent, to_position - side * 1.25 + Vector3.UP, to_position + side * 1.25 + Vector3.UP, SHADOW_STYLE.RIM, 0.07, 0.22, &"vfx_skill_identity", &"rim")
    _spawn_cross(parent, to_position + Vector3.UP * 0.7, SHADOW_STYLE.FLASH, 0.62, &"vfx_skill_identity")


static func spawn_minion_dissolve(parent: Node, world_position: Vector3) -> void:
    if parent == null:
        return
    _spawn_ring(parent, world_position, SHADOW_STYLE.RIM, 0.62, 0.28, &"vfx_skill_identity", &"rim")
    _spawn_motes(parent, world_position, SHADOW_STYLE.SHADOW, 9, 0.75, 0.32, &"vfx_skill_identity", true, &"shadow")
    _spawn_cloud(parent, world_position, SHADOW_STYLE.BODY, 5, 0.52, &"vfx_skill_identity", &"body")


static func _spawn_ring(
        parent: Node,
        world_position: Vector3,
        color: Color,
        radius: float,
        duration: float,
        category_group: StringName,
        tone_role: StringName = &"rim"
) -> void:
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.78
    torus.outer_radius = 0.94
    torus.rings = 12
    torus.ring_segments = 24
    ring.mesh = torus
    var material := SHADOW_STYLE.standard_material(tone_role, 0.82)
    ring.material_override = material
    ring.scale = Vector3.ONE * 0.12
    parent.add_child(ring)
    _tag_vfx(ring, category_group)
    ring.global_position = Vector3(world_position.x, maxf(world_position.y, 0.08), world_position.z)

    var tween := ring.create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(ring, "scale", Vector3.ONE * radius, duration)
    tween.tween_property(material, "albedo_color:a", 0.0, duration)
    tween.set_parallel(false)
    tween.tween_callback(Callable(ring, "queue_free"))


static func _spawn_streak(
        parent: Node,
        from_position: Vector3,
        to_position: Vector3,
        color: Color,
        width: float,
        duration: float,
        category_group: StringName,
        tone_role: StringName = &"rim"
) -> void:
    var delta := to_position - from_position
    var length := delta.length()
    if length < 0.01:
        return

    var streak := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = width
    cylinder.bottom_radius = width
    cylinder.height = length
    streak.mesh = cylinder
    var material := SHADOW_STYLE.standard_material(tone_role, 0.88)
    streak.material_override = material
    parent.add_child(streak)
    _tag_vfx(streak, category_group)

    var y_axis := delta.normalized()
    var reference := Vector3.FORWARD
    if absf(y_axis.dot(reference)) > 0.95:
        reference = Vector3.RIGHT
    var x_axis := y_axis.cross(reference).normalized()
    var z_axis := x_axis.cross(y_axis).normalized()
    streak.global_transform = Transform3D(
        Basis(x_axis, y_axis, z_axis),
        (from_position + to_position) * 0.5
    )

    var tween := streak.create_tween()
    tween.set_parallel(true)
    tween.tween_property(streak, "scale", Vector3(0.35, 1.0, 0.35), duration)
    tween.tween_property(material, "albedo_color:a", 0.0, duration)
    tween.set_parallel(false)
    tween.tween_callback(Callable(streak, "queue_free"))


static func _spawn_cross(
        parent: Node,
        world_position: Vector3,
        color: Color,
        radius: float,
        category_group: StringName
) -> void:
    var height := Vector3.UP * 0.42
    _spawn_streak(
        parent,
        world_position + Vector3(-radius, 0.0, 0.0) + height,
        world_position + Vector3(radius, 0.0, 0.0) + height,
        color,
        0.055,
        0.2,
        category_group
    )
    _spawn_streak(
        parent,
        world_position + Vector3(0.0, 0.0, -radius) + height,
        world_position + Vector3(0.0, 0.0, radius) + height,
        color,
        0.055,
        0.2,
        category_group
    )


static func _spawn_radial_lines(
        parent: Node,
        world_position: Vector3,
        color: Color,
        count: int,
        radius: float,
        category_group: StringName
) -> void:
    var center := world_position + Vector3.UP * 0.45
    for index: int in count:
        var angle := TAU * float(index) / float(count)
        var direction := Vector3(cos(angle), 0.0, sin(angle))
        _spawn_streak(
            parent,
            center + direction * 0.22,
            center + direction * radius,
            color,
            0.035,
            0.24,
            category_group
        )


static func _spawn_orbit(
        parent: Node,
        world_position: Vector3,
        color: Color,
        count: int,
        radius: float,
        duration: float,
        category_group: StringName,
        tone_role: StringName = &"rim"
) -> void:
    var orbit := Node3D.new()
    parent.add_child(orbit)
    _tag_vfx(orbit, category_group)
    orbit.global_position = world_position

    for index: int in count:
        var angle := TAU * float(index) / float(count)
        var mote := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.14
        sphere.height = 0.28
        mote.mesh = sphere
        mote.material_override = SHADOW_STYLE.standard_material(tone_role, 0.9)
        mote.position = Vector3(cos(angle), 0.0, sin(angle)) * radius
        orbit.add_child(mote)

    var tween := orbit.create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(orbit, "rotation:y", TAU * 1.35, duration)
    tween.tween_property(orbit, "scale", Vector3.ONE * 0.2, duration)
    tween.set_parallel(false)
    tween.tween_callback(Callable(orbit, "queue_free"))


static func _spawn_motes(
        parent: Node,
        world_position: Vector3,
        color: Color,
        count: int,
        radius: float,
        duration: float,
        category_group: StringName,
        rise: bool,
        tone_role: StringName = &"ash"
) -> void:
    var root := Node3D.new()
    parent.add_child(root)
    _tag_vfx(root, category_group)
    root.global_position = world_position

    for index: int in count:
        var angle := TAU * float(index) / float(maxi(count, 1)) + randf_range(-0.18, 0.18)
        var mote := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = randf_range(0.055, 0.13)
        sphere.height = sphere.radius * 2.0
        mote.mesh = sphere
        var material := SHADOW_STYLE.standard_material(tone_role, 0.9)
        mote.material_override = material
        mote.position = Vector3(randf_range(-0.12, 0.12), randf_range(0.2, 0.8), randf_range(-0.12, 0.12))
        root.add_child(mote)

        var horizontal := Vector3(cos(angle), 0.0, sin(angle)) * radius
        var destination := mote.position + horizontal
        destination.y += randf_range(0.65, 1.45) if rise else randf_range(-0.15, 0.35)
        var mote_tween := mote.create_tween()
        mote_tween.set_parallel(true)
        mote_tween.set_trans(Tween.TRANS_QUAD)
        mote_tween.set_ease(Tween.EASE_OUT)
        mote_tween.tween_property(mote, "position", destination, duration)
        mote_tween.tween_property(mote, "scale", Vector3.ONE * 0.12, duration)
        mote_tween.tween_property(material, "albedo_color:a", 0.0, duration)

    var cleanup := root.create_tween()
    cleanup.tween_interval(duration + 0.04)
    cleanup.tween_callback(Callable(root, "queue_free"))


static func _spawn_cloud(
        parent: Node,
        world_position: Vector3,
        color: Color,
        count: int,
        radius: float,
        category_group: StringName,
        tone_role: StringName = &"shadow"
) -> void:
    var root := Node3D.new()
    parent.add_child(root)
    _tag_vfx(root, category_group)
    root.global_position = world_position
    var duration := 0.5

    for index: int in count:
        var angle := TAU * float(index) / float(maxi(count, 1))
        var cloud := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = randf_range(0.18, 0.34)
        sphere.height = sphere.radius * 2.0
        cloud.mesh = sphere
        var material := SHADOW_STYLE.standard_material(tone_role, 0.48)
        cloud.material_override = material
        cloud.position = Vector3(0.0, randf_range(0.35, 1.1), 0.0)
        cloud.scale = Vector3.ONE * 0.35
        root.add_child(cloud)
        var destination := Vector3(cos(angle), 0.0, sin(angle)) * radius
        destination.y = cloud.position.y + randf_range(0.1, 0.65)
        var cloud_tween := cloud.create_tween()
        cloud_tween.set_parallel(true)
        cloud_tween.set_trans(Tween.TRANS_QUAD)
        cloud_tween.tween_property(cloud, "position", destination, duration)
        cloud_tween.tween_property(cloud, "scale", Vector3.ONE * randf_range(0.8, 1.35), duration)
        cloud_tween.tween_property(material, "albedo_color:a", 0.0, duration)

    var cleanup := root.create_tween()
    cleanup.tween_interval(duration + 0.04)
    cleanup.tween_callback(Callable(root, "queue_free"))


static func _spawn_shards(
        parent: Node,
        world_position: Vector3,
        color: Color,
        count: int,
        radius: float,
        category_group: StringName,
        tone_role: StringName = &"body"
) -> void:
    var root := Node3D.new()
    parent.add_child(root)
    _tag_vfx(root, category_group)
    root.global_position = world_position
    var duration := 0.38

    for index: int in count:
        var angle := TAU * float(index) / float(maxi(count, 1))
        var shard := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(0.08, randf_range(0.35, 0.7), 0.12)
        shard.mesh = box
        var material := SHADOW_STYLE.standard_material(tone_role, 0.92)
        shard.material_override = material
        shard.position = Vector3(0.0, 0.65, 0.0)
        shard.rotation = Vector3(randf_range(-0.4, 0.4), angle, randf_range(-0.6, 0.6))
        root.add_child(shard)
        var destination := Vector3(cos(angle), 0.0, sin(angle)) * radius
        destination.y = randf_range(0.75, 1.65)
        var shard_tween := shard.create_tween()
        shard_tween.set_parallel(true)
        shard_tween.set_trans(Tween.TRANS_QUAD)
        shard_tween.set_ease(Tween.EASE_OUT)
        shard_tween.tween_property(shard, "position", destination, duration)
        shard_tween.tween_property(shard, "rotation:x", shard.rotation.x + 1.8, duration)
        shard_tween.tween_property(material, "albedo_color:a", 0.0, duration)

    var cleanup := root.create_tween()
    cleanup.tween_interval(duration + 0.04)
    cleanup.tween_callback(Callable(root, "queue_free"))


static func _spawn_animated_skill_sprite(
        parent: Node,
        frames: SpriteFrames,
        world_position: Vector3,
        color: Color,
        pixel_size: float,
        start_scale: float,
        end_scale: float,
        duration: float,
        horizontal: bool,
        direction: Vector3,
        category_group: StringName,
        spin: float,
        tone_role: StringName = &"body"
) -> void:
    if frames == null or frames.get_frame_count(&"default") <= 0:
        return
    var root := Node3D.new()
    parent.add_child(root)
    _tag_vfx(root, category_group)
    root.global_position = world_position
    root.scale = Vector3.ONE * start_scale

    var sprite := AnimatedSprite3D.new()
    sprite.sprite_frames = frames
    sprite.animation = &"default"
    sprite.pixel_size = pixel_size
    sprite.modulate = Color.WHITE
    sprite.no_depth_test = true
    var first_texture := frames.get_frame_texture(&"default", 0)
    var shadow_material := SHADOW_STYLE.sprite_material(first_texture, tone_role, color.a)
    sprite.material_override = shadow_material
    sprite.frame_changed.connect(func() -> void:
        if is_instance_valid(sprite) and sprite.sprite_frames != null:
            shadow_material.set_shader_parameter(
                "source_texture",
                sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
            )
    )
    root.add_child(sprite)
    if horizontal:
        sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
        sprite.rotation.x = -PI * 0.5
    else:
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sprite.rotation.z = _screen_space_angle(parent, direction)
    sprite.play()

    var motion := root.create_tween()
    motion.set_parallel(true)
    motion.set_trans(Tween.TRANS_QUAD)
    motion.set_ease(Tween.EASE_OUT)
    motion.tween_property(root, "scale", Vector3.ONE * end_scale, duration)
    if horizontal:
        motion.tween_property(root, "rotation:y", root.rotation.y + spin, duration)
    elif not is_zero_approx(spin):
        motion.tween_property(sprite, "rotation:z", sprite.rotation.z + spin, duration)

    var fade := sprite.create_tween()
    fade.tween_interval(duration * 0.65)
    fade.tween_property(sprite, "modulate:a", 0.0, duration * 0.35)

    var cleanup := root.create_tween()
    cleanup.tween_interval(duration + 0.04)
    cleanup.tween_callback(Callable(root, "queue_free"))


static func _spawn_texture_burst(
        parent: Node,
        texture: Texture2D,
        world_position: Vector3,
        color: Color,
        pixel_size: float,
        start_scale: float,
        end_scale: float,
        duration: float,
        horizontal: bool,
        direction: Vector3,
        category_group: StringName,
        spin: float,
        tone_role: StringName = &"body"
) -> void:
    if texture == null:
        return
    var root := Node3D.new()
    parent.add_child(root)
    _tag_vfx(root, category_group)
    root.global_position = world_position
    root.scale = Vector3.ONE * start_scale

    var sprite := Sprite3D.new()
    sprite.texture = texture
    sprite.pixel_size = pixel_size
    sprite.modulate = Color.WHITE
    sprite.no_depth_test = true
    sprite.material_override = SHADOW_STYLE.sprite_material(texture, tone_role, color.a)
    root.add_child(sprite)
    if horizontal:
        sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
        sprite.rotation.x = -PI * 0.5
    else:
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sprite.rotation.z = _screen_space_angle(parent, direction)

    var motion := root.create_tween()
    motion.set_parallel(true)
    motion.set_trans(Tween.TRANS_QUAD)
    motion.set_ease(Tween.EASE_OUT)
    motion.tween_property(root, "scale", Vector3.ONE * end_scale, duration)
    if horizontal:
        motion.tween_property(root, "rotation:y", root.rotation.y + spin, duration)
    elif not is_zero_approx(spin):
        motion.tween_property(sprite, "rotation:z", sprite.rotation.z + spin, duration)

    var fade := sprite.create_tween()
    fade.tween_interval(duration * 0.48)
    fade.tween_property(sprite, "modulate:a", 0.0, duration * 0.52)

    var cleanup := root.create_tween()
    cleanup.tween_interval(duration + 0.04)
    cleanup.tween_callback(Callable(root, "queue_free"))


static func _screen_space_angle(parent: Node, direction: Vector3) -> float:
    var flat_direction := direction
    flat_direction.y = 0.0
    if flat_direction.length_squared() <= 0.001:
        flat_direction = Vector3.FORWARD
    else:
        flat_direction = flat_direction.normalized()
    var viewport := parent.get_viewport()
    var camera := viewport.get_camera_3d() if viewport != null else null
    if camera != null:
        var camera_direction := camera.global_transform.basis.inverse() * flat_direction
        return atan2(-camera_direction.y, camera_direction.x)
    return atan2(-flat_direction.z, flat_direction.x)


static func _tag_vfx(node: Node, category_group: StringName) -> void:
    node.add_to_group("combat_vfx")
    node.add_to_group(category_group)


static func _glowing_material(color: Color) -> StandardMaterial3D:
    var role := &"flash" if color.get_luminance() > 0.82 else &"rim"
    return SHADOW_STYLE.standard_material(role, color.a, 1.15)


static func _transparent_material(color: Color, alpha: float) -> StandardMaterial3D:
    var role := &"body" if color.get_luminance() < 0.18 else &"rim"
    return SHADOW_STYLE.standard_material(role, alpha, 0.45 if role == &"rim" else 0.0)
