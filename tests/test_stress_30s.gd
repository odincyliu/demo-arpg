extends SceneTree

const TEST_UTILS := preload("res://tests/six_link_test_utils.gd")

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
    TEST_UTILS.place_player(player, Vector3(0.0, 0.0, 7.0))
    var result := TEST_UTILS.compile([
        &"core_arrow_shot", &"pattern_phantom", &"pattern_repeat",
        &"pattern_multishot", &"shape_orbit", &"pattern_remnant",
    ])
    if not result.valid:
        push_error("Stress build failed: %s" % "; ".join(result.errors))
        quit(1)
        return
    player.set_skill_build(result.build)
    var executor := player.get_skill_executor()
    var peak_projectiles := 0
    var peak_vfx := 0
    for frame_index: int in STRESS_FRAMES:
        if frame_index % 90 == 0:
            executor.request_manual_cast(Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, -1.0))
        await physics_frame
        peak_projectiles = maxi(peak_projectiles, executor.get_active_projectile_count())
        peak_vfx = maxi(peak_vfx, get_nodes_in_group("combat_vfx").size())
        if executor.get_active_projectile_count() > ProjectileManager.MAX_ACTIVE_PROJECTILES:
            failures.append("Projectile count exceeded 384 during stress")
            break
        if executor.get_queue_size() > SkillExecutor.MAX_EVENTS_PER_CAST:
            failures.append("Event queue escaped per-cast safety bounds")
            break

    player.set_skill_build(TEST_UTILS.compile([&"core_slash"]).build)
    for _frame: int in 240:
        await physics_frame
    if executor.get_active_projectile_count() != 0:
        failures.append("Stress projectiles remained after revision cleanup")
    if executor.get_held_count() != 0 or executor.get_persistent_effect_count() != 0 or executor.get_active_minion_count() != 0:
        failures.append("Stress auxiliary instances remained after revision cleanup")
    if get_nodes_in_group("combat_vfx").size() > 2:
        failures.append("Stress VFX did not return to baseline")
    if peak_projectiles <= 0 or peak_vfx <= 0:
        failures.append("Stress run exercised no projectile or VFX load")

    var rejected_projectiles := executor.get_rejected_projectile_count()
    executor.set_build(null)
    main_scene.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: 30-second stress stayed within budgets (peak P%d, VFX%d, rejected P%d)" % [
            peak_projectiles,
            peak_vfx,
            rejected_projectiles,
        ])
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)
