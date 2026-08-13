class_name ConceptChainPrototype
extends Node3D

const CONCEPT_LIBRARY := preload("res://scripts/concept_library.gd")
const PLAYER_SCRIPT := preload("res://scripts/player_controller.gd")
const DUMMY_SCRIPT := preload("res://scripts/training_dummy.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const COMBAT_AUDIO_SCRIPT := preload("res://scripts/combat_audio.gd")

var _player: PlayerController
var _camera: Camera3D
var _hud: PrototypeHud
var _combat_audio: CombatAudio
var _aim_reticle: MeshInstance3D
var _camera_offset := Vector3(10.5, 14.0, 10.5)
var _camera_anchor: Vector3
var _camera_shake: float = 0.0
var _hit_stop_active: bool = false


func _ready() -> void:
    _ensure_input_actions()
    _build_environment()
    _build_arena()
    _spawn_training_dummies()
    _spawn_player()
    _setup_camera()
    _setup_aim_reticle()
    _setup_combat_audio()
    _setup_hud()
    _apply_custom_build(_hud.get_graph())


func _process(delta: float) -> void:
    if _player == null or _camera == null:
        return
    _update_camera(delta)
    _update_aim_reticle()
    _hud.update_cooldown(
        _player.get_cooldown_remaining(),
        _player.get_cooldown_duration()
    )
    _hud.update_player_health(_player.health, _player.max_health)
    _hud.update_runtime_budget(_player.get_skill_executor())


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("reset_dummies"):
        _reset_all_dummies()
        get_viewport().set_input_as_handled()


func _build_environment() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("101722")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("b9d2e6")
    environment.ambient_light_energy = 0.72
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_environment.environment = environment
    add_child(world_environment)

    var light := DirectionalLight3D.new()
    light.light_color = Color("fff1d1")
    light.light_energy = 1.15
    light.shadow_enabled = true
    light.rotation_degrees = Vector3(-58.0, -38.0, 0.0)
    add_child(light)


func _build_arena() -> void:
    var floor := MeshInstance3D.new()
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(30.0, 0.16, 30.0)
    floor.mesh = floor_mesh
    floor.position.y = -0.09
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("1d2b38")
    floor_material.roughness = 1.0
    floor.material_override = floor_material
    add_child(floor)

    var grid_material := StandardMaterial3D.new()
    grid_material.albedo_color = Color("2b4354")
    grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

    for coordinate: int in range(-14, 15, 2):
        var horizontal := MeshInstance3D.new()
        var horizontal_mesh := BoxMesh.new()
        horizontal_mesh.size = Vector3(28.0, 0.012, 0.025)
        horizontal.mesh = horizontal_mesh
        horizontal.material_override = grid_material
        horizontal.position = Vector3(0.0, 0.005, float(coordinate))
        add_child(horizontal)

        var vertical := MeshInstance3D.new()
        var vertical_mesh := BoxMesh.new()
        vertical_mesh.size = Vector3(0.025, 0.012, 28.0)
        vertical.mesh = vertical_mesh
        vertical.material_override = grid_material
        vertical.position = Vector3(float(coordinate), 0.005, 0.0)
        add_child(vertical)


func _spawn_training_dummies() -> void:
    var positions: Array[Vector3] = [
        Vector3(-3.5, 0.0, -3.5),
        Vector3(0.0, 0.0, -3.5),
        Vector3(3.5, 0.0, -3.5),
        Vector3(-3.5, 0.0, 0.0),
        Vector3(0.0, 0.0, 0.0),
        Vector3(3.5, 0.0, 0.0),
        Vector3(-3.5, 0.0, 3.5),
        Vector3(0.0, 0.0, 3.5),
        Vector3(3.5, 0.0, 3.5),
    ]
    for index: int in positions.size():
        var dummy: TrainingDummy = DUMMY_SCRIPT.new()
        dummy.dummy_index = index + 1
        dummy.position = positions[index]
        add_child(dummy)


func _spawn_player() -> void:
    _player = PLAYER_SCRIPT.new()
    _player.position = Vector3(0.0, 0.0, 7.0)
    _player.combat_event.connect(_on_combat_event)
    add_child(_player)


func _setup_camera() -> void:
    _camera = Camera3D.new()
    _camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    _camera.size = 18.0
    _camera.current = true
    _camera.position = _player.position + _camera_offset
    _camera_anchor = _camera.position
    add_child(_camera)
    _camera.look_at(_player.global_position + Vector3.UP * 0.75, Vector3.UP)
    _player.set_view_camera(_camera)


func _setup_hud() -> void:
    _hud = HUD_SCRIPT.new()
    add_child(_hud)
    _hud.graph_changed.connect(_apply_custom_build)
    _hud.reset_requested.connect(_reset_all_dummies)


func _apply_custom_build(source_graph: SkillGraph) -> void:
    var result := CONCEPT_LIBRARY.compile_graph(source_graph)
    if not result.valid:
        _hud.log_event("Skill graph incomplete; combat keeps the last valid version", Color("ff7b87"))
        return
    var graph := result.graph
    _player.set_skill_graph(graph)
    _hud.set_runtime_graph(graph)
    _hud.log_event("Skill graph compiled", graph.get_primary_skill().color)


func _on_combat_event(message: String, event_color: Color) -> void:
    _hud.log_event(message, event_color)
    if message == "Dash":
        _combat_audio.play_dash()
        _camera_shake = maxf(_camera_shake, 0.08)
    elif message.begins_with("Cast"):
        _combat_audio.play_cast()
        _camera_shake = maxf(_camera_shake, 0.055)
    elif message.contains("Explosion"):
        _combat_audio.play_hit(false, true)
        _camera_shake = maxf(_camera_shake, 0.3)
        _request_hit_stop(0.035, 0.16)
    elif message.contains("Critical"):
        _combat_audio.play_hit(true)
        _camera_shake = maxf(_camera_shake, 0.22)
        _request_hit_stop(0.028, 0.2)
    elif message.contains("Hit"):
        _combat_audio.play_hit()
        _camera_shake = maxf(_camera_shake, 0.12)


func _reset_all_dummies() -> void:
    for dummy: Node in get_tree().get_nodes_in_group("damageable"):
        if dummy.has_method("reset_dummy"):
            dummy.call("reset_dummy")
    _hud.log_event("Arena reset", Color("8bd8ff"))


func _setup_aim_reticle() -> void:
    _aim_reticle = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.28
    torus.outer_radius = 0.38
    torus.rings = 12
    torus.ring_segments = 20
    _aim_reticle.mesh = torus
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.55, 0.9, 1.0, 0.8)
    material.emission_enabled = true
    material.emission = Color("7ee7ff")
    material.emission_energy_multiplier = 1.5
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _aim_reticle.material_override = material
    add_child(_aim_reticle)


