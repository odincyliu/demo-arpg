extends SceneTree

const CONCEPT_LIBRARY := preload("res://scripts/concept_library.gd")


func _init() -> void:
    call_deferred("_run_tests")


func _run_tests() -> void:
    var failures: PackedStringArray = []
    _test_default_branch_graph(failures)
    _test_thunder_chain_definition(failures)
    _test_catalog_schema_and_hosts(failures)
    _test_skill_concept_matrix(failures)
    _test_compatibility_rules(failures)
    _test_topologies(failures)
    _test_all_canonical_topologies(failures)
    _test_ui_candidate_contract(failures)
    _test_seeded_legal_graphs(failures)
    _test_schema_failures(failures)

    if failures.is_empty():
        print("PASS: six-node DAG compiler, catalog, adapters, and 10,000 seeded legal graphs")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _test_default_branch_graph(failures: PackedStringArray) -> void:
    var graph := CONCEPT_LIBRARY.get_default_graph()
    if graph.nodes.size() != SkillGraph.MAX_NODES:
        failures.append("Expected exactly six graph nodes")
        return
    if not graph.is_valid():
        failures.append("Default graph is invalid: %s" % " / ".join(graph.validation_errors))
        return
    if graph.get_primary_skill_node_id() != 0:
        failures.append("Fireball must be the implicit manual root")
    var fireball := graph.get_compiled_skill(0)
    var ice_nova := graph.get_compiled_skill(3)
    var summon_core := graph.get_compiled_skill(5)
    if fireball == null or fireball.split_count != 2:
        failures.append("Default Fireball must apply hit split")
    if ice_nova == null or ice_nova.active_skill_id != &"ice_nova":
        failures.append("Critical branch must compile Ice Nova")
    elif ice_nova.emitter_type != &"context" or not is_equal_approx(ice_nova.area_radius, 5.2):
        failures.append("Ice Nova must compile as a contextual fixed 5.2m nova")
    if summon_core == null or summon_core.active_skill_id != &"summon_core":
        failures.append("Kill branch must compile Summon Core")
    if CONCEPT_LIBRARY.get_trigger_type(graph.get_graph_node(2).concept_id) != &"critical":
        failures.append("Node 3 must be the critical branch")
    if CONCEPT_LIBRARY.get_trigger_type(graph.get_graph_node(4).concept_id) != &"kill":
        failures.append("Node 5 must be the kill branch")


func _test_thunder_chain_definition(failures: PackedStringArray) -> void:
    var result := CONCEPT_LIBRARY.compile_graph(_graph_with_supports(&"skill_thunder_orb", []))
    if not result.valid:
        failures.append("Base Thunder Orb failed to compile: %s" % " / ".join(result.errors))
        return
    var definition := result.graph.get_primary_skill()
    if definition.action_type != &"damage" or definition.shape_type != &"tracking":
        failures.append("Base Thunder Orb must be direct Tracking damage")
    if definition.emitter_type != &"player" or definition.has_tag(&"projectile"):
        failures.append("Base Thunder Orb must originate from the player without projectile capability")
    if definition.chain_count != 2 or not is_equal_approx(definition.chain_range, 4.8):
        failures.append("Base Thunder Orb must chain twice within 4.8m")
    if not is_equal_approx(definition.target_range, 12.0) or not is_equal_approx(definition.target_snap_radius, 3.0):
        failures.append("Base Thunder Orb must use 12m range and 3m cursor snapping")

    var chained := _expect_compile(
        failures,
        _graph_with_supports(&"skill_thunder_orb", [&"modifier_chain"]),
        true,
        "Thunder Orb Chain upgrade"
    )
    if chained != null and chained.valid and chained.graph.get_primary_skill().chain_count != 4:
        failures.append("Chain Modifier must extend Thunder Orb to four jumps")
    _expect_compile(
        failures,
        _graph_with_supports(&"skill_thunder_orb", [&"modifier_split"]),
        false,
        "Direct Thunder Orb split"
    )
    for modifier_id: StringName in [
        &"modifier_split",
        &"modifier_pierce",
        &"modifier_bounce",
        &"modifier_accelerate",
        &"modifier_rapid_fire",
    ]:
        var projectile_result := _expect_compile(
            failures,
            _graph_with_supports(&"skill_thunder_orb", [&"action_projectile", modifier_id]),
            true,
            "Projectile Thunder Orb %s" % modifier_id
        )
        if projectile_result != null and projectile_result.valid:
            var projectile_definition := projectile_result.graph.get_primary_skill()
            if projectile_definition.action_type != &"projectile" or not projectile_definition.has_tag(&"projectile"):
                failures.append("Projectile Action did not restore Thunder Orb projectile capability")


