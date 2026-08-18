extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const SHADOW_STYLE := preload("res://scripts/shadow_vfx_style.gd")
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
                COMBAT_VFX.spawn_hit_layers(holder, definition, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 1.0, 2.0), Vector3.FORWARD)
                if _count_group_children(holder, &"vfx_skill_identity") < 2:
                    failures.append("Core %s has no dedicated hit/lifecycle VFX" % component.component_id)
                _spawn_lifecycle_sample(holder, definition)
                if _count_group_descendants(holder, &"vfx_skill_identity") < 3:
                    failures.append("Core %s has no sustained/end VFX sample" % component.component_id)
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
        _verify_neutral_tree(holder, component.component_id, failures)
        holder.queue_free()
        await process_frame

    await _verify_projectile_fallback(failures)
    await _verify_chain_lightning(failures)
    _verify_shadow_palette(failures)
    if failures.is_empty():
        print("PASS: all 49 Components expose neutral Core/Trigger/operation/status VFX with generic fallback")
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
            return TEST_UTILS.compile([&"core_arrow_shot", &"trajectory_return", component.component_id, &"core_ground_burst"])
        return TEST_UTILS.compile([&"core_slash", component.component_id, &"core_ground_burst"])
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


func _spawn_lifecycle_sample(holder: Node3D, definition: SkillDefinition) -> void:
    match definition.core_behavior:
        &"projectile", &"wave":
            COMBAT_VFX.spawn_core_projectile_trail(holder, definition, Vector3.ZERO, Vector3.FORWARD)
            COMBAT_VFX.spawn_core_end(holder, definition, Vector3.FORWARD, Vector3.FORWARD)
        &"channel":
            COMBAT_VFX.spawn_channel_end(holder, definition, Vector3.ZERO, Vector3.FORWARD * 3.0)
        &"persistent":
            COMBAT_VFX.spawn_persistent_field(holder, definition, Vector3.ZERO, definition.area_radius, 0.25)
        &"summon":
            COMBAT_VFX.spawn_minion_dissolve(holder, Vector3.ZERO)
        &"dash":
            COMBAT_VFX.spawn_dash_sequence(holder, Vector3.ZERO, Vector3.FORWARD * definition.target_range, 0.0)
        _:
            COMBAT_VFX.spawn_core_end(holder, definition, Vector3.FORWARD, Vector3.FORWARD)


func _verify_projectile_fallback(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var manager := ProjectileManager.new()
    holder.add_child(manager)
    await process_frame
    for core_id: StringName in [&"core_arrow_shot", &"core_frost_lance", &"core_flame_orb", &"core_shockwave"]:
        var result := TEST_UTILS.compile([core_id])
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
            failures.append("%s had no shadow flight visual" % core_id)
        COMBAT_VFX.spawn_core_projectile_trail(
            holder,
            result.build.get_root_core(),
            Vector3.ZERO,
            Vector3.FORWARD
        )
        await physics_frame
    if _count_group_descendants(holder, &"vfx_projectile_trail") == 0:
        failures.append("Projectile and wave Cores produced no lifecycle trails")
    _verify_neutral_tree(holder, &"projectile_flight", failures)
    manager.clear_active()
    holder.queue_free()
    await process_frame


func _verify_shadow_palette(failures: PackedStringArray) -> void:
    for color: Color in [SHADOW_STYLE.BODY, SHADOW_STYLE.SHADOW, SHADOW_STYLE.ASH, SHADOW_STYLE.RIM, SHADOW_STYLE.FLASH]:
        if not SHADOW_STYLE.is_neutral(color):
            failures.append("ShadowVfxStyle contains a non-neutral swatch")
    if SHADOW_STYLE.RIM.get_luminance() - SHADOW_STYLE.BODY.get_luminance() < 0.5:
        failures.append("Shadow body and gray-white rim lack measurable luminance contrast")
    for component: SkillComponent in SkillCatalog.get_components_by_category(&"Core"):
        var definition := TEST_UTILS.compile([component.component_id]).build.get_root_core()
        if not SHADOW_STYLE.is_neutral(definition.color):
            failures.append("Core %s retains a chromatic VFX color" % component.component_id)


func _verify_neutral_tree(node: Node, label: StringName, failures: PackedStringArray) -> void:
    if node is GeometryInstance3D:
        var material := (node as GeometryInstance3D).material_override
        if material is StandardMaterial3D:
            var standard := material as StandardMaterial3D
            _expect_neutral_color(standard.albedo_color, label, "albedo", failures)
            if standard.emission_enabled:
                _expect_neutral_color(standard.emission, label, "emission", failures)
        elif material is ShaderMaterial:
            var shader_material := material as ShaderMaterial
            for parameter: StringName in [&"body_color", &"ash_color", &"rim_color"]:
                var value: Variant = shader_material.get_shader_parameter(parameter)
                if value is Color:
                    _expect_neutral_color(value as Color, label, String(parameter), failures)
    if node is SpriteBase3D:
        _expect_neutral_color((node as SpriteBase3D).modulate, label, "sprite modulate", failures)
    if node is Light3D:
        _expect_neutral_color((node as Light3D).light_color, label, "light", failures)
    for child: Node in node.get_children():
        _verify_neutral_tree(child, label, failures)


func _expect_neutral_color(
        color: Color,
        label: StringName,
        channel: String,
        failures: PackedStringArray
) -> void:
    if not SHADOW_STYLE.is_neutral(color):
        failures.append("%s uses chromatic %s color %s" % [label, channel, color])


func _verify_chain_lightning(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var from_position := Vector3(0.0, 1.1, 0.0)
    var to_position := Vector3(5.0, 1.0, -1.0)
    COMBAT_VFX.spawn_chain_lightning(holder, from_position, to_position, Color("8fdcff"), 17)
    var chain_root: Node3D
    for candidate: Node in _group_descendants(holder, &"vfx_chain_lightning"):
        if candidate.has_meta("segment_count"):
            chain_root = candidate as Node3D
            break
    if chain_root == null:
        failures.append("Shared Chain operation created no lightning VFX")
    elif int(chain_root.get_meta("segment_count")) < 7 or int(chain_root.get_meta("segment_count")) > 9:
        failures.append("Shared Chain lightning did not use 7-9 segments")
    await process_frame
    for _frame: int in 36:
        await physics_frame
    if _count_group_descendants(holder, &"vfx_chain_lightning") > 0:
        failures.append("Chain VFX remained after its lifetime")
    holder.queue_free()
    await process_frame


func _count_group_descendants(parent: Node, group: StringName) -> int:
    return _group_descendants(parent, group).size()


func _group_descendants(parent: Node, group: StringName) -> Array[Node]:
    var matches: Array[Node] = []
    for child: Node in parent.get_children():
        if child.is_in_group(group):
            matches.append(child)
        matches.append_array(_group_descendants(child, group))
    return matches
