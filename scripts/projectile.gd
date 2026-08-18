class_name SkillProjectile
extends Area3D

signal impact_requested(projectile: SkillProjectile, target: Node3D)
signal expiry_burst_requested(projectile: SkillProjectile, world_position: Vector3)
signal return_completed(projectile: SkillProjectile)
signal remnant_requested(projectile: SkillProjectile, world_position: Vector3)
signal released(projectile: SkillProjectile)
signal event_fired(message: String, event_color: Color)

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const SKILL_VFX_ASSETS := preload("res://scripts/skill_vfx_assets.gd")
const SHADOW_STYLE := preload("res://scripts/shadow_vfx_style.gd")

var definition: SkillDefinition
var source: Node3D
var context: Dictionary = {}
var can_split: bool = true
var visual_effects_enabled: bool = true
var direction: Vector3 = Vector3.FORWARD
var _lifetime_remaining: float = 1.0
var _remaining_hits: int = 1
var _hit_ids: Dictionary = {}
var _active: bool = false
var _trail_cooldown: float = 0.0
var _accent_cooldown: float = 0.0
var _current_speed: float = 0.0
var _returning: bool = false
var _remnant_cooldown: float = 0.0
var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _skill_sprite: AnimatedSprite3D
var _collision_shape: SphereShape3D


func _ready() -> void:
    collision_layer = 0
    collision_mask = 2
    monitorable = false
    body_entered.connect(_on_body_entered)
    _build_visual()
    deactivate(false)


func activate(
        skill_definition: SkillDefinition,
        source_node: Node3D,
        origin: Vector3,
        new_direction: Vector3,
        event_context: Dictionary,
        allow_split: bool,
        enable_visual_effects: bool = true
) -> void:
    definition = skill_definition
    source = source_node
    context = event_context.duplicate(true)
    can_split = allow_split
    visual_effects_enabled = enable_visual_effects
    direction = new_direction.normalized()
    global_position = origin
    _lifetime_remaining = definition.projectile_lifetime
    _remaining_hits = 1 + definition.pierce_count
    _returning = false
    _current_speed = definition.projectile_speed
    _hit_ids.clear()
    _trail_cooldown = 0.0
    _accent_cooldown = 0.0
    _remnant_cooldown = 0.0
    _active = true
    visible = true
    monitoring = true
    set_physics_process(true)
    add_to_group("skill_projectile")
    _configure_core_mesh()
    if _collision_shape != null:
        _collision_shape.radius = (
            0.82 * definition.width_multiplier * definition.size_multiplier
            if definition.core_behavior == &"wave"
            else 0.3 * maxf(definition.size_multiplier, definition.width_multiplier)
        )
    if _mesh_instance != null:
        _mesh_instance.scale = Vector3.ONE * definition.size_multiplier
    _configure_skill_sprite()


func deactivate(emit_release: bool = true) -> void:
    if not _active and emit_release:
        return
    _active = false
    visible = false
    monitoring = false
    set_physics_process(false)
    remove_from_group("skill_projectile")
    if _skill_sprite != null:
        _skill_sprite.stop()
        _skill_sprite.visible = false
    if emit_release:
        released.emit(self)


func set_visual_effects_enabled(enabled: bool) -> void:
    visual_effects_enabled = enabled
    if _active and definition != null and _skill_sprite == null:
        _configure_skill_sprite()
    if _skill_sprite != null:
        _skill_sprite.visible = _active and _has_skill_identity_vfx()
        if _skill_sprite.visible:
            if not _skill_sprite.is_playing():
                _skill_sprite.play(&"default")
        else:
            _skill_sprite.stop()
    if _mesh_instance != null:
        var identity_scale := 0.46 if _has_skill_identity_vfx() else 1.0
        _mesh_instance.scale = Vector3.ONE * identity_scale * (definition.size_multiplier if definition != null else 1.0)


func resolve_impact(target: Node3D) -> void:
    if not _active:
        return
    if _returning:
        global_position += direction * 0.35
        return
    _remaining_hits -= 1
    if _remaining_hits <= 0:
        _begin_return_or_expire(true)
    else:
        global_position += direction * 0.35