func _test_catalog_schema_and_hosts(failures: PackedStringArray) -> void:
    var seen_ids: Dictionary = {}
    for raw_concept: Variant in CONCEPT_LIBRARY.get_catalog().values():
        var concept := raw_concept as SkillConcept
        if seen_ids.has(concept.concept_id):
            failures.append("Duplicate Concept id: %s" % concept.concept_id)
        seen_ids[concept.concept_id] = true
        if concept.runtime_operation_id == &"":
            failures.append("Concept %s has no runtime operation" % concept.concept_id)
        var host_graph := _host_graph_for(concept)
        var result := CONCEPT_LIBRARY.compile_graph(host_graph)
        if not result.valid:
            failures.append("Concept %s has no valid representative host: %s" % [
                concept.concept_id,
                " / ".join(result.errors),
            ])


func _test_compatibility_rules(failures: PackedStringArray) -> void:
    _expect_compile(failures, _graph_with_supports(&"skill_ice_nova", [&"shape_circle"]), false, "Ice Nova duplicate Circle")
    _expect_compile(failures, _graph_with_supports(&"skill_ice_nova", [&"emitter_player"]), true, "Ice Nova player override")
    _expect_compile(failures, _graph_with_supports(&"skill_ice_nova", [&"emitter_impact"]), true, "Ice Nova impact override")
    _expect_compile(failures, _graph_with_supports(&"skill_ice_nova", [&"modifier_split"]), false, "Direct Ice Nova split")
    var projectile_nova := _graph_with_supports(&"skill_ice_nova", [&"action_projectile", &"modifier_split"])
    var projectile_result := _expect_compile(failures, projectile_nova, true, "Projectile Ice Nova split")
    if projectile_result != null and projectile_result.valid:
        var nova := projectile_result.graph.get_primary_skill()
        if not nova.radial or nova.projectile_count != 10:
            failures.append("Projectile-converted Ice Nova did not use the Circle adapter")
    _expect_compile(failures, _graph_with_supports(&"skill_fireball", [&"shape_circle", &"shape_cone"]), false, "Two Patterns")
    _expect_compile(failures, _graph_with_supports(&"skill_fireball", [&"modifier_split", &"action_damage"]), false, "Action invalidates split")
    _expect_compile(failures, _graph_with_supports(&"skill_heavy_slash", [&"modifier_combo", &"modifier_splash"]), true, "Melee combo splash")
    _expect_compile(failures, _graph_with_supports(&"skill_heavy_slash", [&"modifier_rapid_fire"]), false, "Melee rapid fire")
    var projectile_slash := _graph_with_supports(
        &"skill_heavy_slash",
        [&"action_projectile", &"modifier_rapid_fire", &"modifier_split"]
    )
    var slash_result := _expect_compile(failures, projectile_slash, true, "Projectile slash rapid split")
    if slash_result != null and slash_result.valid:
        var slash := slash_result.graph.get_primary_skill()
        if slash.element != &"physical" or slash.projectile_count != 5:
            failures.append("Projectile Heavy Slash must retain physical element and Cone adapter")
    _expect_compile(failures, _graph_with_supports(&"skill_summon_core", [&"shape_rotate"]), false, "Summon Rotate adapter")

    var effects_result := CONCEPT_LIBRARY.compile_graph(_graph_with_supports(
        &"skill_heavy_slash",
        [&"effect_poison", &"effect_explosion", &"modifier_splash"]
    ))
    if not effects_result.valid:
        failures.append("Physical effects graph failed: %s" % " / ".join(effects_result.errors))
    else:
        var definition := effects_result.graph.get_primary_skill()
        if definition.element != &"physical":
            failures.append("Effects must not overwrite the base physical element")
        if not definition.has_effect(&"poison") or not definition.has_effect(&"explosion"):
            failures.append("Multiple Effects did not remain active")

    var duplicate := _graph_with_supports(&"skill_fireball", [&"modifier_split", &"modifier_split"])
    _expect_compile(failures, duplicate, false, "Duplicate Concept")


