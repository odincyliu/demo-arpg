extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const TEST_UTILS := preload("res://tests/six_link_test_utils.gd")


func _init() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var failures: PackedStringArray = []
    for raw_component: Variant in SkillCatalog.get_catalog().values():
        var component := raw_component as SkillComponent
        var result := _representative_result(component)
        if not result.valid:
            failures.append("%s has no VFX host: %s" % [component.component_id, "; ".join(result.errors)])
            continue
        var definition := result.compiled_build.triggered_core if component.is_trigger() else result.compiled_build.root_core
        var holder := Node3D.new()
        root.add_child(holder)
        COMBAT_VFX.spawn_cast_layers(holder, definition, Vector3.ZERO, Vector3.FORWARD)
        await process_frame
        if holder.get_child_count() == 0:
            failures.append("%s produced no cast VFX or generic fallback" % component.component_id)
        match component.category:
            &"Core":
                if _count_group_children(holder, &"vfx_skill_identity") == 0:
                    failures.append("Core %s has no identity VFX fallback" % component.component_id)
            &"Trigger":
                if definition.trigger_type == &"" or _count_group_children(holder, &"vfx_trigger") == 0:
                    failures.append("Trigger %s has no identifiable cue" % component.component_id)
            &"Shape":
                if _count_group_children(holder, &"vfx_shape") == 0:
                    failures.append("Shape %s has no VFX" % component.component_id)
            &"Trajectory", &"Pattern", &"Transform":
                if _count_group_children(holder, &"vfx_modifier") == 0:
                    failures.append("%s %s has no operation VFX" % [component.category, component.component_id])
            &"Effect":
                COMBAT_VFX.spawn_hit_layers(holder, definition, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 1.0, 2.0), Vector3.FORWARD)
                if _count_group_children(holder, &"vfx_effect") == 0:
                    failures.append("Effect %s has no hit VFX" % component.component_id)
        holder.queue_free()
        await process_frame

    await _verify_projectile_fallback(failures)
    await _verify_chain_lightning(failures)
    if failures.is_empty():
        print("PASS: all 55 Components expose Core/Trigger/operation/status VFX with generic fallback")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _representative_result(component: SkillComponent) -> SkillCompileResult:
    if component.is_core():
        return TEST_UTILS.compile([component.component_id])
    if component.is_trigger():
        if component.component_id == &"trigger_channel":
            return TEST_UTILS.compile([&"core_void_beam", component.component_id, &"core_meteor"])
        if component.component_id == &"trigger_return":
            return TEST_UTILS.compile([&"core_returning_blade", &"trajectory_return", component.component_id, &"core_explosion"])
        return TEST_UTILS.compile([&"core_rapid_slash", component.component_id, &"core_explosion"])
    var host := &"core_arrow_shot"
    match component.component_id:
        &"shape_nova":
            host = &"core_shockwave"
        &"effect_ignite":
            host = &"core_flame_orb"
        &"effect_freeze":
            host = &"core_frost_lance"
        &"effect_shock":
            host = &"core_chain_lightning"
        &"pattern_hold", &"pattern_remnant", &"shape_orbit":
            host = &"core_flame_orb"
    return TEST_UTILS.compile([host, component.component_id])


func _count_group_children(holder: Node, group: StringName) -> int:
    var count := 0
    for child: Node in holder.get_children():
        if child.is_in_group(group):
            count += 1
    return count


func _verify_projectile_fallback(failures: PackedStringArray) -> void:
    var result := TEST_UTILS.compile([&"core_frost_lance"])
    var holder := Node3D.new()
    root.add_child(holder)
    var manager := ProjectileManager.new()
    holder.add_child(manager)
    await process_frame
    var projectile := manager.request_projectile(
        holder,
        result.build.get_root_core(),
        holder,
        Vector3.ZERO,
        Vector3.FORWARD,
        {"build_revision": 1},
        true
    )
    if projectile == null or not projectile.visible:
        failures.append("Projectile without dedicated art had no procedural fallback")
    manager.clear_active()
    holder.queue_free()
    await process_frame


func _verify_chain_lightning(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var from_position := Vector3(0.0, 1.1, 0.0)
    var to_position := Vector3(5.0, 1.0, -1.0)
    COMBAT_VFX.spawn_chain_lightning(holder, from_position, to_position, Color("8fdcff"), 17)
    await process_frame
    var chain_root: Node3D
    for candidate: Node in get_nodes_in_group("vfx_chain_lightning"):
        if candidate.has_meta("segment_count"):
            chain_root = candidate as Node3D
            break
    if chain_root == null:
        failures.append("Shared Chain operation created no lightning VFX")
    elif int(chain_root.get_meta("segment_count")) < 7 or int(chain_root.get_meta("segment_count")) > 9:
        failures.append("Shared Chain lightning did not use 7-9 segments")
    for _frame: int in 36:
        await physics_frame
    if not get_nodes_in_group("vfx_chain_lightning").is_empty():
        failures.append("Chain VFX remained after its lifetime")
    holder.queue_free()
    await process_frame
