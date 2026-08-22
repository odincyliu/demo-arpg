extends SceneTree

const TEST_UTILS := preload("res://tests/six_link_test_utils.gd")

const CORE_IDS: Array[StringName] = [
    &"core_slash", &"core_whirlblade", &"core_dash_strike", &"core_shockwave",
    &"core_ground_burst", &"core_arrow_shot", &"core_frost_lance", &"core_flame_orb",
    &"core_frost_nova", &"core_chain_lightning", &"core_meteor", &"core_void_beam",
    &"core_void_rift", &"core_summon",
]


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
    var hud := get_first_node_in_group("six_link_builder_ui") as PrototypeHud
    var dummies: Array[Node] = get_nodes_in_group("damageable")
    if player == null or hud == null or dummies.size() != 9:
        failures.append("Main scene did not create the Six-Link HUD, Player, and nine dummies")
        await _finish(main_scene, failures)
        return

    var messages: Array[String] = []
    player.combat_event.connect(func(message: String, _color: Color) -> void:
        messages.append(message)
    )
    await _verify_all_cores(player, dummies, failures)
    await _verify_core_cast_semantics(player, dummies, failures)
    await _verify_wave_and_splash(player, dummies, failures)
    await _verify_default_hold_freeze(player, dummies, messages, failures)
    await _verify_hold_reaim(player, dummies, failures)
    await _verify_crit_trigger(player, dummies, messages, failures)
    await _verify_return_trigger(player, dummies, messages, failures)
    await _verify_channel_trigger(player, dummies, messages, failures)
    await _verify_remnant_and_trajectories(player, dummies, failures)
    await _verify_summon_follow(player, dummies, failures)
    await _finish(main_scene, failures)


func _verify_all_cores(
        player: PlayerController,
        dummies: Array[Node],
        failures: PackedStringArray
) -> void:
    for core_id: StringName in CORE_IDS:
        var result := TEST_UTILS.compile([core_id])
        if not result.valid:
            failures.append("Core %s did not compile: %s" % [core_id, "; ".join(result.errors)])
            continue
        TEST_UTILS.place_player(player)
        var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -3.0))
        var starting_health := target.health
        player.set_skill_build(result.build)
        var definition := result.build.get_root_core()
        definition.critical_chance = 0.0
        var executor := player.get_skill_executor()
        if definition.channelled:
            Input.action_press("cast_skill")
            executor.begin_channel(target.global_position, Vector3(0.0, 0.0, -1.0))
            for _frame: int in 24:
                await physics_frame
            executor.stop_channel()
            Input.action_release("cast_skill")
        else:
            executor.request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
            var wait_frames := 55 if definition.core_behavior in [&"projectile", &"wave", &"meteor", &"summon"] else 10
            for _frame: int in wait_frames:
                await physics_frame
        var produced_runtime_result := target.health < starting_health
        if core_id == &"core_summon":
            produced_runtime_result = executor.get_active_minion_count() > 0 and target.health < starting_health
        elif core_id == &"core_dash_strike":
            produced_runtime_result = player.global_position.distance_to(Vector3.ZERO) > 1.0 and target.health < starting_health
        if not produced_runtime_result:
            failures.append("Core %s produced no observable Runtime result" % core_id)


