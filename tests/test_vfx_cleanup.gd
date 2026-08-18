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
    var dummies: Array[Node] = get_nodes_in_group("damageable")
    var target := TEST_UTILS.isolate_target(dummies, Vector3(0.0, 0.0, -5.0))
    TEST_UTILS.place_player(player)
    var executor := player.get_skill_executor()
    var safe_build := TEST_UTILS.compile([&"core_slash"]).build

    var hold_build := TEST_UTILS.compile([
        &"core_frost_lance", &"pattern_multishot", &"pattern_hold",
    ]).build
    player.set_skill_build(hold_build)
    executor.request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    await physics_frame
    if executor.get_held_count() <= 0:
        failures.append("Hold setup created no stored instances")
    player.set_skill_build(safe_build)
    if executor.get_held_count() != 0:
        failures.append("Build revision did not clear Held instances")

    var remnant_build := TEST_UTILS.compile([&"core_flame_orb", &"pattern_remnant"]).build
    player.set_skill_build(remnant_build)
    executor.request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    for _frame: int in 15:
        await physics_frame
    if executor.get_persistent_effect_count() <= 0 or executor.get_active_projectile_count() <= 0:
        failures.append("Remnant setup created no persistent/projectile instances")
    player.set_skill_build(safe_build)
    if executor.get_persistent_effect_count() != 0 or executor.get_active_projectile_count() != 0:
        failures.append("Build revision did not clear Remnants and projectiles")

    var summon_build := TEST_UTILS.compile([&"core_summon"]).build
    player.set_skill_build(summon_build)
    executor.request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    await physics_frame
    if executor.get_active_minion_count() != 1:
        failures.append("Summon setup created no minion")
    player.set_skill_build(safe_build)
    if executor.get_active_minion_count() != 0:
        failures.append("Build revision did not clean the minion")

    var repeat_build := TEST_UTILS.compile([&"core_meteor", &"pattern_repeat"]).build
    player.set_skill_build(repeat_build)
    executor.request_manual_cast(target.global_position, Vector3(0.0, 0.0, -1.0))
    await physics_frame
    if executor.get_scheduled_action_count() <= 0:
        failures.append("Repeat/Meteor setup created no scheduled action")
    player.set_skill_build(safe_build)
    if executor.get_scheduled_action_count() != 0:
        failures.append("Build revision did not clear scheduled actions")

    for _frame: int in 240:
        await physics_frame
    var remaining_vfx := get_nodes_in_group("combat_vfx").size()
    if remaining_vfx > 2:
        failures.append("Transient VFX/trails remained after cleanup: %d" % remaining_vfx)

    executor.set_build(null)
    main_scene.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: revision cleanup reclaimed Hold, Remnant, projectile, minion, scheduled, and VFX instances")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)
