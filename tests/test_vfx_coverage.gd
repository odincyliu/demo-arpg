extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const CONCEPT_LIBRARY := preload("res://scripts/concept_library.gd")
const SKILL_VFX_ASSETS := preload("res://scripts/skill_vfx_assets.gd")


func _init() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var failures: PackedStringArray = []
    _verify_projectile_art(failures)
    _verify_projectile_identity_survives_density_limit(failures)
    await _verify_chain_lightning_vfx(failures)
    for raw_concept: Variant in CONCEPT_LIBRARY.get_catalog().values():
        var concept := raw_concept as SkillConcept
        var graph := _host_graph_for(concept)
        var result := CONCEPT_LIBRARY.compile_graph(graph)
        if not result.valid:
            failures.append("Concept %s has no VFX host: %s" % [concept.concept_id, " / ".join(result.errors)])
            continue
        var definition := result.graph.get_compiled_skill(2) if concept.concept_kind == &"Trigger" else result.graph.get_primary_skill()
        if definition == null:
            failures.append("Concept %s has no compiled skill for VFX" % concept.concept_id)
            continue
        var holder := Node3D.new()
        root.add_child(holder)
        COMBAT_VFX.spawn_cast_layers(holder, definition, Vector3.ZERO, Vector3.FORWARD)
        var expected_group := _expected_vfx_group(concept.concept_kind)
        if expected_group != &"" and get_nodes_in_group(expected_group).is_empty():
            failures.append("Concept %s has no cast VFX in %s" % [concept.concept_id, expected_group])
        if concept.concept_kind == &"Skill" and get_nodes_in_group("vfx_skill_identity").is_empty():
            failures.append("Skill %s has no CC0-backed identity VFX" % concept.concept_id)
        if concept.concept_kind in [&"Modifier", &"Effect"]:
            COMBAT_VFX.spawn_hit_layers(
                holder,
                definition,
                Vector3(0.0, 1.0, -2.0),
                Vector3(0.0, 1.0, 2.0),
                Vector3.FORWARD
            )
            if get_nodes_in_group(expected_group).is_empty():
                failures.append("Concept %s has no hit VFX in %s" % [concept.concept_id, expected_group])
        holder.queue_free()
        await process_frame

    if failures.is_empty():
        print("PASS: every graph Concept has matching cast and hit VFX")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _verify_projectile_art(failures: PackedStringArray) -> void:
    for skill_id: StringName in [&"fireball", &"thunder_orb", &"blade_wave", &"summon_core"]:
        var frames := SKILL_VFX_ASSETS.get_projectile_frames(skill_id)
        if frames == null or frames.get_frame_count(&"default") <= 0:
            failures.append("Projectile skill %s has no animated CC0 art" % skill_id)
    for skill_id: StringName in [&"ice_nova", &"thunder_orb", &"blade_wave", &"heavy_slash"]:
        var frames := SKILL_VFX_ASSETS.get_cast_frames(skill_id)
        if frames == null or frames.get_frame_count(&"default") <= 0:
            failures.append("Cast skill %s has no animated CC0 art" % skill_id)


func _verify_projectile_identity_survives_density_limit(failures: PackedStringArray) -> void:
    var graph := SkillGraph.new()
    _put_node(graph, 0, &"skill_blade_wave", SkillGraph.ROOT_PARENT)
    var result := CONCEPT_LIBRARY.compile_graph(graph)
    if not result.valid:
        failures.append("Blade Wave VFX density graph failed: %s" % " / ".join(result.errors))
        return
    var definition := result.graph.get_primary_skill()
    var holder := Node3D.new()
    root.add_child(holder)
    var manager := ProjectileManager.new()
    holder.add_child(manager)
    for index: int in 10:
        manager.request_projectile(
            holder,
            definition,
            holder,
            Vector3.ZERO,
            Vector3.FORWARD.rotated(Vector3.UP, float(index) * 0.05),
            {},
            true
        )
    var missing_identity_count := 0
    var active_projectiles := manager.get("_active") as Dictionary
    for raw_projectile: Variant in active_projectiles.values():
        var projectile := raw_projectile as SkillProjectile
        var skill_sprite := projectile.get("_skill_sprite") as AnimatedSprite3D
        if skill_sprite == null or not skill_sprite.visible or skill_sprite.sprite_frames == null:
            missing_identity_count += 1
    if active_projectiles.size() != 10 or missing_identity_count > 0:
        failures.append(
            "Blade Wave identity VFX missing on %d of %d projectiles after rich VFX cap" % [
                missing_identity_count,
                active_projectiles.size(),
            ]
        )
    manager.clear_active()
    holder.queue_free()


