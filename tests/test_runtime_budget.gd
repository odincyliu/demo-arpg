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
    var executor := player.get_skill_executor()
    executor.set_physics_process(false)
    executor.set_graph(CONCEPT_LIBRARY.get_default_graph())

    var accepted := 0
    for event_index: int in 129:
        var event := CombatEvent.new().configure({
            "cast_id": 77,
            "graph_revision": executor.graph_revision,
            "source_skill_node_id": 0,
            "event_type": &"test",
            "world_position": Vector3.ZERO,
        })
        if bool(executor.call("_enqueue", event)):
            accepted += 1
    if accepted != SkillGraphExecutor.MAX_EVENTS_PER_CAST:
        failures.append("Expected 128 accepted events, got %d" % accepted)
    if int(executor.counters["events_rejected"]) != 1:
        failures.append("The 129th event was not rejected and counted")
    var processed := executor.process_queued_events(SkillGraphExecutor.MAX_EVENTS_PER_PHYSICS_FRAME)
    if processed != 48 or executor.get_queue_size() != 80:
        failures.append("The 49th event was not retained in FIFO for the next frame")

    executor.set_graph(CONCEPT_LIBRARY.get_default_graph())
    if executor.get_queue_size() != 0 or not executor.get("_trigger_occurrences").is_empty():
        failures.append("Graph revision did not clear queued events and Trigger state")
    var runtime: SkillRuntime = executor.get("_runtime") as SkillRuntime
    var manager: ProjectileManager = runtime.get("_projectile_manager") as ProjectileManager
    var definition := executor.graph.get_primary_skill()
    var context := {
        "cast_id": 88,
        "graph_revision": executor.graph_revision,
        "source_skill_node_id": 0,
        "depth": 0,
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
        failures.append("Projectile pool did not return to its 384-object baseline")

    main_scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS: 128-event, 48-per-frame, and 384-projectile budgets")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)
