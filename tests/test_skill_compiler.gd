extends SceneTree


func _init() -> void:
    call_deferred("_run_tests")


func _run_tests() -> void:
    var failures: PackedStringArray = []
    _test_catalog(failures)
    _test_default_build(failures)
    _test_grammar(failures)
    _test_nearest_core_binding(failures)
    _test_fixed_pipeline_order(failures)
    _test_compatibility(failures)
    _test_preview_contract(failures)
    if failures.is_empty():
        print("PASS: modular six-link compiler, 55-component catalog, grammar, and previews")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _test_catalog(failures: PackedStringArray) -> void:
    var catalog := SkillCatalog.get_catalog()
    if catalog.size() != 55:
        failures.append("Expected 55 V1 Components, got %d" % catalog.size())
    var expected_counts := {
        &"Core": 20, &"Trigger": 10, &"Trajectory": 5, &"Shape": 4,
        &"Pattern": 5, &"Effect": 8, &"Transform": 3,
    }
    for category: StringName in expected_counts:
        var actual := SkillCatalog.get_components_by_category(category).size()
        if actual != int(expected_counts[category]):
            failures.append("%s count was %d" % [category, actual])
    for raw_component: Variant in catalog.values():
        var component := raw_component as SkillComponent
        var host := _representative_build(component)
        var result := SkillCompiler.compile_build(host)
        if not result.valid:
            failures.append("Component %s has no valid host: %s" % [component.component_id, "; ".join(result.errors)])


func _test_default_build(failures: PackedStringArray) -> void:
    var build := SkillCatalog.get_default_build()
    if build == null or not build.is_valid():
        failures.append("Default six-link build did not compile")
        return
    var ids: Array[StringName] = [
        &"core_frost_lance", &"pattern_multishot", &"pattern_hold",
        &"effect_freeze", &"trigger_freeze", &"core_shockwave",
    ]
    for index: int in ids.size():
        if build.get_slot(index).component_id != ids[index]:
            failures.append("Default slot %d was not %s" % [index + 1, ids[index]])
    if build.compiled.root_core.compiled_slot_index != 0 or build.compiled.triggered_core.compiled_slot_index != 5:
        failures.append("Default build did not bind both Cores")


func _test_grammar(failures: PackedStringArray) -> void:
    _expect(failures, _build([&"core_arrow_shot"]), true, "single Core")
    _expect(failures, _build([&"core_arrow_shot", &"trajectory_pierce", &"trigger_hit", &"core_explosion", &"transform_expanded"]), true, "trigger chain")
    _expect(failures, _build([&"core_arrow_shot", &"core_explosion"]), false, "Core-Core")
    _expect(failures, _build([&"core_arrow_shot", &"trigger_hit"]), false, "missing Trigger target")
    _expect(failures, _build([&"core_arrow_shot", &"trigger_hit", &"transform_giant", &"core_explosion"]), false, "Component between Trigger and Core")
    _expect(failures, _build([&"core_arrow_shot", &"trigger_hit", &"core_explosion", &"trigger_kill", &"core_ground_burst"]), false, "second Trigger")
    _expect(failures, _build([&"core_arrow_shot", &"shape_cone", &"shape_line"]), false, "multiple Shape")
    _expect(failures, _build([&"core_arrow_shot", &"trajectory_pierce", &"trajectory_pierce"]), false, "duplicate Component")
    var gap := _build([&"core_arrow_shot"])
    gap.set_slot(SkillSlot.new().configure(2, &"trajectory_pierce"))
    _expect(failures, gap, false, "gap")


func _test_nearest_core_binding(failures: PackedStringArray) -> void:
    var result := SkillCompiler.compile_build(_build([
        &"core_arrow_shot", &"transform_expanded", &"trigger_hit",
        &"core_explosion", &"effect_stun", &"transform_giant",
    ]))
    if not result.valid:
        failures.append("Nearest-Core build failed: %s" % "; ".join(result.errors))
        return
    if not result.compiled_build.root_core.has_component(&"transform_expanded"):
        failures.append("Expanded was not bound to the root Core")
    if result.compiled_build.root_core.has_component(&"effect_stun"):
        failures.append("Triggered-Core Effect leaked to root Core")
    if not result.compiled_build.triggered_core.has_component(&"effect_stun") or not result.compiled_build.triggered_core.has_component(&"transform_giant"):
        failures.append("Components after the second Core were not bound to it")