func _verify_chain_lightning_vfx(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var from_position := Vector3(0.0, 1.1, 0.0)
    var to_position := Vector3(5.0, 1.0, -1.0)
    COMBAT_VFX.spawn_chain_lightning(
        holder,
        from_position,
        to_position,
        Color("8fdcff"),
        17
    )
    await process_frame
    var chain_root: Node3D
    for candidate: Node in get_nodes_in_group("vfx_chain_lightning"):
        if candidate.has_meta("segment_count"):
            chain_root = candidate as Node3D
            break
    if chain_root == null:
        failures.append("Chain Lightning created no inspectable VFX root")
    else:
        var segment_count := int(chain_root.get_meta("segment_count"))
        if segment_count < 7 or segment_count > 9:
            failures.append("Chain Lightning did not use 7-9 jagged segments")
        if chain_root.get_child_count() != segment_count * 2:
            failures.append("Chain Lightning is missing its glow or white core layer")
        if (chain_root.get_meta("from_position") as Vector3) != from_position:
            failures.append("Chain Lightning did not preserve its source endpoint")
        if (chain_root.get_meta("to_position") as Vector3) != to_position:
            failures.append("Chain Lightning did not preserve its target endpoint")
    for _frame: int in 36:
        await physics_frame
    if not get_nodes_in_group("vfx_chain_lightning").is_empty():
        failures.append("Chain Lightning VFX remained after 0.5 seconds")
    holder.queue_free()
    await process_frame


func _host_graph_for(concept: SkillConcept) -> SkillGraph:
    var graph := SkillGraph.new()
    if concept.concept_kind == &"Skill":
        _put_node(graph, 0, concept.concept_id, SkillGraph.ROOT_PARENT)
        return graph
    if concept.concept_kind == &"Trigger":
        _put_node(graph, 0, &"skill_fireball", SkillGraph.ROOT_PARENT)
        var parent := SkillGraph.PLAYER_EVENT_PARENT if CONCEPT_LIBRARY.get_trigger_type(concept.concept_id) in [&"damaged", &"dash"] else 0
        _put_node(graph, 1, concept.concept_id, parent, TriggerConfig.new())
        _put_node(graph, 2, &"skill_ice_nova", 1)
        return graph
    var host := &"skill_fireball"
    match concept.concept_id:
        &"action_projectile", &"shape_line":
            host = &"skill_ice_nova"
        &"emitter_player":
            host = &"skill_ice_nova"
        &"modifier_combo":
            host = &"skill_heavy_slash"
        &"effect_fire", &"effect_poison", &"effect_ice", &"effect_lifesteal", &"effect_explosion":
            host = &"skill_blade_wave"
    _put_node(graph, 0, host, SkillGraph.ROOT_PARENT)
    _put_node(graph, 1, concept.concept_id, 0)
    return graph


func _put_node(
        graph: SkillGraph,
        node_id: int,
        concept_id: StringName,
        parent_node_id: int,
        config: TriggerConfig = null
) -> void:
    graph.set_node(SkillGraphNode.new().configure(node_id, concept_id, parent_node_id, config))


func _expected_vfx_group(kind: StringName) -> StringName:
    match kind:
        &"Trigger":
            return &"vfx_trigger"
        &"Skill", &"Action":
            return &"vfx_action"
        &"Emitter":
            return &"vfx_emitter"
        &"Pattern":
            return &"vfx_shape"
        &"Modifier":
            return &"vfx_modifier"
        &"Effect":
            return &"vfx_effect"
    return &""
