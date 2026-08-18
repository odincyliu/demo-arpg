extends SceneTree

const TEST_UTILS := preload("res://tests/six_link_test_utils.gd")

const EVENT_TRIGGERS: Dictionary = {
    &"trigger_hit": &"hit",
    &"trigger_crit": &"critical",
    &"trigger_kill": &"kill",
    &"trigger_stun": &"stun",
    &"trigger_freeze": &"freeze",
    &"trigger_ignite": &"ignite",
    &"trigger_shock": &"electrified",
}


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
    var dummies: Array[Node] = get_nodes_in_group("damageable")
    var target := dummies[0] as TrainingDummy
    TEST_UTILS.place_player(player)
    target.global_position = Vector3(0.0, 0.0, -2.5)

    await _verify_event_triggers(player, target, failures)
    await _verify_damage_and_channel_triggers(player, target, failures)
    await _verify_return_trigger_event(player, target, failures)
    await _verify_trigger_conditions(player, target, failures)
    await _verify_ailments(target, failures)
    await _verify_dot_kill_source(target, failures)

    player.get_skill_executor().set_build(null)
    main_scene.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: ten Triggers, advanced conditions, generation guard, ailments, vulnerability, and DoT source")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _verify_event_triggers(
        player: PlayerController,
        target: TrainingDummy,
        failures: PackedStringArray
) -> void:
    for trigger_id: StringName in EVENT_TRIGGERS:
        var result := TEST_UTILS.compile([&"core_rapid_slash", trigger_id, &"core_summon"])
        if not result.valid:
            failures.append("%s did not compile" % trigger_id)
            continue
        player.set_skill_build(result.build)
        var executor := player.get_skill_executor()
        var event_type := EVENT_TRIGGERS[trigger_id] as StringName
        executor.call("_on_combat_report", _report(executor, target, event_type, 100 + EVENT_TRIGGERS.keys().find(trigger_id), 0))
        executor.process_queued_events()
        executor.process_queued_events()
        if executor.get_active_minion_count() != 1:
            failures.append("%s did not evaluate its %s event" % [trigger_id, event_type])
        player.set_skill_build(result.build)
        executor.call("_on_combat_report", _report(executor, target, event_type, 200 + EVENT_TRIGGERS.keys().find(trigger_id), 1))
        executor.process_queued_events()
        executor.process_queued_events()
        if executor.get_active_minion_count() != 0:
            failures.append("%s recursively fired from generation 1" % trigger_id)


