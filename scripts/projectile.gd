class_name SkillProjectile
extends Area3D

signal impact_requested(projectile: SkillProjectile, target: Node3D)
signal released(projectile: SkillProjectile)
signal event_fired(message: String, event_color: Color)

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const SKILL_VFX_ASSETS := preload("res://scripts/skill_vfx_assets.gd")

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
var _bounces_remaining: int = 0
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _skill_sprite: AnimatedSprite3D


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
    _remaining_hits = 1 + definition.pierce_count + definition.bounce_count
    _bounces_remaining = definition.bounce_count
    _current_speed = definition.projectile_speed
    _hit_ids.clear()
    _trail_cooldown = 0.0
    _accent_cooldown = 0.0
    _active = true
    visible = true
    monitoring = true
    set_physics_process(true)
    add_to_group("skill_projectile")
    if _material != null:
        _material.albedo_color = definition.color
        _material.emission = definition.color
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
        _mesh_instance.scale = Vector3.ONE * 0.46 if _has_skill_identity_vfx() else Vector3.ONE


func resolve_impact(target: Node3D) -> void:
    if not _active:
        return
    var bounced := false
    if _bounces_remaining > 0:
        var next_target := _find_nearest_target(global_position, 10.0, _hit_ids)
        if next_target != null:
            var bounce_direction := next_target.global_position - global_position
            bounce_direction.y = 0.0
            if bounce_direction.length_squared() > 0.01:
                direction = bounce_direction.normalized()
                _bounces_remaining -= 1
                bounced = true
                COMBAT_VFX.spawn_bolt(
                    get_tree().current_scene,
                    global_position,
                    next_target.global_position + Vector3.UP,
                    definition.color
                )
    _remaining_hits -= 1
    if _remaining_hits <= 0:
        _expire(true)
    elif definition.bounce_count > 0 and not bounced and definition.pierce_count <= 0:
        _expire(true)
    else:
        global_position += direction * 0.35


func _physics_process(delta: float) -> void:
    if not _active or definition == null:
        return
    _lifetime_remaining -= delta
    if _lifetime_remaining <= 0.0:
        _expire(false)
        return
    if definition.homing_strength > 0.0:
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
    _current_speed += definition.projectile_acceleration * delta
    var previous_position := global_position
    global_position += direction * _current_speed * delta
    _trail_cooldown -= delta
    if visual_effects_enabled and _trail_cooldown <= 0.0:
        _trail_cooldown = 0.055
        COMBAT_VFX.spawn_projectile_trail(get_tree().current_scene, previous_position, definition.color, 0.19)
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
        if flat_offset.length_squared() <= 0.85 * 0.85:
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


func _expire(show_effect: bool) -> void:
    if not _active:
        return
    if show_effect and definition != null:
        COMBAT_VFX.spawn_pulse(get_tree().current_scene, global_position, definition.color, 0.35)
    deactivate()


func _build_visual() -> void:
    _mesh_instance = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.28
    sphere.height = 0.56
    _mesh_instance.mesh = sphere
    _material = StandardMaterial3D.new()
    _material.emission_enabled = true
    _material.emission_energy_multiplier = 2.3
    _mesh_instance.material_override = _material
    add_child(_mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.3
    collision.shape = shape
    add_child(collision)


func _configure_skill_sprite() -> void:
    if definition == null:
        return
    var frames := SKILL_VFX_ASSETS.get_projectile_frames(definition.active_skill_id)
    if frames == null or frames.get_frame_count(&"default") <= 0:
        if _skill_sprite != null:
            _skill_sprite.stop()
            _skill_sprite.visible = false
            _skill_sprite.sprite_frames = null
        _mesh_instance.scale = Vector3.ONE
        return
    _ensure_skill_sprite()
    _skill_sprite.sprite_frames = frames
    _skill_sprite.animation = &"default"
    _skill_sprite.pixel_size = SKILL_VFX_ASSETS.get_projectile_pixel_size(definition.active_skill_id)
    _skill_sprite.modulate = SKILL_VFX_ASSETS.get_projectile_modulate(
        definition.active_skill_id,
        definition.color
    )
    _skill_sprite.frame = 0
    _skill_sprite.visible = true
    _mesh_instance.scale = Vector3.ONE * 0.46
    _update_skill_sprite_rotation()
    if _skill_sprite.visible:
        _skill_sprite.play(&"default")


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