func _verify_core_cast_semantics(
        player: PlayerController,
        dummies: Array[Node],
        failures: PackedStringArray
) -> void:
    TEST_UTILS.place_player(player)
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -2.5))
    var nova := TEST_UTILS.compile([&"core_frost_nova"])
    player.set_skill_build(nova.build)
    var starting_health := target.health
    player.get_skill_executor().request_manual_cast(Vector3(0.0, 0.0, -10.0), Vector3.FORWARD)
    player.get_skill_executor().process_queued_events()
    if target.health >= starting_health:
        failures.append("Manual Frost Nova did not expand from the player")

    TEST_UTILS.place_player(player)
    target = TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -3.0))
    var chain := TEST_UTILS.compile([&"core_chain_lightning"])
    player.set_skill_build(chain.build)
    player.get_skill_executor().request_manual_cast(target.global_position, Vector3.FORWARD)
    player.get_skill_executor().process_queued_events()
    var found_initial_segment := false
    var expected_origin := player.global_position + Vector3.UP * 1.05
    var expected_target := target.global_position + Vector3.UP
    for candidate: Node in get_nodes_in_group("vfx_chain_lightning"):
        if not candidate.has_meta("from_position"):
            continue
        var from_position := candidate.get_meta("from_position") as Vector3
        var to_position := candidate.get_meta("to_position") as Vector3
        if from_position.distance_to(expected_origin) < 0.15 and to_position.distance_to(expected_target) < 0.15:
            found_initial_segment = true
            break
    if not found_initial_segment:
        failures.append("Chain Lightning omitted the caster-to-first-target segment")

    TEST_UTILS.place_player(player)
    var meteor := TEST_UTILS.compile([&"core_meteor"])
    player.set_skill_build(meteor.build)
    player.get_skill_executor().request_manual_cast(Vector3(0.0, 0.0, -4.0), Vector3.FORWARD)
    player.get_skill_executor().process_queued_events()
    var found_descent := false
    for candidate: Node in get_nodes_in_group("vfx_meteor_descent"):
        if not candidate.has_meta("start_position"):
            continue
        var start_position := candidate.get_meta("start_position") as Vector3
        var end_position := candidate.get_meta("end_position") as Vector3
        if start_position.y - end_position.y >= 8.0:
            found_descent = true
            break
    if not found_descent:
        failures.append("Meteor created no visible sky-to-ground descent")


func _verify_wave_and_splash(
        player: PlayerController,
        dummies: Array[Node],
        failures: PackedStringArray
) -> void:
    TEST_UTILS.place_player(player)
    TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -2.5))
    var first := dummies[0] as TrainingDummy
    var second := dummies[1] as TrainingDummy
    second.reset_dummy()
    second.global_position = Vector3(0.0, 0.0, -5.0)
    var wave := TEST_UTILS.compile([&"core_shockwave"])
    player.set_skill_build(wave.build)
    wave.build.get_root_core().critical_chance = 0.0
    player.get_skill_executor().request_manual_cast(second.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 45:
        await physics_frame
    if first.health >= first.max_health or second.health >= second.max_health:
        failures.append("Shockwave did not damage each target along its path once")
    var first_loss := first.max_health - first.health
    if first_loss > wave.build.get_root_core().damage * 1.1:
        failures.append("Shockwave damaged the same path target more than once")

    TEST_UTILS.place_player(player)
    TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -3.0))
    first = dummies[0] as TrainingDummy
    second = dummies[1] as TrainingDummy
    second.reset_dummy()
    second.global_position = Vector3(1.25, 0.0, -3.0)
    var orb := TEST_UTILS.compile([&"core_flame_orb"])
    player.set_skill_build(orb.build)
    orb.build.get_root_core().critical_chance = 0.0
    player.get_skill_executor().request_manual_cast(first.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 40:
        await physics_frame
    var direct_loss := first.max_health - first.health
    if second.health >= second.max_health:
        failures.append("Flame Orb impact_radius did not damage a nearby splash target")
    if absf(direct_loss - orb.build.get_root_core().damage) > 0.1:
        failures.append("Flame Orb direct target also received duplicate splash damage")


func _verify_default_hold_freeze(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    TEST_UTILS.place_player(player)
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -2.8))
    var build := SkillCatalog.get_default_build()
    player.set_skill_build(build)
    player.get_skill_executor().request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    await physics_frame
    if player.get_skill_executor().get_held_count() != 3:
        failures.append("Default Frost Lance did not store the Multishot formation in Hold")
    for _frame: int in 125:
        await physics_frame
    if player.get_skill_executor().get_held_count() != 0:
        failures.append("Hold did not auto-release after 1.5 seconds")
    if not target.has_status(&"frozen"):
        failures.append("Frost Multishot did not cross the Freeze buildup threshold")
    if TEST_UTILS.message_count(messages, "On Freeze -> Shockwave") != 1:
        failures.append("Freeze did not trigger exactly one generation-1 Shockwave")


