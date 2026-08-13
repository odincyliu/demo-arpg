class_name PlayerController
extends CharacterBody3D

signal combat_event(message: String, event_color: Color)
signal skill_changed(graph: SkillGraph)

const SKILL_GRAPH_EXECUTOR_SCRIPT := preload("res://scripts/skill_graph_executor.gd")
const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")

@export var movement_speed: float = 7.0
@export var movement_acceleration: float = 34.0
@export var movement_deceleration: float = 42.0
@export var destination_stop_distance: float = 0.22
@export var destination_slow_radius: float = 1.35
@export var cast_movement_lock: float = 0.12
@export var arena_limit: float = 13.2
@export var dash_speed: float = 18.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.72

var current_graph: SkillGraph
var current_skill: SkillDefinition
var max_health: float = 100.0
var health: float = 100.0
var _camera: Camera3D
var _skill_executor: SkillGraphExecutor
var _facing_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
var _cooldown_remaining: float = 0.0
var _dash_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_direction: Vector3 = Vector3.FORWARD
var _dash_trail_timer: float = 0.0
var _cast_lock_remaining: float = 0.0
var _has_move_destination: bool = false
var _move_destination: Vector3 = Vector3.ZERO
var _locomotion_time: float = 0.0
var _visual_root: Node3D
var _locomotion_root: Node3D
var _move_marker: MeshInstance3D
var _motion_tween: Tween


func _ready() -> void:
    add_to_group("player")
    collision_layer = 1
    collision_mask = 0
    _build_visuals()
    _build_move_marker()

    _skill_executor = SKILL_GRAPH_EXECUTOR_SCRIPT.new()
    _skill_executor.configure(self)
    _skill_executor.event_fired.connect(_on_runtime_event)
    add_child(_skill_executor)


func _physics_process(delta: float) -> void:
    _cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
    _dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)
    _cast_lock_remaining = maxf(_cast_lock_remaining - delta, 0.0)
    _update_held_arpg_actions()
    _update_movement(delta)
    _update_facing(delta)
    _update_locomotion_visual(delta)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("dash"):
        try_dash()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("simulate_damage"):
        simulate_damage()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("cast_skill"):
        _begin_attack_command()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("move_to_cursor"):
        if Input.is_action_pressed("force_attack"):
            _begin_attack_command()
        else:
            set_move_destination(_get_mouse_world_position())
        get_viewport().set_input_as_handled()


func set_view_camera(view_camera: Camera3D) -> void:
    _camera = view_camera


func set_skill_graph(graph: SkillGraph) -> void:
    if graph == null or not graph.is_valid():
        return
    current_graph = graph
    current_skill = graph.get_primary_skill()
    _skill_executor.set_graph(graph)
    _cooldown_remaining = 0.0
    skill_changed.emit(graph)


func try_cast_skill() -> void:
    if current_graph == null or _cooldown_remaining > 0.0:
        return
    var aim_position := _get_mouse_world_position()
    _face_toward(aim_position, true)
    if _skill_executor.request_manual_cast(aim_position, _facing_direction):
        _cooldown_remaining = current_skill.cooldown
        _cast_lock_remaining = cast_movement_lock
        _animate_cast()


func try_dash() -> void:
    if _dash_cooldown_remaining > 0.0:
        return
    var input_direction := _get_keyboard_move_direction()
    if input_direction.length_squared() <= 0.0 and _has_move_destination:
        input_direction = _direction_to_destination()
    _dash_direction = input_direction if input_direction.length_squared() > 0.0 else _facing_direction
    _dash_remaining = dash_duration
    _dash_cooldown_remaining = dash_cooldown
    _dash_trail_timer = 0.0
    _animate_dash()
    combat_event.emit("衝刺", Color("7ad7ff"))
    _skill_executor.request_external_event(&"dash", global_position)


