extends SceneTree

const CONCEPT_LIBRARY := preload("res://scripts/concept_library.gd")


func _init() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var packed_scene := load("res://main.tscn") as PackedScene
    var main_scene := packed_scene.instantiate()
    root.add_child(main_scene)
    current_scene = main_scene
    await process_frame
    await physics_frame
    var player := get_first_node_in_group("player") as PlayerController
    var graph := SkillGraph.new()
    graph.set_node(SkillGraphNode.new().configure(0, &"skill_fireball", SkillGraph.ROOT_PARENT))
    graph.set_node(SkillGraphNode.new().configure(1, &"shape_rotate", 0))
    graph.set_node(SkillGraphNode.new().configure(2, &"modifier_accelerate", 0))
    graph.set_node(SkillGraphNode.new().configure(3, &"effect_explosion", 0))
    var result := CONCEPT_LIBRARY.compile_graph(graph)
    if not result.valid:
        push_error("Stress graph failed: %s" % " / ".join(result.errors))
        quit(1)
        return
    player.set_skill_graph(result.graph)
    player.set_view_camera(null)
    player.set("_facing_direction", Vector3(0.0, 0.0, -1.0))
    for _cast_index: int in 4:
        player.set("_cooldown_remaining", 0.0)
        player.try_cast_skill()
        for _frame: int in 5:
            await physics_frame
    var peak_count := get_nodes_in_group("combat_vfx").size()
    if peak_count <= 0:
        push_error("Stress casts created no VFX")
        quit(1)
        return
    for _frame: int in 360:
        await physics_frame
    var remaining_count := get_nodes_in_group("combat_vfx").size()
    var active_projectiles := player.get_skill_executor().get_active_projectile_count()
    if remaining_count > 2 or active_projectiles != 0:
        push_error("Cleanup failed: VFX %d, active projectiles %d" % [remaining_count, active_projectiles])
        quit(1)
        return
    player.get_skill_executor().set_graph(null)
    for _frame: int in 20:
        await physics_frame
    main_scene.queue_free()
    await process_frame
    await process_frame
    print("PASS: VFX peak %d, remaining %d, projectiles pooled" % [peak_count, remaining_count])
    quit(0)
