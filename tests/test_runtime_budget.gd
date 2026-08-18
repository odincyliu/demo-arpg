extends SceneTree

const TEST_UTILS := preload("res://tests/six_link_test_utils.gd")


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
    var executor := player.get_skill_executor()
    executor.set_physics_process(false)
    var result := TEST_UTILS.compile([&"core_arrow_shot"])
    executor.set_build(result.build)

    var accepted := 0
    for event_index: int in 129:
        var event := CombatEvent.new().configure({
            "cast_id": 77,
            "build_revision": executor.build_revision,
            "source_core_slot_index": 0,
            "event_type": &"test",
            "world_position": Vector3.ZERO,
        })
        if bool(executor.call("_enqueue", event)):
            accepted += 1
    if accepted != SkillExecutor.MAX_EVENTS_PER_CAST:
        failures.append("Expected 128 accepted events, got %d" % accepted)
    if int(executor.counters["events_rejected"]) != 1:
        failures.append("The 129th event was not rejected and counted")
    var processed := executor.process_queued_events(SkillExecutor.MAX_EVENTS_PER_PHYSICS_FRAME)
    if processed != 48 or executor.get_queue_size() != 80:
        failures.append("The 49th event was not retained in FIFO for the next frame")

    executor.set_build(result.build)
    if executor.get_queue_size() != 0 or not (executor.get("_trigger_occurrences") as Dictionary).is_empty():
        failures.append("Build revision did not clear queued events and Trigger state")
    var runtime := executor.get("_runtime") as SkillRuntime
    var manager := runtime.get("_projectile_manager") as ProjectileManager
    var definition := executor.build.get_root_core()
    var context := {
        "cast_id": 88,
        "build_revision": executor.build_revision,
        "source_core_slot_index": 0,
        "generation": 0,
        "applied_operations": [],
    }
    for projectile_index: int in 385:
        manager.request_projectile(
            main_scene,
            definition,
            player,
            Vector3(float(projectile_index % 16), 1.0, float(projectile_index / 16)),
            Vector3.FORWARD,
            context,
            true
        )
    if manager.get_active_count() != ProjectileManager.MAX_ACTIVE_PROJECTILES:
        failures.append("Projectile manager did not cap active projectiles at 384")
    if manager.rejected_requests != 1:
        failures.append("The 385th projectile request was not rejected and counted")
    manager.clear_active()
    await process_frame
    if manager.get_active_count() != 0 or manager.get_pool_count() != 384:
        failures.append("Projectile pool did not return all 384 instances")

    var persistent_result := TEST_UTILS.compile([&"core_void_rift"])
    executor.set_build(persistent_result.build)
    var persistent_context := {
        "cast_id": 90,
        "build_revision": executor.build_revision,
        "source_core_slot_index": 0,
        "generation": 0,
    }
    for effect_index: int in SkillRuntime.MAX_PERSISTENT_EFFECTS + 1:
        runtime.call(
            "_add_persistent",
            persistent_result.build.get_root_core(),
            Vector3(float(effect_index), 0.0, 0.0),
            player,
            persistent_context,
            1.0,
            false
        )
    if executor.get_persistent_effect_count() != SkillRuntime.MAX_PERSISTENT_EFFECTS:
        failures.append("Persistent Effect budget did not cap at 128")

    var summon_result := TEST_UTILS.compile([&"core_summon"])
    executor.set_build(summon_result.build)
    var summon_context := {
        "cast_id": 91,
        "build_revision": executor.build_revision,
        "source_core_slot_index": 0,
        "generation": 0,
    }
    for minion_index: int in SkillRuntime.MAX_ACTIVE_MINIONS + 1:
        runtime.call(
            "_spawn_minion",
            summon_result.build.get_root_core(),
            player,
            Vector3.ZERO,
            summon_context,
            minion_index
        )
    if executor.get_active_minion_count() != SkillRuntime.MAX_ACTIVE_MINIONS:
        failures.append("Minion budget did not cap at 24")
    executor.set_build(result.build)
    if executor.get_persistent_effect_count() != 0 or executor.get_active_minion_count() != 0:
        failures.append("Auxiliary budget instances were not reclaimed on revision")
    var hold_result := TEST_UTILS.compile([&"core_frost_lance", &"pattern_hold"])
    if hold_result.build.get_root_core().hold_max_stored != 5:
        failures.append("Central Hold limit was not five instances")

    executor.set_build(null)
    main_scene.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: event/frame/projectile/Hold/Persistent/Minion budgets")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)