func _test_skill_concept_matrix(failures: PackedStringArray) -> void:
    var supports: Array[SkillConcept] = []
    for kind: StringName in [&"Emitter", &"Action", &"Pattern", &"Modifier", &"Effect"]:
        supports.append_array(CONCEPT_LIBRARY.get_concepts_by_kind(kind))
    for skill: SkillConcept in CONCEPT_LIBRARY.get_concepts_by_kind(&"Skill"):
        for first_index: int in supports.size():
            var single_result := CONCEPT_LIBRARY.compile_graph(
                _graph_with_supports(skill.concept_id, [supports[first_index].concept_id])
            )
            _expect_complete_or_rejected(
                failures,
                single_result,
                "%s x %s" % [skill.concept_id, supports[first_index].concept_id]
            )
            for second_index: int in range(first_index + 1, supports.size()):
                var pair_result := CONCEPT_LIBRARY.compile_graph(_graph_with_supports(
                    skill.concept_id,
                    [supports[first_index].concept_id, supports[second_index].concept_id]
                ))
                _expect_complete_or_rejected(
                    failures,
                    pair_result,
                    "%s x %s + %s" % [
                        skill.concept_id,
                        supports[first_index].concept_id,
                        supports[second_index].concept_id,
                    ]
                )


func _expect_complete_or_rejected(
        failures: PackedStringArray,
        result: SkillCompileResult,
        label: String
) -> void:
    if result.valid:
        var nonempty_count := 0
        for node: SkillGraphNode in result.graph.nodes:
            if not node.is_empty():
                nonempty_count += 1
        if result.applied_node_ids.size() != nonempty_count or not result.warnings.is_empty():
            failures.append("Compatible pair was partially applied: %s" % label)
    elif result.errors.is_empty():
        failures.append("Rejected pair had no concrete reason: %s" % label)


func _test_topologies(failures: PackedStringArray) -> void:
    var topologies: Array[SkillGraph] = []
    topologies.append(_graph_with_supports(
        &"skill_fireball",
        [&"emitter_mouse", &"shape_cone", &"modifier_split", &"effect_poison", &"effect_lifesteal"]
    ))
    var two_branches := SkillGraph.new()
    _put_node(two_branches, 0, &"skill_fireball", SkillGraph.ROOT_PARENT)
    _put_node(two_branches, 1, &"trigger_hit", 0, TriggerConfig.new())
    _put_node(two_branches, 2, &"skill_thunder_orb", 1)
    _put_node(two_branches, 3, &"trigger_critical", 0, TriggerConfig.new())
    _put_node(two_branches, 4, &"skill_ice_nova", 3)
    _put_node(two_branches, 5, &"modifier_chain", 2)
    topologies.append(two_branches)
    var player_branch := SkillGraph.new()
    _put_node(player_branch, 0, &"skill_heavy_slash", SkillGraph.ROOT_PARENT)
    _put_node(player_branch, 1, &"modifier_combo", 0)
    _put_node(player_branch, 2, &"trigger_dash", SkillGraph.PLAYER_EVENT_PARENT, TriggerConfig.new())
    _put_node(player_branch, 3, &"skill_blade_wave", 2)
    _put_node(player_branch, 4, &"modifier_split", 3)
    _put_node(player_branch, 5, &"effect_ice", 3)
    topologies.append(player_branch)
    for topology_index: int in topologies.size():
        _expect_compile(failures, topologies[topology_index], true, "Legal topology %d" % topology_index)


func _test_all_canonical_topologies(failures: PackedStringArray) -> void:
    var entries: Array[Dictionary] = [{"kind": &"Skill", "parent": SkillGraph.ROOT_PARENT}]
    var stats := {"count": 0}
    _enumerate_topologies(entries, failures, stats)
    if int(stats["count"]) < 1:
        failures.append("Canonical six-node topology enumeration produced no legal graphs")
    else:
        print("INFO: enumerated %d canonical six-node topologies" % int(stats["count"]))


