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
    var has_authored_slash_visual := definition.active_skill_id == &"slash"
    if not has_authored_slash_visual:
        _spawn_core_cue(parent, definition.core_behavior, world_position, flat_direction, definition.color)
    if not has_authored_slash_visual or definition.shape_type != &"cone":
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
            _spawn_slash_cast(parent, definition, world_position, direction)
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
                0.0064,
                0.24,
                0.82,
                0.22,
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
                0.0042,
                0.26,
                0.86,
                0.22,
                false,
                direction,
                &"vfx_skill_identity",
                -0.28
            )
            _spawn_symbiote_tendrils(
                parent,
                world_position + Vector3.UP * 0.12,
                direction,
                definition.size_multiplier * 0.78,
                &"vfx_skill_identity"
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
            _spawn_radial_lines(parent, world_position, SHADOW_STYLE.ASH, 12, definition.area_radius * 0.78, &"vfx_skill_identity")
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
        &"slash":
            _spawn_slash_impact_smoke(parent, definition, target_position, direction)
        &"dash_strike":
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
                0.0058,
                0.25,
                0.82,
                0.24,
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
                0.0042,
                0.46,
                1.1,
                0.27,
                false,
                direction,
                &"vfx_skill_identity",
                -0.22
            )
            _spawn_symbiote_tendrils(
                parent,
                target_position + Vector3.UP * 0.08,
                direction,
                definition.size_multiplier * 0.82,
                &"vfx_skill_identity"
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


static func _spawn_slash_cast(
        parent: Node,
        definition: SkillDefinition,
        world_position: Vector3,
        direction: Vector3
) -> void:
    var attack_direction := direction
    attack_direction.y = 0.0
    attack_direction = (
        attack_direction.normalized()
        if attack_direction.length_squared() > 0.0001
        else Vector3.FORWARD
    )
    var root := Node3D.new()
    root.name = "SlashCastVfx"
    parent.add_child(root)
    _tag_vfx(root, &"vfx_slash_cast")
    root.add_to_group(&"vfx_skill_identity")
    root.add_to_group(&"vfx_core")
    root.add_to_group(&"vfx_shape")
    root.global_position = world_position
    root.set_meta("direction", attack_direction)
    root.set_meta("screen_angle", _screen_space_angle(parent, world_position, attack_direction))
    root.set_meta("presentation_layers", 2)
    root.set_meta("attack_radius", definition.area_radius)
    root.set_meta("swing_type", &"horizontal")
    root.set_meta("exaggeration_scale", 1.22)
    root.set_meta("impact_line_count", 12)
    # Keep the authored blade centered on the compiled attack path. Only its
    # small screen-space roll and the smoke wake vary between casts.
    var sweep_direction := 1.0
    var width_variation := 1.0
    var depth_variation := 1.0
    var bow_variation := 1.0
    var shape_phase := 0.0
    var tilt_degrees := randf_range(4.0, 12.0) * (-1.0 if randf() < 0.5 else 1.0)
    root.set_meta("sweep_direction", sweep_direction)
    root.set_meta("width_variation", width_variation)
    root.set_meta("depth_variation", depth_variation)
    root.set_meta("bow_variation", bow_variation)
    root.set_meta("shape_phase", shape_phase)
    root.set_meta("tilt_degrees", tilt_degrees)
    root.set_meta("tilt_randomized", true)

    var range_scale := clampf(definition.area_radius / 3.4, 0.68, 1.5)
    var visual_scale := range_scale * definition.size_multiplier * 1.22
    var wave_anchor := Node3D.new()
    wave_anchor.name = "SlashSwordWave"
    root.add_child(wave_anchor)
    _tag_vfx(wave_anchor, &"vfx_slash_wave")
    wave_anchor.global_position = world_position
    wave_anchor.set_meta("direction", attack_direction)
    wave_anchor.set_meta("screen_angle", _screen_space_angle(parent, world_position, attack_direction))
    _spawn_horizontal_slash_wave(
        wave_anchor,
        world_position + attack_direction * minf(definition.area_radius * 0.23, 0.82) + Vector3.UP * 0.86,
        attack_direction,
        visual_scale,
        sweep_direction,
        width_variation,
        depth_variation,
        bow_variation,
        shape_phase,
        tilt_degrees
    )
    _spawn_horizontal_slash_shadow_wake(
        root,
        world_position,
        attack_direction,
        visual_scale,
        sweep_direction,
        tilt_degrees
    )
    _spawn_radial_lines(
        root,
        world_position + Vector3.UP * 0.12,
        SHADOW_STYLE.ASH,
        12,
        1.45 * visual_scale,
        &"vfx_skill_identity"
    )
    _spawn_symbiote_tendrils(
        root,
        world_position + attack_direction * 0.18 + Vector3.UP * 0.08,
        attack_direction,
        visual_scale * 0.72,
        &"vfx_skill_identity"
    )

    var cleanup := root.create_tween()
    cleanup.tween_interval(0.58)
    cleanup.tween_callback(Callable(root, "queue_free"))


static func _spawn_slash_impact_smoke(
        parent: Node,
        definition: SkillDefinition,
        target_position: Vector3,
        direction: Vector3
) -> void:
    var flat_direction := direction
    flat_direction.y = 0.0
    flat_direction = flat_direction.normalized() if flat_direction.length_squared() > 0.01 else Vector3.FORWARD
    var root := Node3D.new()
    root.name = "SlashImpactSmokeVfx"
    parent.add_child(root)
    _tag_vfx(root, &"vfx_slash_impact")
    root.add_to_group(&"vfx_skill_identity")
    root.global_position = target_position
    root.set_meta("smoke_only", true)
    _spawn_slash_smoke_wake(
        root,
        target_position - flat_direction * 0.1,
        -flat_direction,
        definition.size_multiplier * 0.68,
        54.0
    )

    var cleanup := root.create_tween()
    cleanup.tween_interval(0.52)
    cleanup.tween_callback(Callable(root, "queue_free"))


static func _spawn_slash_smoke_wake(
        parent: Node,
        world_position: Vector3,
        direction: Vector3,
        size_multiplier: float,
        spread_degrees: float
) -> void:
    var wake := Node3D.new()
    wake.name = "SlashShadowSmoke"
    parent.add_child(wake)
    _tag_vfx(wake, &"vfx_slash_smoke")
    wake.add_to_group(&"vfx_skill_identity")
    wake.global_position = world_position
    var wisp_count := randi_range(11, 15)
    wake.set_meta("wisp_count", wisp_count)
    wake.set_meta("smoke_randomized", true)
    wake.set_meta("screen_angle", _screen_space_angle(parent, world_position, direction))
    var side := Vector3(-direction.z, 0.0, direction.x)
    for wisp_index: int in wisp_count:
        var progress := float(wisp_index) / float(wisp_count - 1)
        var angle := deg_to_rad(lerpf(-spread_degrees * 0.42, spread_degrees * 0.42, progress))
        var wisp_direction := direction.rotated(Vector3.UP, angle)
        var distance := lerpf(0.62, 1.28, sin(progress * PI)) * size_multiplier
        var wisp_position := (
            world_position
            + wisp_direction * distance
            + Vector3.UP * randf_range(0.62, 0.96)
        )
        var sprite := Sprite3D.new()
        sprite.name = "ShadowWisp%02d" % (wisp_index + 1)
        sprite.texture = SKILL_VFX_ASSETS.KENNEY_FIRE
        sprite.pixel_size = randf_range(0.0018, 0.00235) * size_multiplier
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sprite.no_depth_test = true
        sprite.rotation.z = _screen_space_angle(parent, wisp_position, wisp_direction) - PI * 0.5
        sprite.scale = Vector3(randf_range(0.8, 1.15), randf_range(0.48, 0.72), 1.0)
        sprite.modulate = Color(1.0, 1.0, 1.0, randf_range(0.78, 0.94))
        sprite.material_override = SHADOW_STYLE.sprite_material(
            SKILL_VFX_ASSETS.KENNEY_FIRE,
            &"shadow",
            randf_range(0.32, 0.4),
            0.24
        )
        wake.add_child(sprite)
        sprite.global_position = wisp_position

        var drift := (
            -direction * randf_range(0.16, 0.34)
            + side * randf_range(-0.18, 0.18)
            + Vector3.UP * randf_range(0.12, 0.3)
        ) * size_multiplier
        var motion := sprite.create_tween()
        motion.set_parallel(true)
        motion.set_trans(Tween.TRANS_QUAD)
        motion.set_ease(Tween.EASE_OUT)
        motion.tween_property(sprite, "global_position", wisp_position + drift, 0.44)
        motion.tween_property(sprite, "scale", sprite.scale * randf_range(1.38, 1.72), 0.44)
        motion.tween_property(sprite, "modulate:a", 0.0, 0.44)

    var cleanup := wake.create_tween()
    cleanup.tween_interval(0.48)
    cleanup.tween_callback(Callable(wake, "queue_free"))


static func _spawn_horizontal_slash_shadow_wake(
        parent: Node,
        world_position: Vector3,
        direction: Vector3,
        size_multiplier: float,
        sweep_direction: float,
        tilt_degrees: float
) -> void:
    var wake := Node3D.new()
    wake.name = "HorizontalSlashShadowWake"
    parent.add_child(wake)
    _tag_vfx(wake, &"vfx_slash_smoke")
    wake.add_to_group(&"vfx_skill_identity")
    wake.global_position = world_position
    var blade_wisp_count := randi_range(22, 27)
    var character_wisp_count := randi_range(11, 15)
    wake.set_meta("wisp_count", blade_wisp_count + character_wisp_count)
    wake.set_meta("blade_wisp_count", blade_wisp_count)
    wake.set_meta("character_wisp_count", character_wisp_count)
    wake.set_meta("smoke_mode", &"blade_and_character_wake")
    wake.set_meta("smoke_randomized", true)
    wake.set_meta("sweep_direction", sweep_direction)
    wake.set_meta("tilt_degrees", tilt_degrees)

    var blade_smoke := Node3D.new()
    blade_smoke.name = "BladeSlashSmoke"
    blade_smoke.set_meta("smoke_zone", &"blade")
    wake.add_child(blade_smoke)
    var character_smoke := Node3D.new()
    character_smoke.name = "CharacterSlashSmoke"
    character_smoke.set_meta("smoke_zone", &"character")
    wake.add_child(character_smoke)

    var side := Vector3(-direction.z, 0.0, direction.x)
    for wisp_index: int in blade_wisp_count:
        var progress := (float(wisp_index) + 0.5) / float(blade_wisp_count)
        var lateral_progress := lerpf(-1.5, 1.5, progress) + randf_range(-0.12, 0.12)
        var lateral_offset := lateral_progress * size_multiplier
        var bow_offset := (
            0.46 + sin(progress * PI) * 0.42 + randf_range(-0.075, 0.065)
        ) * size_multiplier
        var tilt_height := tan(deg_to_rad(tilt_degrees)) * lateral_progress * 0.72
        var wisp_position := (
            world_position
            + side * lateral_offset
            + direction * bow_offset
            + Vector3.UP * (
                0.75
                + sin(progress * PI) * 0.1
                + tilt_height
                + randf_range(-0.035, 0.035)
            ) * size_multiplier
        )
        var sprite := Sprite3D.new()
        sprite.name = "DraggedShadow%02d" % (wisp_index + 1)
        sprite.texture = SKILL_VFX_ASSETS.KENNEY_FIRE
        sprite.pixel_size = randf_range(0.00175, 0.0027) * size_multiplier
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sprite.no_depth_test = true
        sprite.rotation.z = (
            _screen_space_angle(parent, wisp_position, -direction)
            - PI * 0.5
            + deg_to_rad(tilt_degrees)
        )
        sprite.scale = Vector3(
            randf_range(0.7, 1.12),
            randf_range(0.44, 0.76),
            1.0
        )
        sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
        sprite.material_override = SHADOW_STYLE.sprite_material(
            SKILL_VFX_ASSETS.KENNEY_FIRE,
            &"body",
            randf_range(0.5, 0.66),
            0.08
        )
        blade_smoke.add_child(sprite)
        sprite.global_position = wisp_position

        var drift := (
            -direction * randf_range(0.36, 0.72)
            + side * randf_range(-0.2, 0.2)
            + Vector3.UP * randf_range(0.08, 0.34)
        ) * size_multiplier
        var reveal_index := wisp_index if sweep_direction > 0.0 else blade_wisp_count - 1 - wisp_index
        var delay := float(reveal_index) * 0.0055 + randf_range(0.0, 0.012)
        var motion := sprite.create_tween()
        motion.tween_interval(delay)
        motion.set_parallel(true)
        motion.set_trans(Tween.TRANS_QUAD)
        motion.set_ease(Tween.EASE_OUT)
        motion.tween_property(sprite, "global_position", wisp_position + drift, 0.36)
        motion.tween_property(sprite, "scale", sprite.scale * randf_range(1.5, 2.0), 0.36)
        motion.tween_property(sprite, "modulate:a", randf_range(0.72, 0.94), 0.025)
        motion.chain().tween_property(sprite, "modulate:a", 0.0, 0.32)

    for wisp_index: int in character_wisp_count:
        var radial_direction := (
            -direction * randf_range(0.18, 0.92)
            + side * randf_range(-0.82, 0.82)
        )
        radial_direction = (
            radial_direction.normalized()
            if radial_direction.length_squared() > 0.0001
            else -direction
        )
        var wisp_position := (
            world_position
            + radial_direction * randf_range(0.14, 0.7) * size_multiplier
            + Vector3.UP * randf_range(0.18, 0.72) * size_multiplier
        )
        var sprite := Sprite3D.new()
        sprite.name = "CharacterShadow%02d" % (wisp_index + 1)
        sprite.texture = SKILL_VFX_ASSETS.KENNEY_FIRE
        sprite.pixel_size = randf_range(0.00165, 0.0025) * size_multiplier
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sprite.no_depth_test = true
        sprite.rotation.z = _screen_space_angle(parent, wisp_position, radial_direction) - PI * 0.5
        sprite.scale = Vector3(
            randf_range(0.68, 1.08),
            randf_range(0.5, 0.9),
            1.0
        )
        sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
        sprite.material_override = SHADOW_STYLE.sprite_material(
            SKILL_VFX_ASSETS.KENNEY_FIRE,
            &"shadow",
            randf_range(0.36, 0.52),
            0.08
        )
        character_smoke.add_child(sprite)
        sprite.global_position = wisp_position

        var drift := (
            radial_direction * randf_range(0.12, 0.38)
            - direction * randf_range(0.06, 0.24)
            + Vector3.UP * randf_range(0.18, 0.42)
        ) * size_multiplier
        var delay := randf_range(0.0, 0.045)
        var motion := sprite.create_tween()
        motion.tween_interval(delay)
        motion.set_parallel(true)
        motion.set_trans(Tween.TRANS_QUAD)
        motion.set_ease(Tween.EASE_OUT)
        motion.tween_property(sprite, "global_position", wisp_position + drift, 0.42)
        motion.tween_property(sprite, "scale", sprite.scale * randf_range(1.48, 2.08), 0.42)
        motion.tween_property(sprite, "modulate:a", randf_range(0.52, 0.78), 0.03)
        motion.chain().tween_property(sprite, "modulate:a", 0.0, 0.37)

    var cleanup := wake.create_tween()
    cleanup.tween_interval(0.54)
    cleanup.tween_callback(Callable(wake, "queue_free"))


static func _spawn_horizontal_slash_wave(
        parent: Node,
        world_position: Vector3,
        direction: Vector3,
        size_multiplier: float,
        sweep_direction: float,
        width_variation: float,
        depth_variation: float,
        bow_variation: float,
        shape_phase: float,
        tilt_degrees: float
) -> void:
    var root := Node3D.new()
    root.name = "HorizontalSlashWave"
    parent.add_child(root)
    _tag_vfx(root, &"vfx_skill_identity")
    root.global_position = world_position
    root.set_meta("direction", direction)
    root.set_meta("swing_type", &"horizontal")
    root.set_meta("sweep_direction", sweep_direction)
    root.set_meta("visual_mode", &"procedural_cyclic")
    root.set_meta("erosion_mode", &"material_maker_circular_fbm")
    root.set_meta("tilt_degrees", tilt_degrees)
    root.set_meta("ribbon_count", 2)

    var ribbon := MeshInstance3D.new()
    ribbon.name = "SlashRibbon"
    var quad := QuadMesh.new()
    quad.size = Vector2(
        3.75 * size_multiplier * width_variation,
        1.9 * size_multiplier * depth_variation * bow_variation
    )
    ribbon.mesh = quad
    ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ribbon.extra_cull_margin = 1.0
    var screen_angle := _screen_space_angle(parent, world_position, direction)
    var material := SHADOW_STYLE.cyclic_slash_material()
    material.set_shader_parameter("sweep_direction", sweep_direction)
    material.set_shader_parameter("rotate_all", 285.0 + rad_to_deg(screen_angle) + tilt_degrees)
    material.set_shader_parameter("zoom", 0.62)
    material.set_shader_parameter("phase", shape_phase / TAU)
    ribbon.material_override = material
    root.add_child(ribbon)
    root.set_meta("screen_angle", screen_angle)

    var echo_ribbon := MeshInstance3D.new()
    echo_ribbon.name = "SlashEchoRibbon"
    var echo_quad := QuadMesh.new()
    echo_quad.size = quad.size * Vector2(1.12, 1.14)
    echo_ribbon.mesh = echo_quad
    echo_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    echo_ribbon.extra_cull_margin = 1.0
    var echo_material := SHADOW_STYLE.cyclic_slash_material(0.52)
    echo_material.render_priority = -1
    echo_material.set_shader_parameter("sweep_direction", sweep_direction)
    echo_material.set_shader_parameter("rotate_all", 281.5 + rad_to_deg(screen_angle) + tilt_degrees)
    echo_material.set_shader_parameter("zoom", 0.57)
    echo_material.set_shader_parameter("phase", shape_phase / TAU + 0.17)
    echo_material.set_shader_parameter("body_color", SHADOW_STYLE.SHADOW)
    echo_material.set_shader_parameter("rim_color", SHADOW_STYLE.ASH)
    echo_material.set_shader_parameter("emission_strength", 0.08)
    echo_ribbon.material_override = echo_material
    root.add_child(echo_ribbon)

    var sweep := ribbon.create_tween()
    sweep.set_trans(Tween.TRANS_QUART)
    sweep.set_ease(Tween.EASE_OUT)
    sweep.tween_property(material, "shader_parameter/progress", 1.0, 0.225)
    var dissolve := ribbon.create_tween()
    dissolve.tween_interval(0.145)
    dissolve.tween_property(material, "shader_parameter/dissolve_progress", 0.82, 0.16)
    var echo_sweep := echo_ribbon.create_tween()
    echo_sweep.tween_interval(0.035)
    echo_sweep.set_trans(Tween.TRANS_QUART)
    echo_sweep.set_ease(Tween.EASE_OUT)
    echo_sweep.tween_property(echo_material, "shader_parameter/progress", 1.0, 0.255)
    var echo_dissolve := echo_ribbon.create_tween()
    echo_dissolve.tween_interval(0.17)
    echo_dissolve.tween_property(echo_material, "shader_parameter/dissolve_progress", 0.92, 0.18)
    var cleanup := root.create_tween()
    cleanup.tween_interval(0.39)
    cleanup.tween_callback(Callable(root, "queue_free"))


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
    root.top_level = true
    _tag_vfx(root, &"vfx_chain_lightning")
    root.set_meta("from_position", from_position)
    root.set_meta("to_position", to_position)
    root.set_meta("visual_seed", visual_seed)
    root.set_meta("pulse_count", 2)
    root.set_meta("filaments_per_pulse", 2)
    root.set_meta("mesh_mode", &"camera_facing_array_mesh_ribbon")
    root.set_meta("style", &"pure_black_fissure")
    root.set_meta("exaggeration_scale", 1.18)
    root.set_meta("endpoint_mode", &"delegated_to_cast_hit_layers")
    root.set_meta("lifetime_seconds", 0.226)

    var camera_position := _chain_lightning_camera_position(parent, (from_position + to_position) * 0.5)
    var base_seed := absi(hash([from_position, to_position, visual_seed]))
    var point_counts := PackedInt32Array()
    var branch_counts := PackedInt32Array()
    var main_widths := PackedFloat32Array()
    var width_profile_signatures := PackedInt64Array()
    var path_signatures := PackedInt64Array()
    var pulse_nodes: Array[MeshInstance3D] = []
    var pulse_materials: Array[ShaderMaterial] = []
    for pulse_index: int in 2:
        var pulse_result := _create_chain_lightning_pulse(
            root,
            from_position,
            to_position,
            camera_position,
            absi(hash([base_seed, pulse_index])),
            pulse_index
        )
        var pulse_node := pulse_result["node"] as MeshInstance3D
        var pulse_material := pulse_result["material"] as ShaderMaterial
        pulse_nodes.append(pulse_node)
        pulse_materials.append(pulse_material)
        point_counts.append(int(pulse_result["point_count"]))
        branch_counts.append(int(pulse_result["branch_count"]))
        main_widths.append(float(pulse_result["main_width"]))
        width_profile_signatures.append(int(pulse_result["width_signature"]))
        path_signatures.append(int(pulse_result["signature"]))

    root.set_meta("main_point_counts", point_counts)
    root.set_meta("branch_counts", branch_counts)
    root.set_meta("main_widths", main_widths)
    root.set_meta("width_profile_signatures", width_profile_signatures)
    root.set_meta("path_signatures", path_signatures)
    pulse_nodes[1].hide()

    var timeline := root.create_tween()
    timeline.tween_interval(0.05)
    timeline.tween_callback(Callable(pulse_nodes[0], "hide"))
    timeline.tween_interval(0.012)
    timeline.tween_callback(Callable(pulse_nodes[1], "show"))
    timeline.tween_interval(0.08)
    timeline.tween_property(pulse_materials[1], "shader_parameter/opacity", 0.0, 0.084)
    timeline.tween_callback(Callable(root, "queue_free"))


static func _create_chain_lightning_pulse(
        parent: Node3D,
        from_position: Vector3,
        to_position: Vector3,
        camera_position: Vector3,
        pulse_seed: int,
        pulse_index: int
) -> Dictionary:
    var random := RandomNumberGenerator.new()
    random.seed = pulse_seed
    var length := from_position.distance_to(to_position)
    var recursion_depth := 4 if length <= 6.0 else 5
    var main_points := _generate_chain_lightning_path(
        from_position,
        to_position,
        random,
        recursion_depth,
        minf(length * 0.09, 0.46)
    )
    var branches := _generate_chain_lightning_branches(main_points, random, length)
    var main_width := clampf(length * 0.0195, 0.066, 0.12) * random.randf_range(0.88, 1.12)
    if pulse_index == 1:
        main_width *= random.randf_range(0.72, 0.84)
    var main_width_profile := _generate_chain_lightning_width_profile(
        main_points.size(),
        main_width,
        random,
        true
    )
    var companion_points := _generate_chain_lightning_companion(
        main_points,
        camera_position,
        main_width,
        random
    )

    var mesh := _build_chain_lightning_ribbon(
        main_points,
        companion_points,
        branches,
        main_width_profile,
        camera_position,
        random
    )
    var material := SHADOW_STYLE.chain_lightning_material(1.0, random.randf_range(0.0, 97.0))
    var pulse := MeshInstance3D.new()
    pulse.name = "PrimaryPulse" if pulse_index == 0 else "AftershockPulse"
    pulse.mesh = mesh
    pulse.material_override = material
    pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(pulse)

    var signature_data: Array = [main_points, companion_points]
    signature_data.append_array(branches)
    var signature := hash(signature_data)
    pulse.set_meta("pulse_index", pulse_index)
    pulse.set_meta("main_points", main_points)
    pulse.set_meta("companion_points", companion_points)
    pulse.set_meta("filament_count", 2)
    pulse.set_meta("branch_paths", branches)
    pulse.set_meta("branch_count", branches.size())
    pulse.set_meta("main_width", main_width)
    pulse.set_meta("main_width_profile", main_width_profile)
    pulse.set_meta("path_signature", signature)
    pulse.set_meta("surface_count", mesh.get_surface_count())
    return {
        "node": pulse,
        "material": material,
        "point_count": main_points.size(),
        "branch_count": branches.size(),
        "main_width": main_width,
        "width_signature": hash(main_width_profile),
        "signature": signature,
    }


static func _generate_chain_lightning_path(
        from_position: Vector3,
        to_position: Vector3,
        random: RandomNumberGenerator,
        recursion_depth: int,
        initial_amplitude: float
) -> PackedVector3Array:
    var forward := from_position.direction_to(to_position)
    var side := forward.cross(Vector3.UP)
    if side.length_squared() < 0.0001:
        side = forward.cross(Vector3.RIGHT)
    side = side.normalized()
    var lift := side.cross(forward).normalized()
    var points := PackedVector3Array([from_position, to_position])
    var amplitude := initial_amplitude
    for _level: int in recursion_depth:
        var subdivided := PackedVector3Array()
        var segment_total := points.size() - 1
        for segment_index: int in segment_total:
            subdivided.append(points[segment_index])
            var progress := (float(segment_index) + 0.5) / float(segment_total)
            var envelope := sin(PI * progress)
            var midpoint := (points[segment_index] + points[segment_index + 1]) * 0.5
            midpoint += side * random.randf_range(-amplitude, amplitude) * envelope
            midpoint += lift * random.randf_range(-amplitude * 0.38, amplitude * 0.38) * envelope
            subdivided.append(midpoint)
        subdivided.append(points[points.size() - 1])
        points = subdivided
        amplitude *= 0.62
    var detail_amplitude := initial_amplitude * 0.21
    for point_index: int in range(1, points.size() - 1):
        var progress := float(point_index) / float(points.size() - 1)
        var envelope := sin(PI * progress)
        points[point_index] += side * random.randf_range(-detail_amplitude, detail_amplitude) * envelope
        points[point_index] += lift * random.randf_range(-detail_amplitude * 0.42, detail_amplitude * 0.42) * envelope
    points[0] = from_position
    points[points.size() - 1] = to_position
    return points


static func _generate_chain_lightning_branches(
        main_points: PackedVector3Array,
        random: RandomNumberGenerator,
        main_length: float
) -> Array[PackedVector3Array]:
    var branches: Array[PackedVector3Array] = []
    var branch_count := random.randi_range(2, 4)
    for _branch_index: int in branch_count:
        var anchor_index := random.randi_range(2, main_points.size() - 3)
        var anchor := main_points[anchor_index]
        var tangent := (main_points[anchor_index + 1] - main_points[anchor_index - 1]).normalized()
        var side := tangent.cross(Vector3.UP)
        if side.length_squared() < 0.0001:
            side = tangent.cross(Vector3.RIGHT)
        side = side.normalized()
        var lift := side.cross(tangent).normalized()
        var sign_direction := -1.0 if random.randf() < 0.5 else 1.0
        var branch_direction := (
            tangent * random.randf_range(0.5, 0.78)
            + side * sign_direction * random.randf_range(0.48, 0.78)
            + lift * random.randf_range(-0.24, 0.24)
        ).normalized()
        var branch_length := clampf(main_length * random.randf_range(0.085, 0.17), 0.16, 0.72)
        var branch_end := anchor + branch_direction * branch_length
        branches.append(_generate_chain_lightning_path(
            anchor,
            branch_end,
            random,
            2,
            minf(branch_length * 0.24, 0.12)
        ))
    return branches


static func _generate_chain_lightning_companion(
        main_points: PackedVector3Array,
        camera_position: Vector3,
        main_width: float,
        random: RandomNumberGenerator
) -> PackedVector3Array:
    var companion := PackedVector3Array()
    var separation_sign := -1.0 if random.randf() < 0.5 else 1.0
    var separation_phase := random.randf_range(0.0, TAU)
    for point_index: int in main_points.size():
        var progress := float(point_index) / float(main_points.size() - 1)
        var envelope := pow(sin(PI * progress), 0.68)
        var tangent := _chain_lightning_tangent(main_points, point_index)
        var ribbon_side := _chain_lightning_ribbon_side(
            tangent,
            camera_position - main_points[point_index]
        )
        var separation := main_width * (
            2.45
            + sin(float(point_index) * 1.47 + separation_phase) * 0.52
            + random.randf_range(-0.24, 0.24)
        )
        companion.append(
            main_points[point_index]
            + ribbon_side * separation_sign * separation * envelope
        )
    companion[0] = main_points[0]
    companion[companion.size() - 1] = main_points[main_points.size() - 1]
    return companion


static func _spawn_symbiote_tendrils(
        parent: Node,
        world_position: Vector3,
        direction: Vector3,
        size_multiplier: float,
        category_group: StringName
) -> void:
    if parent == null:
        return
    var flat_direction := direction
    flat_direction.y = 0.0
    flat_direction = (
        flat_direction.normalized()
        if flat_direction.length_squared() > 0.0001
        else Vector3.FORWARD
    )
    var side := Vector3(-flat_direction.z, 0.0, flat_direction.x)
    var root := Node3D.new()
    root.name = "SymbioteTendrils"
    parent.add_child(root)
    root.top_level = true
    root.global_transform = Transform3D.IDENTITY
    _tag_vfx(root, category_group)
    root.add_to_group(&"vfx_symbiote_tendrils")
    root.set_meta("style", &"living_black_gloss")

    var random := RandomNumberGenerator.new()
    random.seed = absi(hash([world_position, direction, randi()]))
    var tendril_count := random.randi_range(5, 7)
    root.set_meta("tendril_count", tendril_count)
    var camera_position := _chain_lightning_camera_position(parent, world_position)
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for _tendril_index: int in tendril_count:
        var start := (
            world_position
            + side * random.randf_range(-0.42, 0.42) * size_multiplier
            + Vector3.UP * random.randf_range(0.34, 0.76) * size_multiplier
        )
        var curl_sign := -1.0 if random.randf() < 0.5 else 1.0
        var trail_direction := (
            -flat_direction * random.randf_range(0.62, 0.96)
            + side * random.randf_range(-0.72, 0.72)
            + Vector3.UP * random.randf_range(0.08, 0.42)
        ).normalized()
        var tendril_length := random.randf_range(0.68, 1.26) * size_multiplier
        var curl := side * curl_sign * random.randf_range(0.12, 0.3) * size_multiplier
        var lift := Vector3.UP * random.randf_range(0.08, 0.24) * size_multiplier
        var curl_phase := random.randf_range(-0.35, 0.35)
        var points := PackedVector3Array()
        for point_index: int in 9:
            var progress := float(point_index) / 8.0
            var curl_envelope := sin(PI * progress)
            var living_wobble := sin(progress * TAU * 1.5 + curl_phase) * curl * 0.22
            points.append(
                start
                + trail_direction * tendril_length * progress
                + curl * curl_envelope
                + living_wobble
                + lift * sin(progress * PI * 0.82)
            )
        var width_profile := _generate_chain_lightning_width_profile(
            points.size(),
            random.randf_range(0.04, 0.068) * clampf(size_multiplier, 0.65, 1.8),
            random,
            false
        )
        _append_chain_lightning_ribbon(surface, points, width_profile, camera_position)

    var tendrils := MeshInstance3D.new()
    tendrils.name = "LivingBlackTendrilMesh"
    tendrils.mesh = surface.commit()
    tendrils.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := SHADOW_STYLE.chain_lightning_material(0.82, random.randf_range(0.0, 97.0))
    material.set_shader_parameter("micro_jitter", 0.072)
    tendrils.material_override = material
    root.add_child(tendrils)

    var fade := root.create_tween()
    fade.tween_interval(0.1)
    fade.tween_property(material, "shader_parameter/opacity", 0.0, 0.28)
    fade.tween_callback(Callable(root, "queue_free"))


static func _build_chain_lightning_ribbon(
        main_points: PackedVector3Array,
        companion_points: PackedVector3Array,
        branches: Array[PackedVector3Array],
        main_width_profile: PackedFloat32Array,
        camera_position: Vector3,
        random: RandomNumberGenerator
) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    _append_chain_lightning_ribbon(surface, main_points, main_width_profile, camera_position)
    var main_width := _average_chain_lightning_width(main_width_profile)
    var companion_width_profile := _generate_chain_lightning_width_profile(
        companion_points.size(),
        main_width * 0.32,
        random,
        true
    )
    _append_chain_lightning_ribbon(
        surface,
        companion_points,
        companion_width_profile,
        camera_position
    )
    for branch: PackedVector3Array in branches:
        var branch_width := main_width * random.randf_range(0.38, 0.55)
        var branch_width_profile := _generate_chain_lightning_width_profile(
            branch.size(),
            branch_width,
            random,
            false
        )
        _append_chain_lightning_ribbon(surface, branch, branch_width_profile, camera_position)
    return surface.commit()


static func _append_chain_lightning_ribbon(
        surface: SurfaceTool,
        points: PackedVector3Array,
        width_profile: PackedFloat32Array,
        camera_position: Vector3
) -> void:
    var segment_count := points.size() - 1
    for segment_index: int in segment_count:
        var progress_from := float(segment_index) / float(segment_count)
        var progress_to := float(segment_index + 1) / float(segment_count)
        var tangent_from := _chain_lightning_tangent(points, segment_index)
        var tangent_to := _chain_lightning_tangent(points, segment_index + 1)
        var side_from := _chain_lightning_ribbon_side(tangent_from, camera_position - points[segment_index])
        var side_to := _chain_lightning_ribbon_side(tangent_to, camera_position - points[segment_index + 1])
        var width_from := width_profile[segment_index]
        var width_to := width_profile[segment_index + 1]
        var left_from := points[segment_index] - side_from * width_from
        var right_from := points[segment_index] + side_from * width_from
        var left_to := points[segment_index + 1] - side_to * width_to
        var right_to := points[segment_index + 1] + side_to * width_to
        _add_chain_lightning_triangle(surface, left_from, Vector2(0.0, progress_from), right_from, Vector2(1.0, progress_from), left_to, Vector2(0.0, progress_to))
        _add_chain_lightning_triangle(surface, right_from, Vector2(1.0, progress_from), right_to, Vector2(1.0, progress_to), left_to, Vector2(0.0, progress_to))


static func _add_chain_lightning_triangle(
        surface: SurfaceTool,
        first: Vector3,
        first_uv: Vector2,
        second: Vector3,
        second_uv: Vector2,
        third: Vector3,
        third_uv: Vector2
) -> void:
    surface.set_uv(first_uv)
    surface.add_vertex(first)
    surface.set_uv(second_uv)
    surface.add_vertex(second)
    surface.set_uv(third_uv)
    surface.add_vertex(third)


static func _chain_lightning_tangent(points: PackedVector3Array, point_index: int) -> Vector3:
    if point_index <= 0:
        return (points[1] - points[0]).normalized()
    if point_index >= points.size() - 1:
        return (points[points.size() - 1] - points[points.size() - 2]).normalized()
    return (points[point_index + 1] - points[point_index - 1]).normalized()


static func _chain_lightning_ribbon_side(tangent: Vector3, camera_delta: Vector3) -> Vector3:
    var view_direction := camera_delta.normalized()
    if view_direction.length_squared() < 0.0001:
        view_direction = Vector3(0.4, 0.7, 1.0).normalized()
    var side := tangent.cross(view_direction)
    if side.length_squared() < 0.0001:
        side = tangent.cross(Vector3.UP)
    if side.length_squared() < 0.0001:
        side = tangent.cross(Vector3.RIGHT)
    return side.normalized()


static func _generate_chain_lightning_width_profile(
        point_count: int,
        base_width: float,
        random: RandomNumberGenerator,
        symmetric_taper: bool
) -> PackedFloat32Array:
    var widths := PackedFloat32Array()
    var phase := random.randf_range(0.0, TAU)
    for point_index: int in point_count:
        var progress := float(point_index) / float(point_count - 1)
        var width_rhythm := (
            0.94
            + sin(float(point_index) * 1.83 + phase) * 0.27
            + sin(float(point_index) * 0.67 + phase * 1.41) * 0.15
            + random.randf_range(-0.09, 0.09)
        )
        var taper := 1.0
        if symmetric_taper:
            taper = lerpf(0.42, 1.0, pow(sin(PI * progress), 0.36))
        else:
            taper = lerpf(0.045, 1.0, pow(1.0 - progress, 0.72))
        widths.append(base_width * clampf(width_rhythm, 0.46, 1.5) * taper)
    return widths


static func _average_chain_lightning_width(width_profile: PackedFloat32Array) -> float:
    var total := 0.0
    for width: float in width_profile:
        total += width
    return total / float(width_profile.size())


static func _chain_lightning_camera_position(parent: Node, midpoint: Vector3) -> Vector3:
    var viewport := parent.get_viewport()
    if viewport != null:
        var camera := viewport.get_camera_3d()
        if camera != null:
            return camera.global_position
    return midpoint + Vector3(4.0, 6.0, 8.0)


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


static func spawn_channel_sustain(parent: Node3D, definition: SkillDefinition) -> Node3D:
    if parent == null or definition == null or definition.active_skill_id != &"whirlblade":
        return null
    var root := Node3D.new()
    root.name = "WhirlbladeChannelVfx"
    parent.add_child(root)
    _tag_vfx(root, &"vfx_channel_sustain")
    root.add_to_group(&"vfx_skill_identity")
    root.position = Vector3.UP * 0.78
    root.set_meta("follows_source", true)
    root.set_meta("rotation_period", 0.42)

    var primary := Node3D.new()
    primary.name = "PrimaryWindmill"
    root.add_child(primary)
    var secondary := Node3D.new()
    secondary.name = "SecondaryWindmill"
    root.add_child(secondary)
    var radius := 2.45 * definition.size_multiplier
    for blade_index: int in 4:
        _add_windmill_blade(
            primary,
            TAU * float(blade_index) / 4.0,
            radius,
            0.22,
            &"body"
        )
        _add_windmill_blade(
            secondary,
            TAU * float(blade_index) / 4.0 + PI * 0.25,
            radius * 0.72,
            0.1,
            &"ash"
        )

    var ring := MeshInstance3D.new()
    ring.name = "WhirlbladeRim"
    var torus := TorusMesh.new()
    torus.inner_radius = radius * 0.92
    torus.outer_radius = radius
    torus.rings = 12
    torus.ring_segments = 32
    ring.mesh = torus
    ring.material_override = SHADOW_STYLE.standard_material(&"rim", 0.48, 0.45)
    ring.position.y = -0.62
    root.add_child(ring)

    var primary_spin := root.create_tween()
    primary_spin.set_loops()
    primary_spin.tween_property(primary, "rotation:y", TAU, 0.42).from(0.0)
    var secondary_spin := root.create_tween()
    secondary_spin.set_loops()
    secondary_spin.tween_property(secondary, "rotation:y", -TAU, 0.68).from(0.0)
    return root


static func spawn_meteor_descent(
        parent: Node,
        target_position: Vector3,
        duration: float,
        area_radius: float
) -> Node3D:
    if parent == null:
        return null
    var root := Node3D.new()
    root.name = "MeteorDescentVfx"
    parent.add_child(root)
    root.top_level = true
    _tag_vfx(root, &"vfx_meteor_descent")
    root.add_to_group(&"vfx_skill_identity")
    var end_position := Vector3(target_position.x, maxf(target_position.y, 0.1) + 0.62, target_position.z)
    var start_position := end_position + Vector3(2.8, 9.4, 2.15)
    var travel_direction := (end_position - start_position).normalized()
    root.global_position = start_position
    root.set_meta("start_position", start_position)
    root.set_meta("end_position", end_position)
    root.set_meta("fall_duration", duration)
    root.set_meta("vfx_profile", &"living_black_meteor")
    root.set_meta("cc0_source", &"cethiel_fireball")
    root.set_meta("mesh_mode", &"procedural_ribbon_contrails")
    root.set_meta("tail_count", 5)
    root.set_meta("telegraph_layers", 3)
    root.set_meta("exaggeration_scale", 1.32)

    var meteor := MeshInstance3D.new()
    meteor.name = "BlackMeteorBody"
    var sphere := SphereMesh.new()
    sphere.radius = 0.88
    sphere.height = 1.76
    meteor.mesh = sphere
    meteor.material_override = SHADOW_STYLE.meteor_material(1.0, randf_range(0.0, 91.0), 0.68, 0.52)
    meteor.scale = Vector3(1.12, 0.9, 0.98)
    root.add_child(meteor)

    var rim := MeshInstance3D.new()
    rim.name = "MeteorWetShell"
    var rim_sphere := SphereMesh.new()
    rim_sphere.radius = 0.96
    rim_sphere.height = 1.92
    rim.mesh = rim_sphere
    rim.material_override = SHADOW_STYLE.meteor_material(0.26, randf_range(0.0, 91.0), 0.86, 0.18)
    rim.scale = Vector3(1.14, 0.9, 0.98)
    root.add_child(rim)

    var random := RandomNumberGenerator.new()
    random.seed = absi(hash([target_position, duration, area_radius, randi()]))
    for lobe_index: int in 3:
        var lobe := MeshInstance3D.new()
        lobe.name = "LivingMeteorLobe%02d" % lobe_index
        var lobe_mesh := SphereMesh.new()
        lobe_mesh.radius = random.randf_range(0.31, 0.48)
        lobe_mesh.height = lobe_mesh.radius * 2.0
        lobe.mesh = lobe_mesh
        lobe.material_override = SHADOW_STYLE.meteor_material(
            0.94,
            random.randf_range(0.0, 91.0),
            0.5,
            0.62
        )
        var lobe_angle := TAU * float(lobe_index) / 3.0 + random.randf_range(-0.35, 0.35)
        lobe.position = Vector3(cos(lobe_angle), random.randf_range(-0.28, 0.32), sin(lobe_angle)) * 0.56
        lobe.scale = Vector3(1.2, random.randf_range(0.68, 1.08), 0.82)
        root.add_child(lobe)

    var camera_position := _chain_lightning_camera_position(parent, start_position)
    var camera_local := camera_position - start_position
    var tail_side := travel_direction.cross(Vector3.UP)
    if tail_side.length_squared() < 0.0001:
        tail_side = travel_direction.cross(Vector3.RIGHT)
    tail_side = tail_side.normalized()
    var tail_lift := tail_side.cross(travel_direction).normalized()
    var tone_roles: Array[StringName] = [&"shadow", &"body", &"ash", &"body", &"rim"]
    for tail_index: int in 5:
        var tail_angle := TAU * float(tail_index) / 5.0 + random.randf_range(-0.28, 0.28)
        var radial_offset := (
            tail_side * cos(tail_angle) + tail_lift * sin(tail_angle)
        ) * random.randf_range(0.08, 0.34)
        _add_meteor_tail_ribbon(
            root,
            travel_direction,
            random.randf_range(2.45, 4.2),
            random.randf_range(0.13, 0.3),
            radial_offset,
            random.randf_range(0.0, TAU),
            tone_roles[tail_index],
            camera_local
        )
    _add_meteor_cc0_aura(
        root,
        duration,
        _screen_space_angle(parent, start_position, travel_direction)
    )
    _spawn_meteor_telegraph(parent, target_position, duration, area_radius)

    var fall := root.create_tween()
    fall.set_parallel(true)
    fall.set_trans(Tween.TRANS_QUAD)
    fall.set_ease(Tween.EASE_IN)
    fall.tween_property(root, "global_position", end_position, duration)
    fall.tween_property(meteor, "rotation", Vector3(4.4, 6.8, 3.2), duration)
    fall.tween_property(rim, "rotation", Vector3(-2.7, 4.9, -3.6), duration)
    fall.tween_property(root, "scale", Vector3.ONE * 1.32, duration)
    var cleanup := root.create_tween()
    cleanup.tween_interval(duration + 0.12)
    cleanup.tween_callback(Callable(root, "queue_free"))
    return root


static func spawn_meteor_impact(parent: Node, target_position: Vector3, area_radius: float) -> void:
    if parent == null:
        return
    var root := Node3D.new()
    root.name = "MeteorImpactVfx"
    parent.add_child(root)
    _tag_vfx(root, &"vfx_meteor_impact")
    root.add_to_group(&"vfx_skill_identity")
    root.set_meta("impact_position", target_position)
    root.set_meta("vfx_profile", &"symbiote_crater_collapse")
    root.set_meta("impact_stages", 2)
    root.set_meta("crown_spike_count", 14)
    root.set_meta("cc0_source", &"cethiel_fireball")
    root.set_meta("exaggeration_scale", 1.28)
    _spawn_ring(root, target_position, SHADOW_STYLE.BODY, area_radius * 1.28, 0.46, &"vfx_skill_identity", &"body")
    _spawn_ring(root, target_position + Vector3.UP * 0.05, SHADOW_STYLE.RIM, area_radius * 0.78, 0.25, &"vfx_skill_identity", &"rim")
    _spawn_texture_burst(
        root,
        SKILL_VFX_ASSETS.KENNEY_CIRCLE,
        target_position + Vector3.UP * 0.045,
        Color(0.02, 0.02, 0.02, 0.34),
        0.009,
        0.25,
        area_radius * 0.54,
        0.5,
        true,
        Vector3.FORWARD,
        &"vfx_skill_identity",
        1.35,
        &"body"
    )
    _spawn_texture_burst(
        root,
        SKILL_VFX_ASSETS.KENNEY_FIRE,
        target_position + Vector3.UP * 0.82,
        SHADOW_STYLE.BODY,
        0.0068,
        0.72,
        1.62,
        0.5,
        false,
        Vector3.RIGHT,
        &"vfx_skill_identity",
        0.52,
        &"body"
    )
    _spawn_texture_burst(
        root,
        SKILL_VFX_ASSETS.KENNEY_FIRE,
        target_position + Vector3(-0.5, 0.68, 0.18),
        SHADOW_STYLE.ASH,
        0.0056,
        0.58,
        1.28,
        0.46,
        false,
        Vector3(-0.75, 0.0, 0.66),
        &"vfx_skill_identity",
        -0.68,
        &"ash"
    )
    _spawn_texture_burst(
        root,
        SKILL_VFX_ASSETS.KENNEY_FIRE,
        target_position + Vector3(0.48, 0.64, -0.16),
        SHADOW_STYLE.SHADOW,
        0.0052,
        0.5,
        1.18,
        0.44,
        false,
        Vector3(0.72, 0.0, -0.7),
        &"vfx_skill_identity",
        0.74,
        &"shadow"
    )
    _spawn_cloud(root, target_position, SHADOW_STYLE.SHADOW, 28, area_radius * 0.96, &"vfx_skill_identity", &"shadow")
    _spawn_shards(root, target_position, SHADOW_STYLE.BODY, 22, area_radius * 0.92, &"vfx_skill_identity", &"body")
    _spawn_meteor_impact_crown(root, target_position, area_radius)
    _spawn_meteor_gravity_collapse(root, target_position, area_radius)
    _spawn_symbiote_tendrils(root, target_position + Vector3.UP * 0.08, Vector3.FORWARD, area_radius * 0.48, &"vfx_skill_identity")
    _spawn_symbiote_tendrils(root, target_position + Vector3.UP * 0.12, Vector3.RIGHT, area_radius * 0.42, &"vfx_skill_identity")
    var cleanup := root.create_tween()
    cleanup.tween_interval(0.78)
    cleanup.tween_callback(Callable(root, "queue_free"))


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


static func _add_windmill_blade(
        parent: Node3D,
        angle: float,
        length: float,
        width: float,
        tone_role: StringName
) -> void:
    var blade := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(width, 0.075, length)
    blade.mesh = mesh
    blade.material_override = SHADOW_STYLE.mesh_material(tone_role, 0.94, 0.024, 0.72)
    blade.position = Vector3(sin(angle), 0.0, cos(angle)) * length * 0.48
    blade.rotation.y = angle
    parent.add_child(blade)

    var edge := MeshInstance3D.new()
    var edge_mesh := BoxMesh.new()
    edge_mesh.size = Vector3(maxf(width * 0.24, 0.028), 0.035, length * 0.92)
    edge.mesh = edge_mesh
    edge.material_override = SHADOW_STYLE.standard_material(&"rim", 0.72, 0.5)
    edge.position = Vector3(sin(angle), 0.08, cos(angle)) * length * 0.48
    edge.rotation.y = angle
    parent.add_child(edge)


static func _add_meteor_tail_ribbon(
        parent: Node3D,
        travel_direction: Vector3,
        length: float,
        width: float,
        offset: Vector3,
        phase: float,
        tone_role: StringName,
        camera_position: Vector3
) -> void:
    var tail_direction := -travel_direction
    var side := tail_direction.cross(Vector3.UP)
    if side.length_squared() < 0.0001:
        side = tail_direction.cross(Vector3.RIGHT)
    side = side.normalized()
    var lift := side.cross(tail_direction).normalized()
    var points := PackedVector3Array()
    var width_profile := PackedFloat32Array()
    for point_index: int in 15:
        var progress := float(point_index) / 14.0
        var envelope := sin(PI * progress)
        var living_wave := sin(progress * TAU * 0.78 + phase)
        var secondary_wave := sin(progress * TAU * 1.62 - phase * 0.62)
        points.append(
            offset
            + tail_direction * length * progress
            + side * living_wave * width * (0.28 + progress * 0.92) * envelope
            + lift * secondary_wave * width * (0.16 + progress * 0.46) * envelope
        )
        var taper := pow(1.0 - progress, 0.8)
        var pulse := 0.93 + sin(progress * TAU * 1.7 + phase) * 0.07
        width_profile.append(maxf(width * taper * pulse, 0.006))

    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    _append_chain_lightning_ribbon(surface, points, width_profile, camera_position)
    var tail := MeshInstance3D.new()
    tail.name = "MeteorLivingContrail"
    tail.mesh = surface.commit()
    tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := SHADOW_STYLE.chain_lightning_material(
        0.88 if tone_role != &"rim" else 0.54,
        phase * 7.7
    )
    material.set_shader_parameter("micro_jitter", 0.048)
    tail.material_override = material
    tail.set_meta("tone_role", tone_role)
    tail.set_meta("point_count", points.size())
    parent.add_child(tail)


static func _add_meteor_cc0_aura(
        parent: Node3D,
        duration: float,
        screen_angle: float
) -> void:
    var frames := SKILL_VFX_ASSETS.get_meteor_frames()
    if frames == null or frames.get_frame_count(&"default") <= 0:
        return
    var sprite := AnimatedSprite3D.new()
    sprite.name = "MeteorCc0FireballAura"
    sprite.sprite_frames = frames
    sprite.animation = &"default"
    sprite.pixel_size = 0.0082
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.no_depth_test = true
    sprite.rotation.z = screen_angle
    sprite.offset = Vector2(34.0, 0.0)
    sprite.scale = Vector3.ONE * 0.84
    var first_texture := frames.get_frame_texture(&"default", 0)
    var material := SHADOW_STYLE.sprite_material(first_texture, &"body", 0.92, 0.62)
    sprite.material_override = material
    sprite.frame_changed.connect(func() -> void:
        if is_instance_valid(sprite) and sprite.sprite_frames != null:
            material.set_shader_parameter(
                "source_texture",
                sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
            )
    )
    parent.add_child(sprite)
    sprite.set_meta("cc0_source", &"cethiel_fireball")
    sprite.play()
    var pulse := sprite.create_tween()
    pulse.set_parallel(true)
    pulse.set_trans(Tween.TRANS_QUAD)
    pulse.set_ease(Tween.EASE_IN)
    pulse.tween_property(sprite, "scale", Vector3.ONE * 1.16, duration)
    pulse.tween_property(sprite, "modulate:a", 0.66, duration)


static func _spawn_meteor_telegraph(
        parent: Node,
        target_position: Vector3,
        duration: float,
        area_radius: float
) -> Node3D:
    var telegraph := Node3D.new()
    telegraph.name = "MeteorConvergenceTelegraph"
    parent.add_child(telegraph)
    telegraph.top_level = true
    telegraph.global_position = Vector3(
        target_position.x,
        maxf(target_position.y, 0.065),
        target_position.z
    )
    _tag_vfx(telegraph, &"vfx_meteor_telegraph")
    telegraph.add_to_group(&"vfx_skill_identity")
    telegraph.set_meta("telegraph_style", &"inward_symbiote_fangs")
    telegraph.set_meta("layer_count", 3)

    var outer_ring := MeshInstance3D.new()
    outer_ring.name = "MeteorOuterWarningRing"
    var outer_torus := TorusMesh.new()
    outer_torus.inner_radius = 0.83
    outer_torus.outer_radius = 0.98
    outer_torus.rings = 18
    outer_torus.ring_segments = 32
    outer_ring.mesh = outer_torus
    var outer_material := SHADOW_STYLE.standard_material(&"body", 0.86)
    outer_ring.material_override = outer_material
    outer_ring.scale = Vector3.ONE * area_radius * 1.28
    telegraph.add_child(outer_ring)

    var inner_ring := MeshInstance3D.new()
    inner_ring.name = "MeteorInnerCollapseRing"
    var inner_torus := TorusMesh.new()
    inner_torus.inner_radius = 0.72
    inner_torus.outer_radius = 0.94
    inner_torus.rings = 14
    inner_torus.ring_segments = 28
    inner_ring.mesh = inner_torus
    var inner_material := SHADOW_STYLE.standard_material(&"ash", 0.68)
    inner_ring.material_override = inner_material
    inner_ring.position.y = 0.028
    inner_ring.scale = Vector3.ONE * area_radius * 0.86
    telegraph.add_child(inner_ring)

    var fang_surface := SurfaceTool.new()
    fang_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var fang_count := 16
    for fang_index: int in fang_count:
        var angle := TAU * float(fang_index) / float(fang_count)
        var direction := Vector3(cos(angle), 0.0, sin(angle))
        var tangent := Vector3(-direction.z, 0.0, direction.x)
        var base := direction * area_radius * 0.91 + Vector3.UP * 0.045
        var tip := direction * area_radius * 0.5 + Vector3.UP * 0.052
        var half_width := area_radius * (0.026 if fang_index % 2 == 0 else 0.018)
        _add_chain_lightning_triangle(
            fang_surface,
            base - tangent * half_width,
            Vector2(0.0, 0.0),
            base + tangent * half_width,
            Vector2(1.0, 0.0),
            tip,
            Vector2(0.5, 1.0)
        )
    var fangs := MeshInstance3D.new()
    fangs.name = "MeteorInwardFangs"
    fangs.mesh = fang_surface.commit()
    var fang_material := SHADOW_STYLE.chain_lightning_material(0.74, randf_range(0.0, 91.0))
    fang_material.set_shader_parameter("micro_jitter", 0.04)
    fangs.material_override = fang_material
    fangs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    fangs.scale = Vector3.ONE * 1.16
    telegraph.add_child(fangs)

    _spawn_texture_burst(
        telegraph,
        SKILL_VFX_ASSETS.KENNEY_CIRCLE,
        telegraph.global_position + Vector3.UP * 0.018,
        SHADOW_STYLE.SHADOW,
        0.009,
        0.38,
        area_radius * 0.68,
        duration,
        true,
        Vector3.FORWARD,
        &"vfx_meteor_telegraph",
        -1.85,
        &"shadow"
    )

    var convergence := telegraph.create_tween()
    convergence.set_parallel(true)
    convergence.set_trans(Tween.TRANS_QUAD)
    convergence.set_ease(Tween.EASE_IN)
    convergence.tween_property(outer_ring, "scale", Vector3.ONE * area_radius * 0.92, duration)
    convergence.tween_property(inner_ring, "scale", Vector3.ONE * area_radius * 0.18, duration)
    convergence.tween_property(fangs, "scale", Vector3.ONE * 0.58, duration)
    convergence.tween_property(outer_material, "albedo_color:a", 0.18, duration)
    convergence.tween_property(inner_material, "albedo_color:a", 0.0, duration)
    convergence.tween_property(fang_material, "shader_parameter/opacity", 0.16, duration)
    var cleanup := telegraph.create_tween()
    cleanup.tween_interval(duration + 0.08)
    cleanup.tween_callback(Callable(telegraph, "queue_free"))
    return telegraph


static func _spawn_meteor_impact_crown(
        parent: Node,
        target_position: Vector3,
        area_radius: float
) -> void:
    var crown := Node3D.new()
    crown.name = "MeteorImpactCrown"
    parent.add_child(crown)
    crown.top_level = true
    crown.global_position = target_position
    _tag_vfx(crown, &"vfx_meteor_impact")
    crown.set_meta("spike_count", 14)
    crown.set_meta("mesh_mode", &"single_surface_tapered_ribbons")
    var camera_local := _chain_lightning_camera_position(parent, target_position) - target_position
    var random := RandomNumberGenerator.new()
    random.seed = absi(hash([target_position, area_radius, randi()]))
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for spike_index: int in 14:
        var angle := TAU * float(spike_index) / 14.0 + random.randf_range(-0.1, 0.1)
        var direction := Vector3(cos(angle), 0.0, sin(angle))
        var tangent := Vector3(-direction.z, 0.0, direction.x)
        var spike_length := area_radius * random.randf_range(0.46, 0.76)
        var spike_height := area_radius * random.randf_range(0.72, 1.08)
        var points := PackedVector3Array()
        var width_profile := PackedFloat32Array()
        for point_index: int in 7:
            var progress := float(point_index) / 6.0
            points.append(
                direction * spike_length * progress
                + Vector3.UP * (
                    sin(PI * progress) * spike_height * 0.62
                    + progress * spike_height * 0.48
                    + 0.06
                )
                + tangent * sin(progress * PI * 1.25 + angle) * area_radius * 0.028
            )
            width_profile.append(
                maxf(area_radius * 0.058 * pow(1.0 - progress, 0.72), 0.008)
            )
        _append_chain_lightning_ribbon(surface, points, width_profile, camera_local)

    var crown_mesh := MeshInstance3D.new()
    crown_mesh.name = "MeteorCrownRibbonMesh"
    crown_mesh.mesh = surface.commit()
    crown_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := SHADOW_STYLE.chain_lightning_material(0.94, random.randf_range(0.0, 91.0))
    material.set_shader_parameter("micro_jitter", 0.072)
    crown_mesh.material_override = material
    crown.add_child(crown_mesh)
    crown.scale = Vector3.ONE * 0.32

    var burst := crown.create_tween()
    burst.set_parallel(true)
    burst.set_trans(Tween.TRANS_BACK)
    burst.set_ease(Tween.EASE_OUT)
    burst.tween_property(crown, "scale", Vector3.ONE * 1.12, 0.24)
    burst.tween_property(material, "shader_parameter/opacity", 0.0, 0.48).set_delay(0.13)
    var cleanup := crown.create_tween()
    cleanup.tween_interval(0.64)
    cleanup.tween_callback(Callable(crown, "queue_free"))


static func _spawn_meteor_gravity_collapse(
        parent: Node,
        target_position: Vector3,
        area_radius: float
) -> void:
    var collapse := Node3D.new()
    collapse.name = "MeteorGravityCollapse"
    parent.add_child(collapse)
    collapse.top_level = true
    collapse.global_position = target_position
    _tag_vfx(collapse, &"vfx_meteor_impact")
    collapse.set_meta("stage", &"secondary_inward_collapse")

    var pillar := Node3D.new()
    pillar.name = "MeteorUmbraPillar"
    var pillar_material := SHADOW_STYLE.meteor_material(0.72, randf_range(0.0, 91.0), 0.42, 0.66)
    pillar.scale = Vector3(0.18, 0.04, 0.18)
    collapse.add_child(pillar)
    for lobe_index: int in 6:
        var lobe := MeshInstance3D.new()
        lobe.name = "UmbraPillarLobe%02d" % lobe_index
        var lobe_mesh := SphereMesh.new()
        var lobe_radius := area_radius * lerpf(0.25, 0.13, float(lobe_index) / 5.0)
        lobe_mesh.radius = lobe_radius
        lobe_mesh.height = lobe_radius * 2.0
        lobe.mesh = lobe_mesh
        lobe.material_override = pillar_material
        var lobe_angle := float(lobe_index) * 2.36
        lobe.position = Vector3(
            cos(lobe_angle) * area_radius * 0.07,
            area_radius * (0.2 + float(lobe_index) * 0.19),
            sin(lobe_angle) * area_radius * 0.07
        )
        lobe.scale = Vector3(
            1.0 + float(lobe_index % 2) * 0.18,
            1.18 + float((lobe_index + 1) % 3) * 0.12,
            0.88 + float(lobe_index % 3) * 0.1
        )
        pillar.add_child(lobe)

    var core := MeshInstance3D.new()
    core.name = "MeteorCollapseCore"
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.72
    core_mesh.height = 1.44
    core.mesh = core_mesh
    core.position.y = 0.5
    var core_material := SHADOW_STYLE.meteor_material(0.92, randf_range(0.0, 91.0), 0.74, 0.5)
    core.material_override = core_material
    core.scale = Vector3.ONE * 0.08
    collapse.add_child(core)

    var inward_ring := MeshInstance3D.new()
    inward_ring.name = "MeteorInwardShockRing"
    var inward_torus := TorusMesh.new()
    inward_torus.inner_radius = 0.75
    inward_torus.outer_radius = 0.96
    inward_torus.rings = 16
    inward_torus.ring_segments = 30
    inward_ring.mesh = inward_torus
    inward_ring.position.y = 0.08
    var ring_material := SHADOW_STYLE.standard_material(&"ash", 0.58)
    inward_ring.material_override = ring_material
    inward_ring.scale = Vector3.ONE * area_radius * 1.04
    collapse.add_child(inward_ring)

    var pillar_burst := collapse.create_tween()
    pillar_burst.tween_interval(0.04)
    pillar_burst.tween_property(pillar, "scale", Vector3(0.94, 1.0, 0.94), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pillar_burst.set_parallel(true)
    pillar_burst.tween_property(pillar, "scale", Vector3(1.28, 0.34, 1.28), 0.34).set_delay(0.16)
    pillar_burst.tween_property(pillar_material, "shader_parameter/opacity", 0.0, 0.3).set_delay(0.19)

    var core_collapse := collapse.create_tween()
    core_collapse.tween_interval(0.08)
    core_collapse.tween_property(core, "scale", Vector3.ONE * area_radius * 0.54, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    core_collapse.tween_property(core, "scale", Vector3.ONE * 0.035, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
    core_collapse.tween_property(core_material, "shader_parameter/opacity", 0.0, 0.08)

    var ring_collapse := collapse.create_tween()
    ring_collapse.tween_interval(0.12)
    ring_collapse.set_parallel(true)
    ring_collapse.set_trans(Tween.TRANS_EXPO)
    ring_collapse.set_ease(Tween.EASE_IN)
    ring_collapse.tween_property(inward_ring, "scale", Vector3.ONE * 0.06, 0.3)
    ring_collapse.tween_property(ring_material, "albedo_color:a", 0.0, 0.3)

    var cleanup := collapse.create_tween()
    cleanup.tween_interval(0.66)
    cleanup.tween_callback(Callable(collapse, "queue_free"))


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
    root.set_meta("direction", direction)

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
        sprite.rotation.z = _screen_space_angle(parent, world_position, direction)
        root.set_meta("screen_angle", sprite.rotation.z)
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
    root.set_meta("direction", direction)

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
        sprite.rotation.z = _screen_space_angle(parent, world_position, direction)
        root.set_meta("screen_angle", sprite.rotation.z)

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


static func _screen_space_angle(
        parent: Node,
        world_position: Vector3,
        direction: Vector3
) -> float:
    var flat_direction := direction
    flat_direction.y = 0.0
    if flat_direction.length_squared() <= 0.001:
        flat_direction = Vector3.FORWARD
    else:
        flat_direction = flat_direction.normalized()
    var viewport := parent.get_viewport()
    var camera := viewport.get_camera_3d() if viewport != null else null
    if camera != null:
        var screen_origin := camera.unproject_position(world_position)
        var screen_target := camera.unproject_position(world_position + flat_direction)
        var screen_direction := screen_target - screen_origin
        if screen_direction.length_squared() > 0.001:
            return atan2(screen_direction.y, screen_direction.x)
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