func _verify_hold_reaim(
        player: PlayerController,
        dummies: Array[Node],
        failures: PackedStringArray
) -> void:
    TEST_UTILS.place_player(player)
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -8.0))
    var result := TEST_UTILS.compile([
        &"core_frost_lance", &"pattern_multishot", &"pattern_hold",
    ])
    player.set_skill_build(result.build)
    var executor := player.get_skill_executor()
    executor.request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    await physics_frame
    player.set("_facing_direction", Vector3.RIGHT)
    for _frame: int in 100:
        await physics_frame
    var runtime := executor.get("_runtime") as SkillRuntime
    var manager := runtime.get("_projectile_manager") as ProjectileManager
    var active := manager.get("_active") as Dictionary
    if active.size() != 3:
        failures.append("Hold did not release the preserved three-instance formation")
        return
    var positive_x := 0
    var direction_z_values: Array[float] = []
    for raw_projectile: Variant in active.values():
        var projectile := raw_projectile as SkillProjectile
        if projectile.direction.x > 0.7:
            positive_x += 1
        direction_z_values.append(projectile.direction.z)
    direction_z_values.sort()
    if positive_x != 3:
        failures.append("Held formation did not re-aim as a group toward the current cursor")
    if direction_z_values.back() - direction_z_values.front() < 0.1:
        failures.append("Held Multishot did not preserve its relative fan arrangement")


func _verify_crit_trigger(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    TEST_UTILS.place_player(player)
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -2.4))
    var config := TriggerConfig.new()
    config.internal_cooldown = 0.0
    var result := TEST_UTILS.compile([
        &"core_slash", &"pattern_repeat", &"trigger_crit", &"core_shockwave",
    ], {2: config})
    player.set_skill_build(result.build)
    result.build.get_root_core().critical_chance = 1.0
    player.get_skill_executor().request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 35:
        await physics_frame
    var trigger_count := TEST_UTILS.message_count(messages, "On Crit -> Shockwave")
    if trigger_count < 1 or trigger_count > 3:
        failures.append("Slash + Repeat On-Crit did not execute within its bounded three-hit chain")
    if player.get_skill_executor().get_queue_size() != 0:
        failures.append("Generation-1 Shockwave recursively generated Trigger events")


func _verify_return_trigger(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    TEST_UTILS.place_player(player)
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -3.0))
    var result := TEST_UTILS.compile([
        &"core_arrow_shot", &"trajectory_return", &"trigger_return", &"core_ground_burst",
    ])
    player.set_skill_build(result.build)
    player.get_skill_executor().request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 100:
        await physics_frame
    if TEST_UTILS.message_count(messages, "On Return -> Ground Burst") != 1:
        failures.append("Arrow Shot + Return did not produce one On Return event at the owner")