func simulate_damage() -> void:
    health = maxf(health - 24.0, 1.0)
    COMBAT_VFX.spawn_pulse(
        get_tree().current_scene,
        global_position + Vector3.UP,
        Color("ff496f"),
        1.1
    )
    combat_event.emit("模擬受傷 -24", Color("ff688a"))
    _skill_executor.request_external_event(&"damaged", global_position)


func heal(amount: float) -> void:
    health = minf(health + amount, max_health)
    COMBAT_VFX.spawn_pulse(
        get_tree().current_scene,
        global_position + Vector3.UP,
        Color("ff79ad"),
        0.65
    )


func get_cooldown_remaining() -> float:
    return _cooldown_remaining


func get_cooldown_duration() -> float:
    return current_skill.cooldown if current_skill != null else 1.0


func get_aim_world_position() -> Vector3:
    return _get_mouse_world_position()


func get_facing_direction() -> Vector3:
    return _facing_direction


func get_skill_executor() -> SkillGraphExecutor:
    return _skill_executor


func set_move_destination(world_position: Vector3) -> void:
    _move_destination = Vector3(
        clampf(world_position.x, -arena_limit, arena_limit),
        global_position.y,
        clampf(world_position.z, -arena_limit, arena_limit)
    )
    _has_move_destination = true
    if _move_marker != null:
        _move_marker.global_position = _move_destination + Vector3.UP * 0.045
        _move_marker.visible = true


func cancel_move_destination() -> void:
    _has_move_destination = false
    if _move_marker != null:
        _move_marker.visible = false


func has_move_destination() -> bool:
    return _has_move_destination


func get_move_destination() -> Vector3:
    return _move_destination


func _get_mouse_world_position() -> Vector3:
    if _camera == null:
        return global_position + _facing_direction * 5.0
    var viewport_mouse := get_viewport().get_mouse_position()
    var ray_origin := _camera.project_ray_origin(viewport_mouse)
    var ray_direction := _camera.project_ray_normal(viewport_mouse)
    var intersection: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
    return intersection as Vector3 if intersection != null else global_position + _facing_direction * 5.0


func _update_movement(delta: float) -> void:
    if _dash_remaining > 0.0:
        _dash_remaining = maxf(_dash_remaining - delta, 0.0)
        velocity.x = _dash_direction.x * dash_speed
        velocity.z = _dash_direction.z * dash_speed
        _dash_trail_timer -= delta
        if _dash_trail_timer <= 0.0:
            _dash_trail_timer = 0.035
            COMBAT_VFX.spawn_dash_ghost(
                get_tree().current_scene,
                global_position,
                rotation.y,
                Color("48bfff")
            )
    else:
        var move_direction := _get_move_direction()
        if _cast_lock_remaining > 0.0 or Input.is_action_pressed("force_attack"):
            move_direction = Vector3.ZERO
        var desired_velocity := move_direction * movement_speed
        var response := movement_acceleration if move_direction.length_squared() > 0.0 else movement_deceleration
        velocity.x = move_toward(velocity.x, desired_velocity.x, response * delta)
        velocity.z = move_toward(velocity.z, desired_velocity.z, response * delta)
    velocity.y = 0.0
    move_and_slide()
    global_position.x = clampf(global_position.x, -arena_limit, arena_limit)
    global_position.z = clampf(global_position.z, -arena_limit, arena_limit)


func _get_move_direction() -> Vector3:
    var keyboard_direction := _get_keyboard_move_direction()
    if keyboard_direction.length_squared() > 0.0:
        cancel_move_destination()
        return keyboard_direction
    if not _has_move_destination:
        return Vector3.ZERO
    var offset := _move_destination - global_position
    offset.y = 0.0
    var distance := offset.length()
    if distance <= destination_stop_distance:
        cancel_move_destination()
        return Vector3.ZERO
    var speed_scale := clampf(distance / destination_slow_radius, 0.18, 1.0)
    return offset.normalized() * speed_scale