func _setup_combat_audio() -> void:
    _combat_audio = COMBAT_AUDIO_SCRIPT.new()
    add_child(_combat_audio)


func _update_camera(delta: float) -> void:
    var desired_position := _player.global_position + _camera_offset
    _camera_anchor = _camera_anchor.lerp(desired_position, minf(delta * 8.5, 1.0))
    _camera_shake = move_toward(_camera_shake, 0.0, delta * 1.7)
    var shake_offset := Vector3(
        randf_range(-_camera_shake, _camera_shake),
        randf_range(-_camera_shake * 0.45, _camera_shake * 0.45),
        randf_range(-_camera_shake, _camera_shake)
    )
    _camera.global_position = _camera_anchor + shake_offset
    _camera.look_at(_player.global_position + Vector3.UP * 0.75, Vector3.UP)


func _update_aim_reticle() -> void:
    var mouse_position := get_viewport().get_mouse_position()
    var ray_origin := _camera.project_ray_origin(mouse_position)
    var ray_direction := _camera.project_ray_normal(mouse_position)
    var intersection: Variant = Plane(Vector3.UP, 0.035).intersects_ray(ray_origin, ray_direction)
    if intersection != null:
        _aim_reticle.global_position = intersection as Vector3


func _request_hit_stop(duration: float, time_scale: float) -> void:
    if _hit_stop_active:
        return
    _hit_stop_active = true
    Engine.time_scale = time_scale
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0
    _hit_stop_active = false


func _ensure_input_actions() -> void:
    _add_key_action("move_left", [KEY_A, KEY_LEFT])
    _add_key_action("move_right", [KEY_D, KEY_RIGHT])
    _add_key_action("move_up", [KEY_W, KEY_UP])
    _add_key_action("move_down", [KEY_S, KEY_DOWN])
    _add_key_action("reset_dummies", [KEY_R])
    _add_key_action("dash", [KEY_SPACE])
    _add_key_action("force_attack", [KEY_SHIFT])
    _add_key_action("simulate_damage", [KEY_Q])
    _add_mouse_action("move_to_cursor", MOUSE_BUTTON_LEFT)
    _add_mouse_action("cast_skill", MOUSE_BUTTON_RIGHT)


func _add_key_action(action_name: StringName, keys: Array[Key]) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    for key: Key in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action_name, event)


func _add_mouse_action(action_name: StringName, button: MouseButton) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    var event := InputEventMouseButton.new()
    event.button_index = button
    InputMap.action_add_event(action_name, event)