func _enumerate_topologies(
        entries: Array[Dictionary],
        failures: PackedStringArray,
        stats: Dictionary
) -> void:
    if not failures.is_empty():
        return
    if entries.size() == SkillGraph.MAX_NODES:
        if not _topology_triggers_have_children(entries):
            return
        var result := CONCEPT_LIBRARY.compile_graph(_graph_from_topology(entries))
        if not result.valid or result.applied_node_ids.size() != SkillGraph.MAX_NODES:
            failures.append("Canonical topology failed: %s | %s" % [entries, " / ".join(result.errors)])
            return
        stats["count"] = int(stats["count"]) + 1
        return
    for parent_id: int in entries.size():
        var parent_kind := StringName(entries[parent_id]["kind"])
        if parent_kind == &"Skill":
            var support_entries := entries.duplicate(true)
            support_entries.append({"kind": &"Support", "parent": parent_id})
            _enumerate_topologies(support_entries, failures, stats)
            var trigger_entries := entries.duplicate(true)
            trigger_entries.append({"kind": &"Trigger", "parent": parent_id})
            _enumerate_topologies(trigger_entries, failures, stats)
        elif parent_kind in [&"Trigger", &"ExternalTrigger"]:
            var skill_entries := entries.duplicate(true)
            skill_entries.append({"kind": &"Skill", "parent": parent_id})
            _enumerate_topologies(skill_entries, failures, stats)
    var external_entries := entries.duplicate(true)
    external_entries.append({"kind": &"ExternalTrigger", "parent": SkillGraph.PLAYER_EVENT_PARENT})
    _enumerate_topologies(external_entries, failures, stats)


func _topology_triggers_have_children(entries: Array[Dictionary]) -> bool:
    for node_id: int in entries.size():
        var kind := StringName(entries[node_id]["kind"])
        if kind not in [&"Trigger", &"ExternalTrigger"]:
            continue
        var has_skill_child := false
        for child_id: int in entries.size():
            if int(entries[child_id]["parent"]) == node_id and StringName(entries[child_id]["kind"]) == &"Skill":
                has_skill_child = true
        if not has_skill_child:
            return false
    return true


func _graph_from_topology(entries: Array[Dictionary]) -> SkillGraph:
    var graph := SkillGraph.new()
    var support_counts: Dictionary = {}
    var support_ids: Array[StringName] = [
        &"emitter_mouse", &"shape_cone", &"modifier_splash", &"effect_poison", &"effect_lifesteal",
    ]
    for node_id: int in entries.size():
        var entry := entries[node_id]
        var kind := StringName(entry["kind"])
        var parent_id := int(entry["parent"])
        var concept_id: StringName
        var config: TriggerConfig
        match kind:
            &"Skill":
                concept_id = &"skill_fireball" if parent_id == SkillGraph.ROOT_PARENT else &"skill_ice_nova"
            &"Trigger":
                concept_id = &"trigger_hit"
                config = TriggerConfig.new()
            &"ExternalTrigger":
                concept_id = &"trigger_dash"
                config = TriggerConfig.new()
            &"Support":
                var support_index := int(support_counts.get(parent_id, 0))
                concept_id = support_ids[support_index]
                support_counts[parent_id] = support_index + 1
        _put_node(graph, node_id, concept_id, parent_id, config)
    return graph


func _test_ui_candidate_contract(failures: PackedStringArray) -> void:
    var graph := CONCEPT_LIBRARY.get_default_graph()
    var offered_count := 0
    for node_id: int in SkillGraph.MAX_NODES:
        for kind: StringName in CONCEPT_LIBRARY.KIND_ORDER:
            for concept: SkillConcept in CONCEPT_LIBRARY.get_concepts_by_kind(kind):
                for parent: Dictionary in CONCEPT_LIBRARY.get_parent_candidates(graph, node_id, concept.concept_id):
                    var state := CONCEPT_LIBRARY.get_candidate_state(
                        graph,
                        node_id,
                        concept.concept_id,
                        int(parent["id"]),
                        graph.get_graph_node(node_id).trigger_config
                    )
                    if state.valid:
                        offered_count += 1
                        if state.result == null or not state.result.valid:
                            failures.append("UI offered %s but compile failed" % concept.concept_id)
    if offered_count == 0:
        failures.append("UI compatibility contract offered no candidates")


func _test_seeded_legal_graphs(failures: PackedStringArray) -> void:
    seed(20260812)
    var graph := CONCEPT_LIBRARY.get_default_graph()
    var catalog_values: Array = CONCEPT_LIBRARY.get_catalog().values()
    for iteration: int in 10000:
        var node_id := randi_range(0, SkillGraph.MAX_NODES - 1)
        var concept := catalog_values[randi_range(0, catalog_values.size() - 1)] as SkillConcept
        var parents := CONCEPT_LIBRARY.get_parent_candidates(graph, node_id, concept.concept_id)
        if not parents.is_empty():
            var parent := parents[randi_range(0, parents.size() - 1)] as Dictionary
            var state := CONCEPT_LIBRARY.get_candidate_state(
                graph,
                node_id,
                concept.concept_id,
                int(parent["id"]),
                TriggerConfig.new()
            )
            if state.valid:
                graph = state.result.graph
        var result := CONCEPT_LIBRARY.compile_graph(graph)
        if not result.valid:
            failures.append("Seeded graph %d became invalid: %s" % [iteration, " / ".join(result.errors)])
            return
        var nonempty_count := 0
        for node: SkillGraphNode in result.graph.nodes:
            if not node.is_empty():
                nonempty_count += 1
        if result.applied_node_ids.size() != nonempty_count:
            failures.append("Seeded graph %d did not apply every node exactly once" % iteration)
            return
        if not result.warnings.is_empty():
            failures.append("Seeded graph %d produced warnings" % iteration)
            return


