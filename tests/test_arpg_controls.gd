extends SceneTree

const CONCEPT_LIBRARY := preload("res://scripts/concept_library.gd")


func _init() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var failures: PackedStringArray = []
    var packed_scene := load("res://main.tscn") as PackedScene
    var main_scene := packed_scene.instantiate()
    root.add_child(main_scene)
    current_scene = main_scene
    await process_frame
    await physics_frame
    var player := get_first_node_in_group("player") as PlayerController
    if player == null:
        push_error("ARPG control test could not find the player")
        quit(1)
        return

    _verify_input_map(failures)
    await _verify_destination_movement(player, failures)
    await _verify_keyboard_override(player, failures)
    await _verify_hold_to_attack(player, failures)
    await _verify_dash(player, failures)

    Input.action_release("move_left")
    Input.action_release("move_right")
    Input.action_release("move_up")
    Input.action_release("move_down")
    Input.action_release("move_to_cursor")
    Input.action_release("cast_skill")
    Input.action_release("force_attack")
    Input.action_release("dash")
    main_scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS: ARPG click movement, WASD override, hold attack, force attack, and dash")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _verify_input_map(failures: PackedStringArray) -> void:
    if not _has_mouse_binding(&"move_to_cursor", MOUSE_BUTTON_LEFT):
        failures.append("Left mouse is not bound to click movement")
    if not _has_mouse_binding(&"cast_skill", MOUSE_BUTTON_RIGHT):
        failures.append("Right mouse is not bound to skill casting")
    if not _has_key_binding(&"force_attack", KEY_SHIFT):
        failures.append("Shift is not bound to force attack")
    if not _has_key_binding(&"dash", KEY_SPACE):
        failures.append("Space is not bound to Dash")


func _verify_destination_movement(
        player: PlayerController,
        failures: PackedStringArray
) -> void:
    player.cancel_move_destination()
    player.global_position = Vector3(-8.0, 0.0, 8.0)
    player.velocity = Vector3.ZERO
    var destination := Vector3(-4.5, 0.0, 8.0)
    player.set_move_destination(destination)
    var marker := player.get("_move_marker") as MeshInstance3D
    if marker == null or not marker.visible:
        failures.append("Click movement did not show its ground destination marker")
    await physics_frame
    var first_frame_speed := Vector2(player.velocity.x, player.velocity.z).length()
    if first_frame_speed <= 0.0 or first_frame_speed >= player.movement_speed:
        failures.append("Click movement did not accelerate smoothly")
    for _frame: int in 90:
        await physics_frame
    var flat_distance := Vector2(
        player.global_position.x - destination.x,
        player.global_position.z - destination.z
    ).length()
    if flat_distance > player.destination_stop_distance + 0.08:
        failures.append("Click movement did not arrive at its destination")
    if player.has_move_destination():
        failures.append("Destination remained active after arrival")
    if marker != null and marker.visible:
        failures.append("Destination marker remained visible after arrival")
    if Vector2(player.velocity.x, player.velocity.z).length() > 0.3:
        failures.append("Character did not decelerate after reaching the destination")


func _verify_keyboard_override(
        player: PlayerController,
        failures: PackedStringArray
) -> void:
    player.global_position = Vector3(-4.5, 0.0, 8.0)
    player.velocity = Vector3.ZERO
    player.set_move_destination(Vector3(4.0, 0.0, 8.0))
    Input.action_press("move_left")
    for _frame: int in 3:
        await physics_frame
    Input.action_release("move_left")
    if player.has_move_destination():
        failures.append("WASD did not cancel the active mouse destination")
    if player.velocity.x >= 0.0:
        failures.append("WASD did not immediately override click movement")


func _verify_hold_to_attack(
        player: PlayerController,
        failures: PackedStringArray
) -> void:
    var result := CONCEPT_LIBRARY.compile_graph(_single_skill_graph(&"skill_ice_nova"))
    if not result.valid:
        failures.append("ARPG attack graph failed: %s" % " / ".join(result.errors))
        return
    result.graph.get_primary_skill().cooldown = 0.08
    player.set_skill_graph(result.graph)
    player.global_position = Vector3(-8.0, 0.0, 8.0)
    player.velocity = Vector3.ZERO
    var cast_counter := {"count": 0}
    player.combat_event.connect(func(message: String, _color: Color) -> void:
        if message.contains("Cast -> Ice Nova"):
            cast_counter["count"] = int(cast_counter["count"]) + 1
    )

    player.set_move_destination(Vector3(-3.0, 0.0, 8.0))
    var stationary_position := player.global_position
    Input.action_press("force_attack")
    Input.action_press("move_to_cursor")
    for _frame: int in 18:
        await physics_frame
    Input.action_release("move_to_cursor")
    Input.action_release("force_attack")
    if player.global_position.distance_to(stationary_position) > 0.08:
        failures.append("Shift+left click moved the character instead of forcing a stationary attack")
    if player.has_move_destination():
        failures.append("Attack command did not cancel click movement")
    if int(cast_counter["count"]) < 2:
        failures.append("Holding force attack did not repeat the equipped skill")

    cast_counter["count"] = 0
    Input.action_press("cast_skill")
    for _frame: int in 18:
        await physics_frame
    Input.action_release("cast_skill")
    if int(cast_counter["count"]) < 2:
        failures.append("Holding right mouse did not repeatedly cast at cooldown")


func _verify_dash(player: PlayerController, failures: PackedStringArray) -> void:
    player.global_position = Vector3(-8.0, 0.0, 8.0)
    player.velocity = Vector3.ZERO
    player.cancel_move_destination()
    player.set("_dash_cooldown_remaining", 0.0)
    player.set("_facing_direction", Vector3(1.0, 0.0, 0.0))
    var start := player.global_position
    player.try_dash()
    for _frame: int in 5:
        await physics_frame
    if player.global_position.distance_to(start) < 0.7:
        failures.append("Dash did not move along the current movement/facing direction")


func _single_skill_graph(concept_id: StringName) -> SkillGraph:
    var graph := SkillGraph.new()
    graph.set_node(SkillGraphNode.new().configure(0, concept_id, SkillGraph.ROOT_PARENT))
    return graph


func _has_mouse_binding(action: StringName, button: MouseButton) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
            return true
    return false


func _has_key_binding(action: StringName, key: Key) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        if event is InputEventKey and (event as InputEventKey).physical_keycode == key:
            return true
    return false