func _test_fixed_pipeline_order(failures: PackedStringArray) -> void:
    var result := SkillCompiler.compile_build(_build([
        &"core_arrow_shot", &"transform_giant", &"trajectory_pierce",
        &"pattern_multishot", &"effect_bleed", &"shape_line",
    ]))
    if not result.valid:
        failures.append("Pipeline order build failed: %s" % "; ".join(result.errors))
        return
    var actual: Array[StringName] = []
    for component: SkillComponent in result.compiled_build.root_core.components:
        actual.append(component.component_id)
    var expected: Array[StringName] = [
        &"core_arrow_shot", &"pattern_multishot", &"shape_line",
        &"transform_giant", &"trajectory_pierce", &"effect_bleed",
    ]
    if actual != expected:
        failures.append("Components did not compile by fixed Pipeline category and Slot order: %s" % actual)


func _test_compatibility(failures: PackedStringArray) -> void:
    _expect(failures, _build([&"core_slash", &"trajectory_pierce"]), false, "Pierce melee")
    _expect(failures, _build([&"core_flame_orb", &"effect_freeze"]), false, "Freeze fire")
    _expect(failures, _build([&"core_arrow_shot", &"trigger_return", &"core_explosion"]), false, "On Return without Return")
    _expect(failures, _build([&"core_arrow_shot", &"trajectory_return", &"trigger_return", &"core_explosion"]), true, "On Return with Return")
    _expect(failures, _build([&"core_void_beam", &"trigger_channel", &"core_meteor"]), true, "Channel Trigger")


func _test_preview_contract(failures: PackedStringArray) -> void:
    var build := SkillCatalog.get_default_build()
    var preview := SkillCompiler.preview_edit(build, {"slot_index": 0, "component_id": &""})
    if preview.valid or preview.build.validation_errors.is_empty():
        failures.append("Clearing Slot 1 should create an invalid draft")
    if not build.is_valid():
        failures.append("Preview edit mutated the source build")
    var state := SkillCompiler.get_candidate_state(build, 1, &"trajectory_pierce")
    if not state.valid:
        failures.append("Compatible candidate was rejected: %s" % state.reason)


func _representative_build(component: SkillComponent) -> SixLinkBuild:
    if component.is_core():
        return _build([component.component_id])
    if component.is_trigger():
        match component.component_id:
            &"trigger_channel":
                return _build([&"core_void_beam", component.component_id, &"core_meteor"])
            &"trigger_return":
                return _build([&"core_returning_blade", &"trajectory_return", component.component_id, &"core_explosion"])
            _:
                return _build([&"core_rapid_slash", component.component_id, &"core_explosion"])
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
        &"effect_bleed", &"effect_poison":
            host = &"core_arrow_shot"
        &"pattern_hold", &"pattern_remnant", &"shape_orbit":
            host = &"core_flame_orb"
    return _build([host, component.component_id])


func _build(component_ids: Array[StringName]) -> SixLinkBuild:
    var build := SixLinkBuild.new()
    for index: int in mini(component_ids.size(), SixLinkBuild.MAX_SLOTS):
        var config := TriggerConfig.new() if SkillCatalog.get_component(component_ids[index]).is_trigger() else null
        build.set_slot(SkillSlot.new().configure(index, component_ids[index], config))
    return build


func _expect(failures: PackedStringArray, build: SixLinkBuild, expected: bool, label: String) -> SkillCompileResult:
    var result := SkillCompiler.compile_build(build)
    if result.valid != expected:
        failures.append("%s expected valid=%s, got %s" % [label, expected, "; ".join(result.errors)])
    return result