func _get_keyboard_move_direction() -> Vector3:
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if input_vector.length_squared() <= 0.0:
        return Vector3.ZERO
    if _camera == null:
        return Vector3(input_vector.x, 0.0, input_vector.y).normalized()
    var camera_forward := -_camera.global_transform.basis.z
    camera_forward.y = 0.0
    camera_forward = camera_forward.normalized()
    var camera_right := _camera.global_transform.basis.x
    camera_right.y = 0.0
    camera_right = camera_right.normalized()
    return (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()


func _direction_to_destination() -> Vector3:
    var direction := _move_destination - global_position
    direction.y = 0.0
    return direction.normalized() if direction.length_squared() > 0.01 else Vector3.ZERO


func _update_facing(delta: float) -> void:
    var desired_direction := Vector3.ZERO
    var aiming := (
        _cast_lock_remaining > 0.0
        or Input.is_action_pressed("cast_skill")
        or (Input.is_action_pressed("force_attack") and Input.is_action_pressed("move_to_cursor"))
    )
    if aiming:
        desired_direction = _get_mouse_world_position() - global_position
    else:
        desired_direction = Vector3(velocity.x, 0.0, velocity.z)
    desired_direction.y = 0.0
    if desired_direction.length_squared() < 0.04:
        return
    _facing_direction = desired_direction.normalized()
    var target_rotation := atan2(-_facing_direction.x, -_facing_direction.z)
    rotation.y = lerp_angle(rotation.y, target_rotation, 1.0 - exp(-18.0 * delta))


func _face_toward(world_position: Vector3, immediate: bool = false) -> void:
    var direction := world_position - global_position
    direction.y = 0.0
    if direction.length_squared() < 0.04:
        return
    _facing_direction = direction.normalized()
    if immediate:
        rotation.y = atan2(-_facing_direction.x, -_facing_direction.z)


func _update_held_arpg_actions() -> void:
    var move_held := Input.is_action_pressed("move_to_cursor")
    var cast_held := Input.is_action_pressed("cast_skill")
    if not move_held and not cast_held:
        return
    if _is_pointer_over_ui():
        return
    var force_attack := Input.is_action_pressed("force_attack")
    if cast_held or (force_attack and move_held):
        _begin_attack_command()
    elif move_held:
        set_move_destination(_get_mouse_world_position())


func _begin_attack_command() -> void:
    cancel_move_destination()
    try_cast_skill()


func _is_pointer_over_ui() -> bool:
    var viewport := get_viewport()
    if viewport == null:
        return false
    return viewport.gui_get_hovered_control() != null


func _on_runtime_event(message: String, event_color: Color) -> void:
    combat_event.emit(message, event_color)


func _build_visuals() -> void:
    _visual_root = Node3D.new()
    add_child(_visual_root)
    _locomotion_root = Node3D.new()
    _visual_root.add_child(_locomotion_root)

    var player_material := StandardMaterial3D.new()
    player_material.albedo_color = Color("3b78d8")
    player_material.roughness = 0.72

    var body_mesh := MeshInstance3D.new()
    var capsule_mesh := CapsuleMesh.new()
    capsule_mesh.radius = 0.48
    capsule_mesh.height = 1.65
    body_mesh.mesh = capsule_mesh
    body_mesh.material_override = player_material
    body_mesh.position.y = 0.95
    _locomotion_root.add_child(body_mesh)

    var head_mesh := MeshInstance3D.new()
    var sphere_mesh := SphereMesh.new()
    sphere_mesh.radius = 0.38
    sphere_mesh.height = 0.76
    head_mesh.mesh = sphere_mesh
    head_mesh.material_override = player_material
    head_mesh.position.y = 1.92
    _locomotion_root.add_child(head_mesh)

    var facing_marker := MeshInstance3D.new()
    var marker_mesh := BoxMesh.new()
    marker_mesh.size = Vector3(0.18, 0.15, 0.72)
    facing_marker.mesh = marker_mesh
    var marker_material := StandardMaterial3D.new()
    marker_material.albedo_color = Color("f8e36c")
    marker_material.emission_enabled = true
    marker_material.emission = Color("f8e36c")
    facing_marker.material_override = marker_material
    facing_marker.position = Vector3(0.0, 1.18, -0.68)
    _locomotion_root.add_child(facing_marker)

    var collision := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.radius = 0.48
    capsule_shape.height = 1.65
    collision.shape = capsule_shape
    collision.position.y = 0.95
    add_child(collision)


func _build_move_marker() -> void:
    _move_marker = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.32
    torus.outer_radius = 0.42
    torus.rings = 10
    torus.ring_segments = 24
    _move_marker.mesh = torus
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.32, 0.78, 1.0, 0.55)
    material.emission_enabled = true
    material.emission = Color("55c8ff")
    material.emission_energy_multiplier = 1.8
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _move_marker.material_override = material
    _move_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _move_marker.visible = false
    add_child(_move_marker)
    _move_marker.set_as_top_level(true)


