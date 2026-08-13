extends SceneTree

const CONCEPT_LIBRARY := preload("res://scripts/concept_library.gd")


func _init() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var failures: PackedStringArray = []
    var packed_scene := load("res://main.tscn") as PackedScene
    if packed_scene == null:
        push_error("Could not load main scene")
        quit(1)
        return
    var main_scene := packed_scene.instantiate()
    root.add_child(main_scene)
    current_scene = main_scene
    await process_frame
    await physics_frame

    var player := get_first_node_in_group("player") as PlayerController
    var builder := get_first_node_in_group("concept_builder_ui") as PrototypeHud
    var dummies := get_nodes_in_group("damageable")
    if player == null or builder == null:
        failures.append("Main scene did not create player and graph HUD")
    if dummies.size() != 9:
        failures.append("Expected 9 training dummies, got %d" % dummies.size())
    if builder != null and builder.get_selected_nodes().size() != SkillGraph.MAX_NODES:
        failures.append("HUD did not create exactly six graph slots")
    if player == null or builder == null:
        _finish(main_scene, failures)
        return

    var start_position := player.global_position
    Input.action_press("move_up")
    for _frame: int in 8:
        await physics_frame
    Input.action_release("move_up")
    if player.global_position.distance_to(start_position) < 0.1:
        failures.append("Player movement failed")

    var combat_messages: Array[String] = []
    player.combat_event.connect(func(message: String, _color: Color) -> void:
        combat_messages.append(message)
    )
    await _test_default_parallel_branches(player, dummies, combat_messages, failures)
    await _test_hit_triggered_ice_nova_origin(player, dummies, failures)
    await _test_thunder_chain(player, dummies, combat_messages, failures)
    await _test_external_trigger(player, combat_messages, failures)
    await _test_lifesteal(player, failures)
    await _test_rapid_fire_and_combo(player, dummies, combat_messages, failures)
    await _test_secondary_hit_branch(player, dummies, combat_messages, failures)
    await _test_dot_kill_semantics(player, dummies, combat_messages, failures)
    await _test_trigger_conditions(player, dummies, failures)
    await _test_internal_cooldown(player, failures)

    Input.action_release("move_up")
    _finish(main_scene, failures)