func _verify_damage_and_channel_triggers(
        player: PlayerController,
        target: TrainingDummy,
        failures: PackedStringArray
) -> void:
    var damage_config := TriggerConfig.new()
    damage_config.damage_threshold_ratio = 0.1
    damage_config.internal_cooldown = 0.0
    var damage_result := TEST_UTILS.compile([
        &"core_slash", &"trigger_damage_taken", &"core_summon",
    ], {1: damage_config})
    player.set_skill_build(damage_result.build)
    var executor := player.get_skill_executor()
    executor.request_player_damage(9.0, player.global_position)
    executor.process_queued_events()
    executor.process_queued_events()
    if executor.get_active_minion_count() != 0:
        failures.append("On Damage Taken fired before its accumulated threshold")
    executor.request_player_damage(1.0, player.global_position)
    executor.process_queued_events()
    executor.process_queued_events()
    if executor.get_active_minion_count() != 1:
        failures.append("On Damage Taken did not fire at 10% maximum health")

    var channel_config := TriggerConfig.new()
    channel_config.channel_interval = 0.1
    channel_config.internal_cooldown = 0.0
    var channel_result := TEST_UTILS.compile([
        &"core_void_beam", &"trigger_channel", &"core_summon",
    ], {1: channel_config})
    player.set_skill_build(channel_result.build)
    executor = player.get_skill_executor()
    Input.action_press("cast_skill")
    executor.begin_channel(target.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 28:
        await physics_frame
    executor.stop_channel()
    Input.action_release("cast_skill")
    if executor.get_active_minion_count() < 2:
        failures.append("Channel Trigger did not repeat at its configured interval")


func _verify_return_trigger_event(
        player: PlayerController,
        target: TrainingDummy,
        failures: PackedStringArray
) -> void:
    var result := TEST_UTILS.compile([
        &"core_returning_blade", &"trajectory_return", &"trigger_return", &"core_summon",
    ])
    player.set_skill_build(result.build)
    var executor := player.get_skill_executor()
    executor.call("_on_combat_report", _report(executor, target, &"return", 301, 0))
    executor.process_queued_events()
    executor.process_queued_events()
    if executor.get_active_minion_count() != 1:
        failures.append("On Return did not evaluate the shared return event")


func _verify_trigger_conditions(
        player: PlayerController,
        target: TrainingDummy,
        failures: PackedStringArray
) -> void:
    var config := TriggerConfig.new()
    config.every_n = 2
    config.chance = 100.0
    config.internal_cooldown = 0.0
    config.max_player_health_ratio = 0.5
    config.required_target_status = &"ignite"
    var result := TEST_UTILS.compile([
        &"core_slash", &"trigger_hit", &"core_summon",
    ], {1: config})
    player.health = 40.0
    target.reset_dummy()
    target.apply_ignite(3.0, 1.0, {})
    player.set_skill_build(result.build)
    var executor := player.get_skill_executor()
    executor.call("_on_combat_report", _report(executor, target, &"hit", 401, 0))
    executor.process_queued_events()
    executor.process_queued_events()
    if executor.get_active_minion_count() != 0:
        failures.append("Every-N fired on occurrence one")
    executor.call("_on_combat_report", _report(executor, target, &"hit", 402, 0))
    executor.process_queued_events()
    executor.process_queued_events()
    if executor.get_active_minion_count() != 1:
        failures.append("Every-N, low-health, and target-status conditions did not pass together")
    var first_roll := float(executor.call("_deterministic_percent", 9, 1, 3))
    var second_roll := float(executor.call("_deterministic_percent", 9, 1, 3))
    if not is_equal_approx(first_roll, second_roll):
        failures.append("Trigger probability was not deterministic")

    config = TriggerConfig.new()
    config.chance = 0.0
    config.internal_cooldown = 0.0
    result = TEST_UTILS.compile([&"core_slash", &"trigger_hit", &"core_summon"], {1: config})
    player.set_skill_build(result.build)
    executor = player.get_skill_executor()
    executor.call("_on_combat_report", _report(executor, target, &"hit", 403, 0))
    executor.process_queued_events()
    executor.process_queued_events()
    if executor.get_active_minion_count() != 0:
        failures.append("Zero-percent Trigger probability fired")

    config = TriggerConfig.new()
    config.internal_cooldown = 1.0
    result = TEST_UTILS.compile([&"core_slash", &"trigger_hit", &"core_summon"], {1: config})
    player.set_skill_build(result.build)
    executor = player.get_skill_executor()
    for cast_id: int in [404, 405]:
        executor.call("_on_combat_report", _report(executor, target, &"hit", cast_id, 0))
        executor.process_queued_events()
        executor.process_queued_events()
    if executor.get_active_minion_count() != 1:
        failures.append("Internal cooldown did not suppress the same-frame Trigger")
    player.health = player.max_health


func _verify_ailments(target: TrainingDummy, failures: PackedStringArray) -> void:
    target.reset_dummy()
    if not target.apply_ignite(3.0, 4.0, {"source_core_slot_index": 0}):
        failures.append("First Ignite application did not report a transition")
    if target.apply_ignite(3.0, 4.0, {"source_core_slot_index": 0}):
        failures.append("Ignite refresh incorrectly reported a second transition")
    if not target.apply_electrified(3.0, 1.2):
        failures.append("First Shock application did not report Electrified")
    if target.apply_electrified(3.0, 1.2):
        failures.append("Shock refresh incorrectly reported a second transition")
    var health_before := target.health
    target.take_damage(10.0)
    if absf((health_before - target.health) - 12.0) > 0.01:
        failures.append("Electrified did not increase damage taken by 20%")

    target.reset_dummy()
    target.add_freeze_buildup(50.0, 2.0)
    for _frame: int in 30:
        await physics_frame
    var decayed_freeze := float(target.get("_freeze_buildup"))
    if decayed_freeze >= 50.0 or decayed_freeze <= 0.0:
        failures.append("Freeze buildup did not decay over time")
    target.reset_dummy()
    if target.add_freeze_buildup(35.0, 2.0) or target.add_freeze_buildup(35.0, 2.0):
        failures.append("Freeze triggered before 100 buildup")
    if not target.add_freeze_buildup(35.0, 2.0):
        failures.append("Freeze did not trigger after crossing 100 buildup")
    target.reset_dummy()
    if target.add_stun_buildup(35.0, 1.5) or target.add_stun_buildup(35.0, 1.5):
        failures.append("Stun triggered before 100 buildup")
    if not target.add_stun_buildup(35.0, 1.5):
        failures.append("Stun did not trigger after crossing 100 buildup")

    target.reset_dummy()
    for stack_index: int in 12:
        target.apply_poison_stack(4.0, 1.0, 10, {"stack": stack_index})
    var poison_stacks := target.get("_poison_stacks") as Array
    if poison_stacks.size() != 10:
        failures.append("Poison did not cap at ten stacks")
    target.apply_bleed(3.0, 2.0, {})
    if not target.has_status(&"bleed") or not target.has_status(&"poison"):
        failures.append("Bleed or Poison status was not retained")


func _verify_dot_kill_source(target: TrainingDummy, failures: PackedStringArray) -> void:
    target.reset_dummy()
    target.health = 1.0
    var killed_context: Dictionary = {}
    var callback := func(context: Dictionary, _position: Vector3, _target: Node3D) -> void:
        killed_context.merge(context, true)
    target.dot_killed.connect(callback)
    target.apply_ignite(1.0, 10.0, {
        "cast_id": 700,
        "build_revision": 1,
        "source_core_slot_index": 4,
        "generation": 0,
    })
    for _frame: int in 30:
        await physics_frame
        if not killed_context.is_empty():
            break
    if killed_context.is_empty() or int(killed_context.get("source_core_slot_index", -1)) != 4:
        failures.append("DoT kill did not preserve its source Core attribution")
    if target.dot_killed.is_connected(callback):
        target.dot_killed.disconnect(callback)
    for _frame: int in 100:
        await physics_frame


func _report(
        executor: SkillExecutor,
        target: TrainingDummy,
        event_type: StringName,
        cast_id: int,
        generation: int
) -> Dictionary:
    return {
        "cast_id": cast_id,
        "build_revision": executor.build_revision,
        "source_core_slot_index": 0,
        "target_core_slot_index": 0,
        "generation": generation,
        "events": [event_type],
        "world_position": target.global_position,
        "target": target,
        "source": executor.source_player,
        "facing_direction": Vector3(0.0, 0.0, -1.0),
    }