func _physics_process(delta: float) -> void:
    if not _active or definition == null:
        return
    _lifetime_remaining -= delta
    if _lifetime_remaining <= 0.0:
        _begin_return_or_expire(false)
        if not _active:
            return
    if _returning:
        if not is_instance_valid(source):
            _expire(false)
            return
        var return_target := source.global_position + Vector3.UP * 1.0
        var return_offset := return_target - global_position
        return_offset.y = 0.0
        if return_offset.length() <= 0.65:
            return_completed.emit(self)
            _expire(false, false)
            return
        direction = return_offset.normalized()
    elif definition.homing_strength > 0.0:
        var target := _find_nearest_target(global_position, INF, _hit_ids)
        if target != null:
            var desired := target.global_position - global_position
            desired.y = 0.0
            if desired.length_squared() > 0.01:
                direction = direction.lerp(
                    desired.normalized(),
                    clampf(definition.homing_strength * delta, 0.0, 1.0)
                ).normalized()
    if definition.rotation_speed != 0.0:
        direction = direction.rotated(Vector3.UP, definition.rotation_speed * delta).normalized()
    _update_skill_sprite_rotation()
    var previous_position := global_position
    global_position += direction * _current_speed * delta
    _trail_cooldown -= delta
    if visual_effects_enabled and _trail_cooldown <= 0.0:
        _trail_cooldown = 0.055
        COMBAT_VFX.spawn_core_projectile_trail(
            get_tree().current_scene,
            definition,
            previous_position,
            direction,
            0.19
        )
    _remnant_cooldown -= delta
    if definition.remnant_enabled and _remnant_cooldown <= 0.0:
        _remnant_cooldown = maxf(definition.remnant_tick_interval, 0.12)
        remnant_requested.emit(self, previous_position)
    _accent_cooldown -= delta
    if visual_effects_enabled and _accent_cooldown <= 0.0:
        _accent_cooldown = 0.13
        COMBAT_VFX.spawn_flight_accent(get_tree().current_scene, definition, global_position, direction)
    _scan_segment_for_targets(previous_position, global_position)


func _on_body_entered(body: Node3D) -> void:
    if not _active or not body.is_in_group("damageable"):
        return
    var body_id := body.get_instance_id()
    if _hit_ids.has(body_id):
        return
    _hit_ids[body_id] = true
    impact_requested.emit(self, body)


func _scan_segment_for_targets(from_position: Vector3, to_position: Vector3) -> void:
    var segment := to_position - from_position
    segment.y = 0.0
    var segment_length_squared := segment.length_squared()
    for target: Node in get_tree().get_nodes_in_group("damageable"):
        if not _active or not target is Node3D or _hit_ids.has(target.get_instance_id()):
            continue
        var target_3d := target as Node3D
        var to_target := target_3d.global_position - from_position
        to_target.y = 0.0
        var closest_weight := 0.0
        if segment_length_squared > 0.0001:
            closest_weight = clampf(to_target.dot(segment) / segment_length_squared, 0.0, 1.0)
        var closest_point := from_position + segment * closest_weight
        var flat_offset := target_3d.global_position - closest_point
        flat_offset.y = 0.0
        var hit_radius := 0.85 * definition.size_multiplier
        if definition.core_behavior == &"wave":
            hit_radius = 0.82 * definition.width_multiplier * definition.size_multiplier
        if flat_offset.length_squared() <= hit_radius * hit_radius:
            _on_body_entered(target_3d)


func _find_nearest_target(
        from_position: Vector3,
        maximum_distance: float,
        excluded_ids: Dictionary
) -> Node3D:
    var nearest: Node3D
    var nearest_distance := maximum_distance
    for target: Node in get_tree().get_nodes_in_group("damageable"):
        if not target is Node3D or excluded_ids.has(target.get_instance_id()):
            continue
        var target_3d := target as Node3D
        var distance := target_3d.global_position.distance_to(from_position)
        if distance < nearest_distance:
            nearest = target_3d
            nearest_distance = distance
    return nearest


func _expire(show_effect: bool, request_expiry_burst: bool = false) -> void:
    if not _active:
        return
    if show_effect and definition != null:
        COMBAT_VFX.spawn_pulse(get_tree().current_scene, global_position, definition.color, 0.35)
    elif definition != null and visual_effects_enabled:
        COMBAT_VFX.spawn_core_end(get_tree().current_scene, definition, global_position, direction)
    if request_expiry_burst and definition != null and definition.impact_radius > 0.0:
        expiry_burst_requested.emit(self, global_position)
    deactivate()


func _begin_return_or_expire(show_effect: bool) -> void:
    if definition != null and definition.return_enabled and not _returning and is_instance_valid(source):
        _returning = true
        _lifetime_remaining = definition.projectile_lifetime * definition.return_speed_multiplier
        _current_speed = definition.projectile_speed * definition.return_speed_multiplier
        _remaining_hits = 1 + definition.pierce_count
        return
    _expire(show_effect, not show_effect)