func _update_locomotion_visual(delta: float) -> void:
    if _locomotion_root == null:
        return
    var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    var speed_ratio := clampf(horizontal_velocity.length() / movement_speed, 0.0, 1.8)
    if (
        speed_ratio <= 0.01
        and absf(_locomotion_root.position.y) <= 0.001
        and absf(_locomotion_root.rotation.x) <= 0.001
        and absf(_locomotion_root.rotation.z) <= 0.001
        and (_move_marker == null or not _move_marker.visible)
    ):
        return
    var target_height := 0.0
    if speed_ratio > 0.05:
        _locomotion_time += delta * (10.5 + speed_ratio * 2.0)
        target_height = sin(_locomotion_time) * 0.045 * minf(speed_ratio, 1.0)
    var local_velocity := global_transform.basis.inverse() * horizontal_velocity
    var target_pitch := clampf(local_velocity.z / movement_speed, -1.0, 1.0) * 0.075
    var target_roll := clampf(-local_velocity.x / movement_speed, -1.0, 1.0) * 0.085
    if _dash_remaining > 0.0:
        target_pitch *= 1.7
        target_roll *= 1.35
    _locomotion_root.position.y = lerpf(
        _locomotion_root.position.y,
        target_height,
        1.0 - exp(-16.0 * delta)
    )
    _locomotion_root.rotation.x = lerp_angle(
        _locomotion_root.rotation.x,
        target_pitch,
        1.0 - exp(-13.0 * delta)
    )
    _locomotion_root.rotation.z = lerp_angle(
        _locomotion_root.rotation.z,
        target_roll,
        1.0 - exp(-13.0 * delta)
    )
    if _move_marker != null and _move_marker.visible:
        var pulse := 0.92 + sin(float(Time.get_ticks_msec()) * 0.009) * 0.1
        _move_marker.scale = Vector3.ONE * pulse


func _animate_cast() -> void:
    if _motion_tween != null and _motion_tween.is_valid():
        _motion_tween.kill()
    _visual_root.scale = Vector3(1.12, 0.86, 1.12)
    _motion_tween = create_tween()
    _motion_tween.set_trans(Tween.TRANS_BACK)
    _motion_tween.set_ease(Tween.EASE_OUT)
    _motion_tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.15)


func _animate_dash() -> void:
    if _motion_tween != null and _motion_tween.is_valid():
        _motion_tween.kill()
    _visual_root.scale = Vector3(0.78, 0.9, 1.32)
    _motion_tween = create_tween()
    _motion_tween.set_trans(Tween.TRANS_BACK)
    _motion_tween.set_ease(Tween.EASE_OUT)
    _motion_tween.tween_property(_visual_root, "scale", Vector3.ONE, dash_duration + 0.08)
