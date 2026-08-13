extends SceneTree

const CONCEPT_LIBRARY := preload("res://scripts/concept_library.gd")
const STRESS_FRAMES: int = 1800


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
    executor.set_graph(CONCEPT_LIBRARY.get_default_graph())
    var runtime := executor.get("_runtime") as SkillRuntime
    var manager := runtime.get("_projectile_manager") as ProjectileManager
    var definition := executor.graph.get_primary_skill()
    definition.projectile_lifetime = 15.0
    definition.projectile_speed = 1.0
    definition.homing_strength = 0.0
    definition.rotation_speed = 0.0
    definition.projectile_acceleration = 0.0
    var context := {
        "cast_id": 1,
        "graph_revision": executor.graph_revision,
        "source_skill_node_id": 0,
        "depth": 0,
        "applied_operations": [],
    }
    _fill_projectiles(manager, main_scene, definition, player, context)
    var start_msec := Time.get_ticks_msec()
    for frame_index: int in STRESS_FRAMES:
        var cast_id := 1000 + frame_index
        for event_index: int in SkillGraphExecutor.MAX_EVENTS_PER_PHYSICS_FRAME:
            executor.call("_enqueue", CombatEvent.new().configure({
                "cast_id": cast_id,
                "graph_revision": executor.graph_revision,
                "source_skill_node_id": 0,
                "event_type": &"stress",
                "world_position": Vector3.ZERO,
            }))
        await physics_frame
        context["cast_id"] = cast_id
        _fill_projectiles(manager, main_scene, definition, player, context)
    var elapsed_seconds := maxf(float(Time.get_ticks_msec() - start_msec) / 1000.0, 0.001)
    var average_fps := float(STRESS_FRAMES) / elapsed_seconds
    if average_fps < 55.0:
        failures.append("30-second stress average %.1f FPS was below the 60 FPS target tolerance" % average_fps)
    if manager.peak_active_count != ProjectileManager.MAX_ACTIVE_PROJECTILES:
        failures.append("Stress test never reached 384 active projectiles")
    if executor.get_queue_size() != 0:
        failures.append("Event FIFO did not drain after processing 48 events per frame")
    manager.clear_active()
    for _frame: int in 360:
        await physics_frame
    if manager.get_active_count() != 0:
        failures.append("Active projectile count did not return to zero")
    if get_nodes_in_group("combat_vfx").size() > 2:
        failures.append("Stress VFX did not return to baseline")
    main_scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS: 30s stress at %.1f FPS, 384 projectiles, 48 events/frame, clean baseline" % average_fps)
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _fill_projectiles(
        manager: ProjectileManager,
        parent: Node,
        definition: SkillDefinition,
        player: PlayerController,
        context: Dictionary
) -> void:
    while manager.get_active_count() < ProjectileManager.MAX_ACTIVE_PROJECTILES:
        var index := manager.get_active_count()
        manager.request_projectile(
            parent,
            definition,
            player,
            Vector3(40.0 + float(index % 24), 1.0, 40.0 + float(index / 24)),
            Vector3.FORWARD,
            context,
            true
        )