func _test_default_parallel_branches(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    _reset_dummies(dummies)
    for dummy: Node in dummies:
        dummy.set("health", 20.0)
    var graph := CONCEPT_LIBRARY.get_default_graph()
    graph.get_compiled_skill(0).critical_chance = 1.0
    player.set_skill_graph(graph)
    _place_player(player, Vector3(0.0, 0.0, 7.0))
    player.try_cast_skill()
    await physics_frame
    if player.get_skill_executor().get_active_projectile_count() != 1:
        failures.append("Hit-split Fireball must start as one projectile")
    for _frame: int in 120:
        await physics_frame
    if not _messages_contain(messages, "Split on Hit"):
        failures.append("Fireball did not split after impact")
    if not _messages_contain(messages, "Ice Nova"):
        failures.append("Critical branch did not cast Ice Nova")
    if not _messages_contain(messages, "Summon Core"):
        failures.append("Kill branch did not cast Summon Core")
    if player.get_skill_executor().get_active_projectile_count() >= ProjectileManager.MAX_ACTIVE_PROJECTILES:
        failures.append("Default parallel branches escaped projectile recursion guards")
    _clear_projectiles(player)


func _test_external_trigger(
        player: PlayerController,
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    var graph := SkillGraph.new()
    _put_node(graph, 0, &"skill_fireball", SkillGraph.ROOT_PARENT)
    _put_node(graph, 1, &"trigger_damaged", SkillGraph.PLAYER_EVENT_PARENT, TriggerConfig.new())
    _put_node(graph, 2, &"skill_summon_core", 1)
    _equip(player, graph, failures, "Damaged trigger graph")
    player.simulate_damage()
    for _frame: int in 10:
        await physics_frame
    if not _messages_contain(messages, "Summon Core"):
        failures.append("Damaged player-event branch did not cast Summon Core")
    _clear_projectiles(player)


func _test_lifesteal(player: PlayerController, failures: PackedStringArray) -> void:
    var graph := _graph_with_supports(&"skill_ice_nova", [&"effect_lifesteal"])
    _equip(player, graph, failures, "Lifesteal graph")
    var definition := player.get_skill_executor().graph.get_primary_skill()
    if definition == null or definition.emitter_type != &"context" or not is_equal_approx(definition.area_radius, 5.2):
        failures.append("Ice Nova must default to a contextual fixed 5.2m radius")
        return
    _reset_dummies(get_nodes_in_group("damageable"))
    player.health = 40.0
    _place_player(player, Vector3(0.0, 0.0, 2.0))
    player.get_skill_executor().request_manual_cast(Vector3(40.0, 0.0, 40.0), Vector3.FORWARD)
    for _frame: int in 3:
        await physics_frame
    if player.health <= 40.0:
        failures.append("Player-centered Ice Nova followed the distant aim point or failed to Lifesteal")


func _test_hit_triggered_ice_nova_origin(
        player: PlayerController,
        dummies: Array[Node],
        failures: PackedStringArray
) -> void:
    _clear_projectiles(player)
    _reset_dummies(dummies)
    var original_positions: Array[Vector3] = []
    for index: int in dummies.size():
        var dummy := dummies[index] as Node3D
        original_positions.append(dummy.global_position)
        dummy.global_position = Vector3(40.0 + float(index) * 3.0, 0.0, 40.0)
    var impact_target := dummies[0] as Node3D
    var nearby_witness := dummies[1] as Node3D
    impact_target.global_position = Vector3.ZERO
    nearby_witness.global_position = Vector3(3.5, 0.0, 0.0)

    var graph := SkillGraph.new()
    _put_node(graph, 0, &"skill_fireball", SkillGraph.ROOT_PARENT)
    var hit_config := TriggerConfig.new()
    hit_config.internal_cooldown = 0.0
    _put_node(graph, 1, &"trigger_hit", 0, hit_config)
    _put_node(graph, 2, &"skill_ice_nova", 1)
    var result := CONCEPT_LIBRARY.compile_graph(graph)
    if not result.valid:
        failures.append("Hit-triggered Ice Nova graph failed to compile: %s" % " / ".join(result.errors))
        for index: int in dummies.size():
            (dummies[index] as Node3D).global_position = original_positions[index]
        _reset_dummies(dummies)
        return
    player.set_skill_graph(result.graph)
    result.graph.get_compiled_skill(0).damage = 1.0
    _place_player(player, Vector3(0.0, 0.0, 7.0))
    player.get_skill_executor().request_manual_cast(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 90:
        await physics_frame
    if float(nearby_witness.get("health")) >= float(nearby_witness.get("max_health")):
        failures.append("Fireball Hit-triggered Ice Nova did not expand from the struck enemy")

    _clear_projectiles(player)
    for index: int in dummies.size():
        (dummies[index] as Node3D).global_position = original_positions[index]
    _reset_dummies(dummies)


func _test_thunder_chain(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    _clear_projectiles(player)
    var original_positions: Array[Vector3] = []
    for index: int in dummies.size():
        var dummy := dummies[index] as Node3D
        original_positions.append(dummy.global_position)
        dummy.global_position = Vector3(40.0 + float(index) * 3.0, 0.0, 40.0)
    var base_result := CONCEPT_LIBRARY.compile_graph(_graph_with_supports(&"skill_thunder_orb", []))
    if not base_result.valid:
        failures.append("Base Thunder chain failed to compile: %s" % " / ".join(base_result.errors))
        _restore_dummies(dummies, original_positions)
        return
    var definition := base_result.graph.get_primary_skill()
    definition.critical_chance = 0.0
    player.set_skill_graph(base_result.graph)
    _place_player(player, Vector3.ZERO)
    var primary := dummies[0] as Node3D
    var jump_one := dummies[1] as Node3D
    var jump_two := dummies[2] as Node3D
    var untouched := dummies[3] as Node3D
    primary.global_position = Vector3(0.0, 0.0, -5.0)
    jump_one.global_position = Vector3(3.5, 0.0, -5.0)
    jump_two.global_position = Vector3(7.0, 0.0, -5.0)
    untouched.global_position = Vector3(10.5, 0.0, -5.0)
    _reset_dummies(dummies)
    messages.clear()
    player.get_skill_executor().request_manual_cast(primary.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 3:
        await physics_frame
    if not is_equal_approx(float(primary.get("health")), 293.0):
        failures.append("Thunder chain primary target did not take 100% damage")
    if not is_equal_approx(float(jump_one.get("health")), 300.56):
        failures.append("Thunder chain first jump did not take 72% damage")
    if absf(float(jump_two.get("health")) - 304.0592) > 0.02:
        failures.append("Thunder chain second jump did not apply per-hop decay")
    if not is_equal_approx(float(untouched.get("health")), float(untouched.get("max_health"))):
        failures.append("Base Thunder chain exceeded two jumps")
    if player.get_skill_executor().get_active_projectile_count() != 0:
        failures.append("Base Thunder chain incorrectly spawned a projectile")
    var found_player_origin := false
    for chain_vfx: Node in get_nodes_in_group("vfx_chain_lightning"):
        if not chain_vfx.has_meta("from_position"):
            continue
        var from_position := chain_vfx.get_meta("from_position") as Vector3
        if from_position.distance_to(player.global_position) < 2.0:
            found_player_origin = true
            break
    if not found_player_origin:
        failures.append("Thunder chain VFX did not originate from the player")

    var upgraded_result := CONCEPT_LIBRARY.compile_graph(
        _graph_with_supports(&"skill_thunder_orb", [&"modifier_chain"])
    )
    if not upgraded_result.valid:
        failures.append("Upgraded Thunder chain failed to compile: %s" % " / ".join(upgraded_result.errors))
    else:
        _reset_dummies(dummies)
        for index: int in 5:
            (dummies[index] as Node3D).global_position = Vector3(float(index) * 3.5, 0.0, -5.0)
        upgraded_result.graph.get_primary_skill().critical_chance = 0.0
        player.set_skill_graph(upgraded_result.graph)
        player.get_skill_executor().request_manual_cast(
            (dummies[0] as Node3D).global_position,
            Vector3(0.0, 0.0, -1.0)
        )
        for _frame: int in 3:
            await physics_frame
        if float(dummies[4].get("health")) >= float(dummies[4].get("max_health")):
            failures.append("Chain Modifier did not extend Thunder chain to four jumps")

    var cone_result := CONCEPT_LIBRARY.compile_graph(
        _graph_with_supports(&"skill_thunder_orb", [&"shape_cone"])
    )
    if not cone_result.valid:
        failures.append("Cone Thunder chain failed to compile: %s" % " / ".join(cone_result.errors))
    else:
        for index: int in dummies.size():
            (dummies[index] as Node3D).global_position = Vector3(40.0 + float(index) * 3.0, 0.0, 40.0)
        (dummies[0] as Node3D).global_position = Vector3(0.0, 0.0, -4.0)
        (dummies[1] as Node3D).global_position = Vector3(1.5, 0.0, -5.0)
        (dummies[2] as Node3D).global_position = Vector3(-1.5, 0.0, -5.0)
        (dummies[3] as Node3D).global_position = Vector3(3.8, 0.0, -4.0)
        (dummies[4] as Node3D).global_position = Vector3(7.4, 0.0, -4.0)
        _reset_dummies(dummies)
        messages.clear()
        cone_result.graph.get_primary_skill().critical_chance = 0.0
        player.set_skill_graph(cone_result.graph)
        player.get_skill_executor().request_manual_cast(Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, -1.0))
        for _frame: int in 3:
            await physics_frame
        if _message_count(messages, "Follow-up Effect -> Chain") != 1:
            failures.append("Cone Thunder pattern created more than one follow-up chain")

    var projectile_result := CONCEPT_LIBRARY.compile_graph(
        _graph_with_supports(&"skill_thunder_orb", [&"action_projectile", &"modifier_split"])
    )
    if not projectile_result.valid:
        failures.append("Projectile Thunder conversion failed: %s" % " / ".join(projectile_result.errors))
    else:
        for index: int in dummies.size():
            (dummies[index] as Node3D).global_position = Vector3(40.0 + float(index) * 3.0, 0.0, 40.0)
        primary.global_position = Vector3(0.0, 0.0, -5.0)
        _reset_dummies(dummies)
        messages.clear()
        projectile_result.graph.get_primary_skill().critical_chance = 0.0
        player.set_skill_graph(projectile_result.graph)
        player.get_skill_executor().request_manual_cast(primary.global_position, Vector3(0.0, 0.0, -1.0))
        await physics_frame
        if player.get_skill_executor().get_active_projectile_count() != 1:
            failures.append("Projectile Action did not restore the Thunder Orb projectile")
        for _frame: int in 45:
            await physics_frame
        if not _messages_contain(messages, "Split on Hit"):
            failures.append("Projectile-converted Thunder Orb did not execute Split")
        _clear_projectiles(player)

    for index: int in dummies.size():
        (dummies[index] as Node3D).global_position = Vector3(40.0 + float(index) * 3.0, 0.0, 40.0)
    var dead_target := dummies[0] as Node3D
    var live_target := dummies[1] as Node3D
    dead_target.global_position = Vector3(0.0, 0.0, -5.0)
    dead_target.set("health", 0.0)
    dead_target.set("_dead", true)
    dead_target.set("collision_layer", 0)
    live_target.global_position = Vector3(2.0, 0.0, -5.0)
    live_target.call("reset_dummy")
    messages.clear()
    player.set_skill_graph(base_result.graph)
    player.get_skill_executor().request_manual_cast(dead_target.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 3:
        await physics_frame
    if float(live_target.get("health")) >= float(live_target.get("max_health")):
        failures.append("Thunder cursor targeting did not skip a dead target")

    for index: int in dummies.size():
        (dummies[index] as Node3D).global_position = Vector3(40.0 + float(index) * 3.0, 0.0, 40.0)
    var out_of_range := dummies[0] as Node3D
    out_of_range.call("reset_dummy")
    out_of_range.global_position = Vector3(0.0, 0.0, -13.0)
    messages.clear()
    player.set_skill_graph(base_result.graph)
    player.get_skill_executor().request_manual_cast(out_of_range.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 3:
        await physics_frame
    if float(out_of_range.get("health")) < float(out_of_range.get("max_health")):
        failures.append("Thunder cursor targeting exceeded its 12m range")
    if not _messages_contain(messages, "No valid target") or _messages_contain(messages, "Hit -> Chain Lightning"):
        failures.append("No-target Thunder cast produced Hit semantics")

    _restore_dummies(dummies, original_positions)


func _test_rapid_fire_and_combo(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    _reset_dummies(dummies)
    _equip(player, _graph_with_supports(&"skill_fireball", [&"modifier_rapid_fire"]), failures, "Rapid Fire graph")
    _place_player(player, Vector3(0.0, 0.0, 7.0))
    player.try_cast_skill()
    for _frame: int in 30:
        await physics_frame
    if not _messages_contain(messages, "Stage 3/3"):
        failures.append("Rapid Fire did not execute three timed volleys")
    _clear_projectiles(player)

    messages.clear()
    _reset_dummies(dummies)
    _equip(
        player,
        _graph_with_supports(&"skill_heavy_slash", [&"modifier_combo", &"modifier_splash"]),
        failures,
        "Melee combo graph"
    )
    _place_player(player, Vector3(0.0, 0.0, 2.0))
    player.try_cast_skill()
    for _frame: int in 30:
        await physics_frame
    if not _messages_contain(messages, "Combo -> Stage 3/3"):
        failures.append("Melee Combo did not execute three timed hits")
    var side_dummy := _find_dummy_at(dummies, Vector3(3.5, 0.0, 0.0))
    if side_dummy == null or float(side_dummy.get("health")) >= float(side_dummy.get("max_health")):
        failures.append("Splash did not damage a secondary target")


func _test_secondary_hit_branch(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    _reset_dummies(dummies)
    var graph := SkillGraph.new()
    _put_node(graph, 0, &"skill_heavy_slash", SkillGraph.ROOT_PARENT)
    _put_node(graph, 1, &"modifier_splash", 0)
    var config := TriggerConfig.new()
    config.internal_cooldown = 0.0
    _put_node(graph, 2, &"trigger_hit", 0, config)
    _put_node(graph, 3, &"skill_thunder_orb", 2)
    _equip(player, graph, failures, "Secondary hit graph")
    _place_player(player, Vector3(0.0, 0.0, 2.0))
    player.try_cast_skill()
    await physics_frame
    var found_triggered_player_origin := false
    for chain_vfx: Node in get_nodes_in_group("vfx_chain_lightning"):
        if not chain_vfx.has_meta("from_position"):
            continue
        var from_position := chain_vfx.get_meta("from_position") as Vector3
        if from_position.distance_to(player.global_position) < 2.0:
            found_triggered_player_origin = true
            break
    if not found_triggered_player_origin:
        failures.append("Hit-triggered Thunder chain did not originate from the player")
    for _frame: int in 19:
        await physics_frame
    if _message_count(messages, "Chain Lightning") < 2:
        failures.append("Primary and splash secondary hits did not independently trigger the branch")
    _clear_projectiles(player)


func _test_dot_kill_semantics(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    _reset_dummies(dummies)
    var graph := SkillGraph.new()
    _put_node(graph, 0, &"skill_thunder_orb", SkillGraph.ROOT_PARENT)
    _put_node(graph, 1, &"effect_poison", 0)
    var hit_config := TriggerConfig.new()
    hit_config.chance = 0.0
    hit_config.internal_cooldown = 0.0
    _put_node(graph, 2, &"trigger_hit", 0, hit_config)
    _put_node(graph, 3, &"skill_ice_nova", 2)
    _put_node(graph, 4, &"trigger_kill", 0, TriggerConfig.new())
    _put_node(graph, 5, &"skill_summon_core", 4)
    _equip(player, graph, failures, "DoT graph")
    player.current_graph.get_compiled_skill(0).chain_count = 0
    var target := _find_dummy_at(dummies, Vector3(0.0, 0.0, 3.5))
    if target == null:
        failures.append("Could not find DoT target dummy")
        return
    for dummy: Node in dummies:
        dummy.set("health", 25.0)
    player.current_graph.get_compiled_skill(0).critical_chance = 0.0
    _place_player(player, Vector3(0.0, 0.0, 7.0))
    player.try_cast_skill()
    for _frame: int in 120:
        await physics_frame
    var executor := player.get_skill_executor()
    if int(executor.get("_trigger_occurrences").get(2, 0)) != 1:
        failures.append("DoT tick incorrectly emitted Hit events")
    if not _messages_contain(messages, "Summon Core"):
        failures.append("DoT kill did not emit the source-owned Kill event")
    _clear_projectiles(player)


func _test_trigger_conditions(
        player: PlayerController,
        dummies: Array[Node],
        failures: PackedStringArray
) -> void:
    _reset_dummies(dummies)
    var config := TriggerConfig.new()
    config.every_n = 2
    config.chance = 100.0
    config.internal_cooldown = 0.0
    config.max_player_health_ratio = 0.5
    config.required_target_status = &"poison"
    var graph := SkillGraph.new()
    _put_node(graph, 0, &"skill_fireball", SkillGraph.ROOT_PARENT)
    _put_node(graph, 1, &"trigger_damaged", SkillGraph.PLAYER_EVENT_PARENT, config)
    _put_node(graph, 2, &"skill_summon_core", 1)
    _equip(player, graph, failures, "Conditional trigger graph")
    var target := dummies[0] as Node3D
    target.call("apply_poison", 2.0, 0.0, {})
    player.health = 80.0
    var executor := player.get_skill_executor()
    executor.request_external_event(&"damaged", target.global_position, target)
    executor.request_external_event(&"damaged", target.global_position, target)
    for _frame: int in 3:
        await physics_frame
    if executor.get_active_projectile_count() > 0:
        failures.append("Low-health condition triggered while player health was too high")
    player.health = 40.0
    executor.request_external_event(&"damaged", target.global_position, target)
    executor.request_external_event(&"damaged", target.global_position, target)
    for _frame: int in 5:
        await physics_frame
    if executor.get_active_projectile_count() == 0:
        failures.append("every-N/chance/low-health/status conditions did not pass deterministically")
    var first_roll := float(executor.call("_deterministic_percent", 9, 1, 3))
    var second_roll := float(executor.call("_deterministic_percent", 9, 1, 3))
    if not is_equal_approx(first_roll, second_roll):
        failures.append("Trigger chance roll is not deterministic")
    _clear_projectiles(player)


func _test_internal_cooldown(
        player: PlayerController,
        failures: PackedStringArray
) -> void:
    var graph := SkillGraph.new()
    _put_node(graph, 0, &"skill_fireball", SkillGraph.ROOT_PARENT)
    var config := TriggerConfig.new()
    config.internal_cooldown = 0.08
    _put_node(graph, 1, &"trigger_damaged", SkillGraph.PLAYER_EVENT_PARENT, config)
    _put_node(graph, 2, &"skill_summon_core", 1)
    _equip(player, graph, failures, "ICD graph")
    var executor := player.get_skill_executor()
    executor.request_external_event(&"damaged", player.global_position)
    executor.request_external_event(&"damaged", player.global_position)
    await physics_frame
    var first_time := float(executor.get("_trigger_last_time").get(1, -1.0))
    if int(executor.get("_trigger_occurrences").get(1, 0)) != 2:
        failures.append("0.08s ICD did not evaluate both same-frame occurrences")
    for _frame: int in 7:
        await physics_frame
    executor.request_external_event(&"damaged", player.global_position)
    await physics_frame
    var second_time := float(executor.get("_trigger_last_time").get(1, -1.0))
    if second_time <= first_time:
        failures.append("0.08s ICD did not allow a later trigger")
    _clear_projectiles(player)


func _equip(
        player: PlayerController,
        source_graph: SkillGraph,
        failures: PackedStringArray,
        label: String
) -> void:
    var result := CONCEPT_LIBRARY.compile_graph(source_graph)
    if not result.valid:
        failures.append("%s failed to compile: %s" % [label, " / ".join(result.errors)])
        return
    player.set_skill_graph(result.graph)


func _graph_with_supports(skill_id: StringName, supports: Array[StringName]) -> SkillGraph:
    var graph := SkillGraph.new()
    _put_node(graph, 0, skill_id, SkillGraph.ROOT_PARENT)
    for index: int in supports.size():
        _put_node(graph, index + 1, supports[index], 0)
    return graph


func _put_node(
        graph: SkillGraph,
        node_id: int,
        concept_id: StringName,
        parent_node_id: int,
        config: TriggerConfig = null
) -> void:
    graph.set_node(SkillGraphNode.new().configure(node_id, concept_id, parent_node_id, config))


func _place_player(player: PlayerController, position: Vector3) -> void:
    player.global_position = position
    player.set_view_camera(null)
    player.set("_facing_direction", Vector3(0.0, 0.0, -1.0))
    player.set("_cooldown_remaining", 0.0)


func _clear_projectiles(player: PlayerController) -> void:
    var manager: ProjectileManager = player.get_skill_executor().get("_runtime").get("_projectile_manager")
    manager.clear_active()


func _reset_dummies(dummies: Array[Node]) -> void:
    for dummy: Node in dummies:
        dummy.call("reset_dummy")


func _restore_dummies(dummies: Array[Node], positions: Array[Vector3]) -> void:
    for index: int in mini(dummies.size(), positions.size()):
        (dummies[index] as Node3D).global_position = positions[index]
    _reset_dummies(dummies)


func _messages_contain(messages: Array[String], fragment: String) -> bool:
    return _message_count(messages, fragment) > 0


func _message_count(messages: Array[String], fragment: String) -> int:
    var count := 0
    for message: String in messages:
        if message.contains(fragment):
            count += 1
    return count


func _find_dummy_at(dummies: Array[Node], world_position: Vector3) -> Node3D:
    for dummy: Node in dummies:
        if dummy is Node3D and (dummy as Node3D).global_position.distance_to(world_position) < 0.1:
            return dummy as Node3D
    return null


func _finish(main_scene: Node, failures: PackedStringArray) -> void:
    var player := get_first_node_in_group("player") as PlayerController
    if player != null:
        player.get_skill_executor().set_graph(null)
    for _frame: int in 20:
        await physics_frame
    main_scene.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: graph runtime, secondary events, conditions, DoT, movement, and combat supports")
        call_deferred("quit", 0)
        return
    for failure: String in failures:
        push_error(failure)
    call_deferred("quit", 1)