func _verify_channel_trigger(
        player: PlayerController,
        dummies: Array[Node],
        messages: Array[String],
        failures: PackedStringArray
) -> void:
    messages.clear()
    TEST_UTILS.place_player(player)
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -4.0))
    var config := TriggerConfig.new()
    config.channel_interval = 0.2
    config.internal_cooldown = 0.0
    var result := TEST_UTILS.compile([
        &"core_void_beam", &"trigger_channel", &"core_meteor",
    ], {1: config})
    player.set_skill_build(result.build)
    var executor := player.get_skill_executor()
    Input.action_press("cast_skill")
    executor.begin_channel(target.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 50:
        await physics_frame
    executor.stop_channel()
    Input.action_release("cast_skill")
    if TEST_UTILS.message_count(messages, "Channel Trigger -> Meteor") < 2:
        failures.append("Void Beam Channel Trigger did not use the configured interval")
    if result.build.get_root_core().channel_can_move:
        failures.append("Void Beam must lock movement while Whirlblade remains mobile")
    var whirl := TEST_UTILS.compile([&"core_whirlblade"])
    if not whirl.build.get_root_core().channel_can_move:
        failures.append("Whirlblade must remain mobile while channelled")
    player.set_skill_build(whirl.build)
    Input.action_press("cast_skill")
    executor.begin_channel(target.global_position, Vector3(0.0, 0.0, -1.0))
    await physics_frame
    var sustain: Node3D
    for candidate: Node in get_nodes_in_group("vfx_channel_sustain"):
        if candidate is Node3D and candidate.get_parent() == player:
            sustain = candidate as Node3D
            break
    if sustain == null or not bool(sustain.get_meta("follows_source", false)):
        failures.append("Whirlblade created no persistent player-centred windmill VFX")
    else:
        var offset := sustain.global_position - player.global_position
        player.global_position += Vector3.RIGHT * 1.5
        await physics_frame
        if sustain.global_position.distance_to(player.global_position + offset) > 0.05:
            failures.append("Whirlblade windmill did not follow player movement")
    executor.stop_channel()
    Input.action_release("cast_skill")
    await process_frame
    for candidate: Node in get_nodes_in_group("vfx_channel_sustain"):
        if is_instance_valid(candidate) and candidate.get_parent() == player:
            failures.append("Whirlblade sustain VFX remained after channel end")
            break


func _verify_remnant_and_trajectories(
        player: PlayerController,
        dummies: Array[Node],
        failures: PackedStringArray
) -> void:
    TEST_UTILS.place_player(player)
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -5.0))
    var remnant := TEST_UTILS.compile([&"core_flame_orb", &"pattern_remnant"])
    player.set_skill_build(remnant.build)
    player.get_skill_executor().request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 20:
        await physics_frame
    if player.get_skill_executor().get_persistent_effect_count() <= 0:
        failures.append("Remnant did not create budgeted persistent trail effects")

    var trajectory_combo := TEST_UTILS.compile([
        &"core_arrow_shot", &"trajectory_pierce", &"trajectory_fork",
        &"trajectory_chain", &"trajectory_return", &"trajectory_homing",
    ])
    if not trajectory_combo.valid:
        failures.append("Five shared Trajectory operations did not compose: %s" % "; ".join(trajectory_combo.errors))
        return
    player.set_skill_build(trajectory_combo.build)
    player.get_skill_executor().request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    await physics_frame
    if player.get_skill_executor().get_active_projectile_count() <= 0:
        failures.append("Composed Trajectory build spawned no shared projectile instance")


func _verify_summon_follow(
        player: PlayerController,
        dummies: Array[Node],
        failures: PackedStringArray
) -> void:
    TEST_UTILS.place_player(player)
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -5.0))
    var result := TEST_UTILS.compile([&"core_summon"])
    player.set_skill_build(result.build)
    var executor := player.get_skill_executor()
    executor.request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    await physics_frame
    var runtime := executor.get("_runtime") as SkillRuntime
    var minions := runtime.get("_active_minions") as Array
    if minions.size() != 1:
        failures.append("Summon follow test created no minion")
        return
    var minion := minions[0] as SkillMinion
    var start_position := minion.global_position
    player.global_position = Vector3(5.0, 0.0, 0.0)
    for _frame: int in 45:
        await physics_frame
    if minion.global_position.distance_to(start_position) < 1.0 or minion.global_position.distance_to(player.global_position) > 3.5:
        failures.append("Summon did not follow its owner after movement")


func _finish(main_scene: Node, failures: PackedStringArray) -> void:
    var player := get_first_node_in_group("player") as PlayerController
    if player != null:
        player.get_skill_executor().set_build(null)
    for _frame: int in 10:
        await physics_frame
    main_scene.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: all 14 Cores, wave, splash, Hold/Freeze, Crit, Return, Channel, Remnant, Trajectory, and Summon")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)