func _build_visual() -> void:
    _mesh_instance = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.28
    sphere.height = 0.56
    _mesh_instance.mesh = sphere
    _material = SHADOW_STYLE.mesh_material(&"body", 0.96, 0.018, 0.68)
    _mesh_instance.material_override = _material
    add_child(_mesh_instance)
    var collision := CollisionShape3D.new()
    _collision_shape = SphereShape3D.new()
    _collision_shape.radius = 0.3
    collision.shape = _collision_shape
    add_child(collision)


func _configure_core_mesh() -> void:
    if definition == null or _mesh_instance == null:
        return
    _mesh_instance.rotation = Vector3.ZERO
    match definition.active_skill_id:
        &"arrow_shot":
            var arrow := BoxMesh.new()
            arrow.size = Vector3(0.1, 0.1, 1.35)
            _mesh_instance.mesh = arrow
        &"frost_lance":
            var lance := PrismMesh.new()
            lance.size = Vector3(0.24, 0.24, 1.75)
            _mesh_instance.mesh = lance
            _mesh_instance.rotation.x = PI * 0.5
        &"shockwave":
            var wave := BoxMesh.new()
            wave.size = Vector3(1.45 * definition.width_multiplier, 0.62, 0.22)
            _mesh_instance.mesh = wave
        _:
            var orb := SphereMesh.new()
            orb.radius = 0.28
            orb.height = 0.56
            _mesh_instance.mesh = orb
    _mesh_instance.rotation.y = atan2(direction.x, direction.z)


func _configure_skill_sprite() -> void:
    if definition == null:
        return
    var frames := SKILL_VFX_ASSETS.get_projectile_frames(definition.active_skill_id)
    if frames == null or frames.get_frame_count(&"default") <= 0:
        if _skill_sprite != null:
            _skill_sprite.stop()
            _skill_sprite.visible = false
            _skill_sprite.sprite_frames = null
        _mesh_instance.scale = Vector3.ONE * definition.size_multiplier
        return
    _ensure_skill_sprite()
    _skill_sprite.sprite_frames = frames
    _skill_sprite.animation = &"default"
    _skill_sprite.pixel_size = SKILL_VFX_ASSETS.get_projectile_pixel_size(definition.active_skill_id)
    _skill_sprite.modulate = Color.WHITE
    var first_texture := frames.get_frame_texture(&"default", 0)
    var shadow_material := SHADOW_STYLE.sprite_material(first_texture, &"body", 1.0, 0.78)
    _skill_sprite.material_override = shadow_material
    if not _skill_sprite.frame_changed.is_connected(_on_skill_sprite_frame_changed):
        _skill_sprite.frame_changed.connect(_on_skill_sprite_frame_changed)
    _skill_sprite.frame = 0
    _skill_sprite.visible = true
    _mesh_instance.scale = Vector3.ONE * 0.46 * definition.size_multiplier
    _update_skill_sprite_rotation()
    if _skill_sprite.visible:
        _skill_sprite.play(&"default")


func _on_skill_sprite_frame_changed() -> void:
    if (
        _skill_sprite == null
        or _skill_sprite.sprite_frames == null
        or not _skill_sprite.material_override is ShaderMaterial
    ):
        return
    (_skill_sprite.material_override as ShaderMaterial).set_shader_parameter(
        "source_texture",
        _skill_sprite.sprite_frames.get_frame_texture(_skill_sprite.animation, _skill_sprite.frame)
    )


func _has_skill_identity_vfx() -> bool:
    return (
        _skill_sprite != null
        and _skill_sprite.sprite_frames != null
        and _skill_sprite.sprite_frames.get_frame_count(&"default") > 0
    )


func _ensure_skill_sprite() -> void:
    if _skill_sprite != null:
        return
    _skill_sprite = AnimatedSprite3D.new()
    _skill_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _skill_sprite.no_depth_test = true
    _skill_sprite.visible = false
    _skill_sprite.position = Vector3.UP * 0.08
    add_child(_skill_sprite)


func _update_skill_sprite_rotation() -> void:
    if _skill_sprite == null or not _skill_sprite.visible:
        return
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        var camera_direction := camera.global_transform.basis.inverse() * direction
        _skill_sprite.rotation.z = atan2(-camera_direction.y, camera_direction.x)
        return
    _skill_sprite.rotation.z = atan2(-direction.z, direction.x)