func _test_schema_failures(failures: PackedStringArray) -> void:
    var bad_field := SkillConcept.new().configure(
        &"bad_field", "Bad", &"Effect", "", &"bad_field", ConceptLibrary.PHASE_EFFECT,
        {"stats": [{"field": &"unknown_damage", "op": &"ADD", "value": 1.0}]}
    )
    var definition := SkillDefinition.new()
    if definition.apply_concept(bad_field).is_empty():
        failures.append("Unknown stat fields must fail")
    var bad_operation := SkillConcept.new().configure(
        &"bad_op", "Bad", &"Effect", "", &"bad_op", ConceptLibrary.PHASE_EFFECT,
        {"stats": [{"field": &"damage", "op": &"DIVIDE", "value": 2.0}]}
    )
    if SkillDefinition.new().apply_concept(bad_operation).is_empty():
        failures.append("Unknown stat operations must fail")
    var bad_type := SkillConcept.new().configure(
        &"bad_type", "Bad", &"Effect", "", &"bad_type", ConceptLibrary.PHASE_EFFECT,
        {"stats": [{"field": &"damage", "op": &"SET", "value": "high"}]}
    )
    if SkillDefinition.new().apply_concept(bad_type).is_empty():
        failures.append("Wrong stat value types must fail")


func _host_graph_for(concept: SkillConcept) -> SkillGraph:
    if concept.concept_kind == &"Skill":
        var skill_graph := SkillGraph.new()
        _put_node(skill_graph, 0, concept.concept_id, SkillGraph.ROOT_PARENT)
        return skill_graph
    if concept.concept_kind == &"Trigger":
        var trigger_graph := SkillGraph.new()
        _put_node(trigger_graph, 0, &"skill_fireball", SkillGraph.ROOT_PARENT)
        var parent := SkillGraph.PLAYER_EVENT_PARENT if CONCEPT_LIBRARY.get_trigger_type(concept.concept_id) in [&"damaged", &"dash"] else 0
        _put_node(trigger_graph, 1, concept.concept_id, parent, TriggerConfig.new())
        _put_node(trigger_graph, 2, &"skill_ice_nova", 1)
        return trigger_graph
    var host_skill := &"skill_fireball"
    match concept.concept_id:
        &"action_projectile", &"shape_line":
            host_skill = &"skill_ice_nova"
        &"emitter_player":
            host_skill = &"skill_ice_nova"
        &"modifier_combo":
            host_skill = &"skill_heavy_slash"
        &"effect_fire", &"effect_poison", &"effect_ice", &"effect_lifesteal", &"effect_explosion":
            host_skill = &"skill_blade_wave"
    return _graph_with_supports(host_skill, [concept.concept_id])


func _graph_with_supports(skill_id: StringName, support_ids: Array[StringName]) -> SkillGraph:
    var graph := SkillGraph.new()
    _put_node(graph, 0, skill_id, SkillGraph.ROOT_PARENT)
    for support_index: int in mini(support_ids.size(), SkillGraph.MAX_NODES - 1):
        _put_node(graph, support_index + 1, support_ids[support_index], 0)
    return graph


func _put_node(
        graph: SkillGraph,
        node_id: int,
        concept_id: StringName,
        parent_node_id: int,
        config: TriggerConfig = null
) -> void:
    graph.set_node(SkillGraphNode.new().configure(node_id, concept_id, parent_node_id, config))


func _expect_compile(
        failures: PackedStringArray,
        graph: SkillGraph,
        expected_valid: bool,
        label: String
) -> SkillCompileResult:
    var result := CONCEPT_LIBRARY.compile_graph(graph)
    if result.valid != expected_valid:
        failures.append("%s expected valid=%s, got %s: %s" % [
            label,
            expected_valid,
            result.valid,
            " / ".join(result.errors),
        ])
    return result
