class_name ConceptLibrary
extends RefCounted

const PHASE_SKILL: int = 0
const PHASE_ACTION: int = 10
const PHASE_EMITTER: int = 20
const PHASE_PATTERN: int = 30
const PHASE_MODIFIER: int = 40
const PHASE_EFFECT: int = 50

const KIND_ORDER: Array[StringName] = [
    &"Skill", &"Trigger", &"Emitter", &"Action", &"Pattern", &"Modifier", &"Effect",
]
const KIND_LABELS: Dictionary = {
    &"Skill": "Skill｜技能",
    &"Trigger": "Trigger｜觸發",
    &"Emitter": "Emitter｜生成點",
    &"Action": "Action｜行為",
    &"Pattern": "Pattern｜模式",
    &"Modifier": "Modifier｜改造",
    &"Effect": "Effect｜效果",
}
const CAPABILITY_LABELS: Dictionary = {
    &"hit": "命中", &"projectile": "投射物", &"melee": "近戰",
    &"summon": "召喚", &"area": "範圍", &"spell": "法術", &"attack": "攻擊",
}
const TRIGGER_TYPES: Dictionary = {
    &"trigger_hit": &"hit",
    &"trigger_critical": &"critical",
    &"trigger_kill": &"kill",
    &"trigger_damaged": &"damaged",
    &"trigger_dash": &"dash",
}

static var _catalog_cache: Dictionary = {}


static func get_default_graph() -> SkillGraph:
    var graph := SkillGraph.new()
    graph.set_node(SkillGraphNode.new().configure(0, &"skill_fireball", SkillGraph.ROOT_PARENT))
    graph.set_node(SkillGraphNode.new().configure(1, &"modifier_split", 0))
    graph.set_node(SkillGraphNode.new().configure(2, &"trigger_critical", 0, TriggerConfig.new()))
    graph.set_node(SkillGraphNode.new().configure(3, &"skill_ice_nova", 2))
    graph.set_node(SkillGraphNode.new().configure(4, &"trigger_kill", 0, TriggerConfig.new()))
    graph.set_node(SkillGraphNode.new().configure(5, &"skill_summon_core", 4))
    return compile_graph(graph).graph


static func get_catalog() -> Dictionary:
    if _catalog_cache.is_empty():
        _catalog_cache = _build_catalog()
    return _catalog_cache


static func get_concept(concept_id: StringName) -> SkillConcept:
    return get_catalog().get(concept_id) as SkillConcept


static func get_concepts_by_kind(kind: StringName) -> Array[SkillConcept]:
    var concepts: Array[SkillConcept] = []
    for raw_concept: Variant in get_catalog().values():
        var concept := raw_concept as SkillConcept
        if concept != null and concept.concept_kind == kind:
            concepts.append(concept)
    concepts.sort_custom(func(left: SkillConcept, right: SkillConcept) -> bool:
        return String(left.concept_id) < String(right.concept_id)
    )
    return concepts


static func get_kind_label(kind: StringName) -> String:
    return String(KIND_LABELS.get(kind, kind))


static func get_trigger_type(concept_id: StringName) -> StringName:
    return StringName(TRIGGER_TYPES.get(concept_id, &""))


static func compile_graph(source_graph: SkillGraph) -> SkillCompileResult:
    var result := SkillCompileResult.new()
    result.graph = source_graph.copy_graph() if source_graph != null else SkillGraph.new()
    if source_graph == null:
        result.fail("技能圖不存在")
        return _publish_result(result)

    var catalog := get_catalog()
    var nonempty: Array[SkillGraphNode] = []
    var node_by_id: Dictionary = {}
    for node: SkillGraphNode in result.graph.nodes:
        if node.node_id < 0 or node.node_id >= SkillGraph.MAX_NODES:
            result.fail("節點編號超出 0–5：%d" % node.node_id)
            continue
        if node.is_empty():
            continue
        if not catalog.has(node.concept_id):
            result.fail("第 %d 格找不到 Concept：%s" % [node.node_id + 1, node.concept_id])
            continue
        nonempty.append(node)
        node_by_id[node.node_id] = node
        var concept := catalog[node.concept_id] as SkillConcept
        _validate_concept_schema(concept, result)

    var manual_roots: Array[SkillGraphNode] = []
    for node: SkillGraphNode in nonempty:
        var concept := catalog[node.concept_id] as SkillConcept
        if node.parent_node_id == SkillGraph.ROOT_PARENT:
            manual_roots.append(node)
            if concept.concept_kind != &"Skill":
                result.fail("第 %d 格：手動根節點必須是 Skill" % (node.node_id + 1))
        _validate_parent_rule(node, concept, node_by_id, catalog, result)
    if manual_roots.size() != 1:
        result.fail("技能圖必須恰好有一個手動主動技能根節點")

    for node: SkillGraphNode in nonempty:
        if not _is_reachable(node, node_by_id):
            result.fail("第 %d 格無法從手動根或玩家事件根抵達" % (node.node_id + 1))
        var concept := catalog[node.concept_id] as SkillConcept
        if concept.concept_kind == &"Trigger":
            var has_skill_child := false
            for child: SkillGraphNode in result.graph.get_children(node.node_id):
                var child_concept := catalog.get(child.concept_id) as SkillConcept
                if child_concept != null and child_concept.concept_kind == &"Skill":
                    has_skill_child = true
            if not has_skill_child:
                result.fail("第 %d 格 Trigger 後面至少需要一個 Skill" % (node.node_id + 1))

    if not result.errors.is_empty():
        return _publish_result(result)

    for node: SkillGraphNode in nonempty:
        var concept := catalog[node.concept_id] as SkillConcept
        if concept.concept_kind == &"Skill":
            _compile_skill_node(node, result.graph, catalog, result)
    for node: SkillGraphNode in nonempty:
        var concept := catalog[node.concept_id] as SkillConcept
        if concept.concept_kind == &"Trigger":
            result.applied_node_ids.append(node.node_id)
    result.applied_node_ids.sort()
    if result.applied_node_ids.size() != nonempty.size():
        result.fail("有非空節點未被編譯器套用")
    return _publish_result(result)


static func preview_edit(graph: SkillGraph, edit: Dictionary) -> NodeCompatibility:
    if graph == null:
        return NodeCompatibility.rejected("技能圖不存在")
    var node_id := int(edit.get("node_id", -1))
    if node_id < 0 or node_id >= SkillGraph.MAX_NODES:
        return NodeCompatibility.rejected("欄位不存在")
    var candidate := graph.copy_graph()
    var concept_id := StringName(edit.get("concept_id", &""))
    if concept_id == &"":
        candidate.clear_node(node_id)
        var clear_result := compile_graph(candidate)
        var clear_reason := "已清空"
        if not clear_result.valid:
            clear_reason += "；孤立節點需修正後才會更新戰鬥"
        return NodeCompatibility.accepted(clear_result, clear_reason)

    var parent_id := int(edit.get("parent_node_id", SkillGraph.ROOT_PARENT))
    var config: TriggerConfig = edit.get("trigger_config") as TriggerConfig
    candidate.set_node(SkillGraphNode.new().configure(node_id, concept_id, parent_id, config))
    var compile_result := compile_graph(candidate)
    if not compile_result.valid:
        return NodeCompatibility.rejected("\n".join(compile_result.errors), compile_result)
    var concept := get_concept(concept_id)
    return NodeCompatibility.accepted(compile_result, concept.summary if concept != null else "")


static func get_candidate_state(
        graph: SkillGraph,
        node_id: int,
        concept_id: StringName,
        parent_node_id: int,
        config: TriggerConfig = null
) -> NodeCompatibility:
    return preview_edit(graph, {
        "node_id": node_id,
        "concept_id": concept_id,
        "parent_node_id": parent_node_id,
        "trigger_config": config,
    })


static func get_parent_candidates(
        graph: SkillGraph,
        node_id: int,
        concept_id: StringName
) -> Array[Dictionary]:
    var parents: Array[Dictionary] = []
    var concept := get_concept(concept_id)
    if concept == null:
        return parents
    if concept.concept_kind == &"Skill" and _manual_root_id_excluding(graph, node_id) < 0:
        parents.append({"id": SkillGraph.ROOT_PARENT, "name": "手動施放根"})
    if concept.concept_kind == &"Trigger" and get_trigger_type(concept_id) in [&"damaged", &"dash"]:
        parents.append({"id": SkillGraph.PLAYER_EVENT_PARENT, "name": "玩家事件"})
    for candidate: SkillGraphNode in graph.nodes:
        if candidate.is_empty() or candidate.node_id == node_id:
            continue
        var parent_concept := get_concept(candidate.concept_id)
        if parent_concept == null:
            continue
        var allowed := false
        if concept.is_support():
            allowed = parent_concept.concept_kind == &"Skill"
        elif concept.concept_kind == &"Trigger":
            allowed = parent_concept.concept_kind == &"Skill" and get_trigger_type(concept_id) not in [&"damaged", &"dash"]
        elif concept.concept_kind == &"Skill":
            allowed = parent_concept.concept_kind == &"Trigger"
        if allowed:
            parents.append({
                "id": candidate.node_id,
                "name": "%d %s" % [candidate.node_id + 1, parent_concept.display_name],
            })
    return parents


static func describe_path(graph: SkillGraph, node_id: int) -> String:
    var parts: PackedStringArray = []
    var visited: Dictionary = {}
    var current := graph.get_graph_node(node_id)
    while current != null and not current.is_empty() and not visited.has(current.node_id):
        visited[current.node_id] = true
        var concept := get_concept(current.concept_id)
        parts.insert(0, concept.display_name if concept != null else String(current.concept_id))
        if current.parent_node_id < 0:
            if current.parent_node_id == SkillGraph.PLAYER_EVENT_PARENT:
                parts.insert(0, "玩家事件")
            break
        current = graph.get_graph_node(current.parent_node_id)
    return " → ".join(parts)


static func _compile_skill_node(
        skill_node: SkillGraphNode,
        graph: SkillGraph,
        catalog: Dictionary,
        result: SkillCompileResult
) -> void:
    var definition := SkillDefinition.new()
    definition.compiled_node_id = skill_node.node_id
    if skill_node.parent_node_id >= 0:
        var trigger_node := graph.get_graph_node(skill_node.parent_node_id)
        if trigger_node != null:
            definition.trigger_type = get_trigger_type(trigger_node.concept_id)
    var skill_concept := catalog[skill_node.concept_id] as SkillConcept
    var capabilities: Dictionary = {}
    _apply_capability_changes(capabilities, skill_concept)
    var error := definition.apply_concept(skill_concept)
    if not error.is_empty():
        result.fail("第 %d 格：%s" % [skill_node.node_id + 1, error])
        return

    var supports: Array[SkillGraphNode] = []
    for child: SkillGraphNode in graph.get_children(skill_node.node_id):
        var child_concept := catalog[child.concept_id] as SkillConcept
        if child_concept != null and child_concept.is_support():
            supports.append(child)
    supports.sort_custom(func(left: SkillGraphNode, right: SkillGraphNode) -> bool:
        var left_concept := catalog[left.concept_id] as SkillConcept
        var right_concept := catalog[right.concept_id] as SkillConcept
        if left_concept.compile_phase == right_concept.compile_phase:
            return left.node_id < right.node_id
        return left_concept.compile_phase < right_concept.compile_phase
    )

    var used_ids: Dictionary = {skill_node.concept_id: true}
    var exclusive_groups: Dictionary = {}
    for support_node: SkillGraphNode in supports:
        var concept := catalog[support_node.concept_id] as SkillConcept
        if used_ids.has(concept.concept_id):
            result.fail("第 %d 格：同一技能不能重複裝備「%s」" % [support_node.node_id + 1, concept.display_name])
            continue
        used_ids[concept.concept_id] = true
        if concept.exclusive_group != &"":
            if exclusive_groups.has(concept.exclusive_group):
                result.fail("第 %d 格：同一技能只能有一個 %s" % [support_node.node_id + 1, concept.exclusive_group])
                continue
            exclusive_groups[concept.exclusive_group] = support_node.node_id
        var compatibility_error := _capability_error(concept, capabilities)
        if not compatibility_error.is_empty():
            result.fail("第 %d 格「%s」：%s" % [support_node.node_id + 1, concept.display_name, compatibility_error])
            continue
        if concept.concept_kind == &"Action":
            var requested_action := StringName(concept.structural_changes.get("action_type", &""))
            if requested_action == definition.action_type:
                result.fail("第 %d 格：技能原本就是%s" % [support_node.node_id + 1, concept.display_name])
                continue
        if concept.concept_kind == &"Emitter":
            var requested_emitter := StringName(concept.structural_changes.get("emitter_type", &""))
            if requested_emitter == definition.emitter_type:
                result.fail("第 %d 格：技能原本就從%s生成" % [support_node.node_id + 1, concept.display_name])
                continue
        if concept.concept_kind == &"Pattern":
            var requested_pattern := StringName(concept.structural_changes.get("shape_type", &""))
            if requested_pattern == definition.shape_type:
                result.fail("第 %d 格：技能原本就是%s模式" % [support_node.node_id + 1, concept.display_name])
                continue
            var adapter_key := _adapter_key(definition.action_type, capabilities)
            if adapter_key not in concept.adapters:
                result.fail("第 %d 格「%s」沒有 %s Adapter" % [support_node.node_id + 1, concept.display_name, adapter_key])
                continue
        error = definition.apply_concept(concept)
        if not error.is_empty():
            result.fail("第 %d 格：%s" % [support_node.node_id + 1, error])
            continue
        _apply_capability_changes(capabilities, concept)
        result.applied_node_ids.append(support_node.node_id)

    if result.errors.is_empty():
        definition.set_capabilities(capabilities)
        definition.finalize()
        result.compiled_skills[skill_node.node_id] = definition
        result.applied_node_ids.append(skill_node.node_id)


static func _validate_parent_rule(
        node: SkillGraphNode,
        concept: SkillConcept,
        node_by_id: Dictionary,
        catalog: Dictionary,
        result: SkillCompileResult
) -> void:
    if node.parent_node_id == SkillGraph.ROOT_PARENT:
        return
    if node.parent_node_id == SkillGraph.PLAYER_EVENT_PARENT:
        if concept.concept_kind != &"Trigger" or get_trigger_type(concept.concept_id) not in [&"damaged", &"dash"]:
            result.fail("第 %d 格：只有受傷或 Dash Trigger 可接玩家事件根" % (node.node_id + 1))
        return
    if not node_by_id.has(node.parent_node_id):
        result.fail("第 %d 格的父節點不存在" % (node.node_id + 1))
        return
    var parent := node_by_id[node.parent_node_id] as SkillGraphNode
    var parent_concept := catalog[parent.concept_id] as SkillConcept
    if concept.is_support() and parent_concept.concept_kind != &"Skill":
        result.fail("第 %d 格：支援 Concept 的父節點必須是 Skill" % (node.node_id + 1))
    elif concept.concept_kind == &"Skill" and parent_concept.concept_kind != &"Trigger":
        result.fail("第 %d 格：後續 Skill 的父節點必須是 Trigger" % (node.node_id + 1))
    elif concept.concept_kind == &"Trigger":
        var trigger_type := get_trigger_type(concept.concept_id)
        if trigger_type in [&"damaged", &"dash"]:
            result.fail("第 %d 格：受傷或 Dash Trigger 必須接玩家事件根" % (node.node_id + 1))
        elif parent_concept.concept_kind != &"Skill":
            result.fail("第 %d 格：命中／暴擊／擊殺 Trigger 的父節點必須是 Skill" % (node.node_id + 1))


static func _is_reachable(node: SkillGraphNode, node_by_id: Dictionary) -> bool:
    var visited: Dictionary = {}
    var current := node
    while current != null:
        if visited.has(current.node_id):
            return false
        visited[current.node_id] = true
        if current.parent_node_id in [SkillGraph.ROOT_PARENT, SkillGraph.PLAYER_EVENT_PARENT]:
            return true
        current = node_by_id.get(current.parent_node_id) as SkillGraphNode
    return false


static func _validate_concept_schema(concept: SkillConcept, result: SkillCompileResult) -> void:
    if concept.runtime_operation_id == &"":
        result.fail("Concept %s 缺少 Runtime operation ID" % concept.concept_id)
    if concept.concept_kind not in KIND_ORDER:
        result.fail("Concept %s 的種類無效" % concept.concept_id)
    for operation: Dictionary in concept.stat_operations:
        var field := StringName(operation.get("field", &""))
        var operation_type := StringName(operation.get("op", &""))
        var value: Variant = operation.get("value")
        if not SkillDefinition.NUMERIC_FIELDS.has(field):
            result.fail("Concept %s 使用未知欄位 %s" % [concept.concept_id, field])
        elif operation_type not in SkillDefinition.STAT_OPERATIONS:
            result.fail("Concept %s 使用不允許操作 %s" % [concept.concept_id, operation_type])
        elif not value is int and not value is float:
            result.fail("Concept %s 的欄位 %s 型別錯誤" % [concept.concept_id, field])
    for raw_field: Variant in concept.structural_changes:
        if StringName(raw_field) not in SkillDefinition.STRUCTURAL_FIELDS:
            result.fail("Concept %s 使用未知結構欄位 %s" % [concept.concept_id, raw_field])


static func _capability_error(concept: SkillConcept, capabilities: Dictionary) -> String:
    for required: StringName in concept.requires_all:
        if not capabilities.has(required):
            return "需要%s能力" % CAPABILITY_LABELS.get(required, required)
    if not concept.requires_any.is_empty():
        var found := false
        for required: StringName in concept.requires_any:
            if capabilities.has(required):
                found = true
        if not found:
            var labels: PackedStringArray = []
            for required: StringName in concept.requires_any:
                labels.append(String(CAPABILITY_LABELS.get(required, required)))
            return "需要%s其中一種能力" % "／".join(labels)
    for excluded: StringName in concept.excludes:
        if capabilities.has(excluded):
            return "與%s能力衝突" % CAPABILITY_LABELS.get(excluded, excluded)
    return ""


static func _apply_capability_changes(capabilities: Dictionary, concept: SkillConcept) -> void:
    for removed: StringName in concept.removes:
        capabilities.erase(removed)
    for provided: StringName in concept.provides:
        capabilities[provided] = true


static func _adapter_key(action_type: StringName, capabilities: Dictionary) -> StringName:
    if action_type == &"summon":
        return &"summon"
    if capabilities.has(&"melee"):
        return &"melee"
    return action_type


static func _manual_root_id_excluding(graph: SkillGraph, excluded_node_id: int) -> int:
    for node: SkillGraphNode in graph.nodes:
        if node.node_id != excluded_node_id and not node.is_empty() and node.parent_node_id == SkillGraph.ROOT_PARENT:
            return node.node_id
    return -1


static func _publish_result(result: SkillCompileResult) -> SkillCompileResult:
    result.finish()
    result.graph.compiled_skills = result.compiled_skills.duplicate()
    result.graph.validation_errors = result.errors.duplicate()
    result.graph.validation_warnings = result.warnings.duplicate()
    result.graph.applied_node_ids.assign(result.applied_node_ids)
    return result


static func _op(field: StringName, operation: StringName, value: Variant) -> Dictionary:
    return {"field": field, "op": operation, "value": value}


static func _concept(
        concept_id: StringName,
        name: String,
        kind: StringName,
        summary: String,
        phase: int,
        data: Dictionary = {}
) -> SkillConcept:
    return SkillConcept.new().configure(concept_id, name, kind, summary, concept_id, phase, data)


static func _build_catalog() -> Dictionary:
    var catalog: Dictionary = {}
    var concepts: Array[SkillConcept] = [
        _concept(&"trigger_hit", "命中時", &"Trigger", "來源技能每次命中時觸發。", PHASE_SKILL),
        _concept(&"trigger_critical", "暴擊時", &"Trigger", "來源技能暴擊命中時觸發。", PHASE_SKILL),
        _concept(&"trigger_kill", "擊殺時", &"Trigger", "來源技能造成擊殺時觸發。", PHASE_SKILL),
        _concept(&"trigger_damaged", "受傷時", &"Trigger", "玩家受傷時觸發；測試場按 Q。", PHASE_SKILL),
        _concept(&"trigger_dash", "Dash 時", &"Trigger", "玩家開始 Dash 時觸發。", PHASE_SKILL),

        _concept(&"emitter_player", "玩家", &"Emitter", "改從玩家位置產生。", PHASE_EMITTER, {
            "exclusive_group": &"Emitter", "structural": {"emitter_type": &"player"},
        }),
        _concept(&"emitter_enemy", "敵人", &"Emitter", "改從事件目標或準心最近敵人產生。", PHASE_EMITTER, {
            "exclusive_group": &"Emitter", "structural": {"emitter_type": &"enemy"},
        }),
        _concept(&"emitter_impact", "碰撞點", &"Emitter", "改從觸發事件位置產生。", PHASE_EMITTER, {
            "exclusive_group": &"Emitter", "structural": {"emitter_type": &"impact"},
        }),
        _concept(&"emitter_mouse", "滑鼠位置", &"Emitter", "改從地面準心位置產生。", PHASE_EMITTER, {
            "exclusive_group": &"Emitter", "structural": {"emitter_type": &"mouse"},
        }),

        _concept(&"action_damage", "直接傷害", &"Action", "轉成即時形狀查詢並造成傷害。", PHASE_ACTION, {
            "exclusive_group": &"Action", "removes": [&"projectile", &"summon", &"minion"],
            "provides": [&"hit"], "structural": {"action_type": &"damage"},
            "stats": [_op(&"damage", &"MULTIPLY", 1.35), _op(&"cooldown", &"MULTIPLY", 1.15)],
        }),
        _concept(&"action_projectile", "投射物", &"Action", "轉成可飛行、碰撞的投射物。", PHASE_ACTION, {
            "exclusive_group": &"Action", "removes": [&"melee", &"summon", &"minion"],
            "provides": [&"projectile", &"hit"], "structural": {"action_type": &"projectile"},
        }),
        _concept(&"action_summon", "召喚", &"Action", "轉成三個分批攻擊的召喚核心。", PHASE_ACTION, {
            "exclusive_group": &"Action", "removes": [&"melee"],
            "provides": [&"summon", &"minion", &"projectile", &"hit"],
            "structural": {"action_type": &"summon"},
            "stats": [_op(&"damage", &"MULTIPLY", 0.72), _op(&"cooldown", &"MULTIPLY", 1.8)],
        }),

        _concept(&"shape_circle", "圓形", &"Pattern", "依 Action 轉為環射、圓形傷害、360° 橫掃或環形部署。", PHASE_PATTERN, {
            "exclusive_group": &"Pattern", "adapters": [&"projectile", &"damage", &"melee", &"summon"],
            "provides": [&"area"], "structural": {"shape_type": &"circle", "radial": true},
            "stats": [_op(&"projectile_count", &"SET", 10), _op(&"spread_degrees", &"SET", 0.0), _op(&"damage", &"MULTIPLY", 0.62), _op(&"projectile_lifetime", &"MULTIPLY", 0.8)],
        }),
        _concept(&"shape_cone", "扇形", &"Pattern", "依 Action 轉為扇射、扇形區域、弧斬或扇形部署。", PHASE_PATTERN, {
            "exclusive_group": &"Pattern", "adapters": [&"projectile", &"damage", &"melee", &"summon"],
            "provides": [&"area"], "structural": {"shape_type": &"cone", "radial": false},
            "stats": [_op(&"projectile_count", &"SET", 5), _op(&"spread_degrees", &"SET", 52.0), _op(&"damage", &"MULTIPLY", 0.76)],
        }),
        _concept(&"shape_line", "直線", &"Pattern", "依 Action 轉為直射、直線傷害、突刺或直線部署。", PHASE_PATTERN, {
            "exclusive_group": &"Pattern", "adapters": [&"projectile", &"damage", &"melee", &"summon"],
            "structural": {"shape_type": &"line", "radial": false},
            "stats": [_op(&"projectile_count", &"SET", 1), _op(&"spread_degrees", &"SET", 0.0), _op(&"projectile_speed", &"MULTIPLY", 1.45)],
        }),
        _concept(&"shape_rotate", "旋轉", &"Pattern", "投射物旋繞或近戰 360° 橫掃；召喚沒有此 Adapter。", PHASE_PATTERN, {
            "exclusive_group": &"Pattern", "adapters": [&"projectile", &"melee"],
            "requires_any": [&"projectile", &"melee"], "provides": [&"area"],
            "structural": {"shape_type": &"rotate", "radial": true},
            "stats": [_op(&"projectile_count", &"SET", 6), _op(&"rotation_speed", &"SET", 2.8), _op(&"damage", &"MULTIPLY", 0.7), _op(&"projectile_lifetime", &"MULTIPLY", 1.35)],
        }),
        _concept(&"shape_tracking", "追蹤", &"Pattern", "依 Action 轉為追蹤、鎖定、近戰突進或召喚自動選敵。", PHASE_PATTERN, {
            "exclusive_group": &"Pattern", "adapters": [&"projectile", &"damage", &"melee", &"summon"],
            "structural": {"shape_type": &"tracking", "radial": false},
            "stats": [_op(&"projectile_count", &"SET", 1), _op(&"spread_degrees", &"SET", 0.0), _op(&"homing_strength", &"SET", 5.4), _op(&"projectile_lifetime", &"MULTIPLY", 1.35)],
        }),

        _concept(&"modifier_split", "命中分裂", &"Modifier", "主要或其他技能的投射物命中後分裂；同一次分裂不自我遞迴。", PHASE_MODIFIER, {
            "requires_all": [&"projectile"], "structural": {"modifier_type": &"split"},
            "stats": [_op(&"split_count", &"ADD", 2), _op(&"damage", &"MULTIPLY", 0.82)],
        }),
        _concept(&"modifier_pierce", "穿透", &"Modifier", "穿過三個額外目標。", PHASE_MODIFIER, {
            "requires_all": [&"projectile"], "structural": {"modifier_type": &"pierce"},
            "stats": [_op(&"pierce_count", &"ADD", 3), _op(&"projectile_speed", &"MULTIPLY", 1.1)],
        }),
        _concept(&"modifier_bounce", "反彈", &"Modifier", "命中後轉向其他目標三次。", PHASE_MODIFIER, {
            "requires_all": [&"projectile"], "structural": {"modifier_type": &"bounce"},
            "stats": [_op(&"bounce_count", &"SET", 3), _op(&"projectile_lifetime", &"MULTIPLY", 1.35)],
        }),
        _concept(&"modifier_accelerate", "加速", &"Modifier", "投射物飛行時持續加速。", PHASE_MODIFIER, {
            "requires_all": [&"projectile"], "structural": {"modifier_type": &"accelerate"},
            "stats": [_op(&"projectile_acceleration", &"SET", 15.0), _op(&"projectile_lifetime", &"MULTIPLY", 1.15)],
        }),
        _concept(&"modifier_chain", "連鎖", &"Modifier", "命中後跳向四個鄰近目標；連鎖本身不再啟動同一連鎖。", PHASE_MODIFIER, {
            "requires_all": [&"hit"], "structural": {"modifier_type": &"chain"},
            "stats": [_op(&"chain_count", &"SET", 4), _op(&"chain_range", &"SET", 4.8), _op(&"chain_damage_multiplier", &"SET", 0.72)],
        }),
        _concept(&"modifier_rapid_fire", "連射", &"Modifier", "短間隔連續施放三輪投射物。", PHASE_MODIFIER, {
            "requires_all": [&"projectile"], "structural": {"modifier_type": &"rapid_fire"},
            "stats": [_op(&"repeat_count", &"SET", 3), _op(&"repeat_interval", &"SET", 0.11), _op(&"damage", &"MULTIPLY", 0.68), _op(&"cooldown", &"MULTIPLY", 1.18)],
        }),
        _concept(&"modifier_combo", "三連擊", &"Modifier", "近戰技能快速連續命中三次。", PHASE_MODIFIER, {
            "requires_all": [&"melee"], "structural": {"modifier_type": &"combo"},
            "stats": [_op(&"repeat_count", &"SET", 3), _op(&"repeat_interval", &"SET", 0.13), _op(&"damage", &"MULTIPLY", 0.72), _op(&"cooldown", &"MULTIPLY", 1.22)],
        }),
        _concept(&"modifier_splash", "擴散傷害", &"Modifier", "每次實際命中傷害附近敵人；擴散不自我擴散。", PHASE_MODIFIER, {
            "requires_all": [&"hit"], "structural": {"modifier_type": &"splash"},
            "stats": [_op(&"splash_radius", &"SET", 3.8), _op(&"splash_damage_multiplier", &"SET", 0.46), _op(&"damage", &"MULTIPLY", 0.88)],
        }),

        _concept(&"effect_fire", "火焰", &"Effect", "附加火焰傷害與燃燒，不改寫原始元素。", PHASE_EFFECT, {
            "requires_all": [&"hit"], "structural": {"effect_type": &"fire"},
            "stats": [_op(&"damage", &"MULTIPLY", 1.1), _op(&"burn_duration", &"SET", 3.0), _op(&"burn_damage_per_second", &"SET", 6.0)],
        }),
        _concept(&"effect_poison", "中毒", &"Effect", "附加持續中毒，不改寫原始元素。", PHASE_EFFECT, {
            "requires_all": [&"hit"], "structural": {"effect_type": &"poison"},
            "stats": [_op(&"damage", &"MULTIPLY", 0.82), _op(&"poison_duration", &"SET", 4.0), _op(&"poison_damage_per_second", &"SET", 5.0)],
        }),
        _concept(&"effect_ice", "冰凍", &"Effect", "附加凍結狀態，不改寫原始元素。", PHASE_EFFECT, {
            "requires_all": [&"hit"], "structural": {"effect_type": &"ice"},
            "stats": [_op(&"damage", &"MULTIPLY", 0.9), _op(&"freeze_duration", &"SET", 2.5)],
        }),
        _concept(&"effect_lifesteal", "吸血", &"Effect", "只依實際 Hit 傷害回復 20%，DoT 不吸血。", PHASE_EFFECT, {
            "requires_all": [&"hit"], "structural": {"effect_type": &"lifesteal"},
            "stats": [_op(&"lifesteal_ratio", &"SET", 0.2)],
        }),
        _concept(&"effect_explosion", "爆炸", &"Effect", "命中後造成範圍爆炸；爆炸不自我爆炸。", PHASE_EFFECT, {
            "requires_all": [&"hit"], "structural": {"effect_type": &"explosion"},
            "stats": [_op(&"explosion_radius", &"SET", 2.2), _op(&"explosion_damage_multiplier", &"SET", 0.65)],
        }),
    ]
    concepts.append_array(_skill_concepts())
    for concept: SkillConcept in concepts:
        catalog[concept.concept_id] = concept
    return catalog


static func _skill_concepts() -> Array[SkillConcept]:
    return [
        _concept(&"skill_fireball", "火球", &"Skill", "直線飛行並命中的火焰投射物。", PHASE_SKILL, {
            "provides": [&"spell", &"projectile", &"hit", &"fire"],
            "structural": {"active_skill_id": &"fireball", "action_type": &"projectile", "shape_type": &"line", "emitter_type": &"player", "effect_type": &"fire", "element": &"fire", "color": Color("ff7b45")},
            "stats": [_op(&"damage", &"SET", 32.0), _op(&"cooldown", &"SET", 0.55), _op(&"projectile_speed", &"SET", 14.5), _op(&"projectile_lifetime", &"SET", 2.4), _op(&"critical_chance", &"SET", 0.32), _op(&"burn_duration", &"SET", 3.0), _op(&"burn_damage_per_second", &"SET", 6.0)],
        }),
        _concept(&"skill_ice_nova", "冰環", &"Skill", "手動施放以玩家為中心；由事件觸發時以事件目標為中心擴散。", PHASE_SKILL, {
            "provides": [&"spell", &"area", &"hit", &"ice"],
            "structural": {"active_skill_id": &"ice_nova", "action_type": &"damage", "shape_type": &"circle", "emitter_type": &"context", "effect_type": &"ice", "element": &"ice", "color": Color("72d9ff"), "radial": true},
            "stats": [_op(&"damage", &"SET", 25.0), _op(&"cooldown", &"SET", 0.42), _op(&"area_radius", &"SET", 5.2), _op(&"projectile_count", &"SET", 10), _op(&"critical_chance", &"SET", 0.18), _op(&"freeze_duration", &"SET", 2.5)],
        }),
        _concept(&"skill_thunder_orb", "雷光球", &"Skill", "從角色連接準心目標，再跳向兩個鄰近敵人的瞬發雷鏈。", PHASE_SKILL, {
            "provides": [&"spell", &"hit", &"arcane"],
            "structural": {"active_skill_id": &"thunder_orb", "action_type": &"damage", "shape_type": &"tracking", "emitter_type": &"player", "element": &"arcane", "color": Color("8fdcff")},
            "stats": [_op(&"damage", &"SET", 27.0), _op(&"cooldown", &"SET", 0.48), _op(&"projectile_speed", &"SET", 11.5), _op(&"projectile_lifetime", &"SET", 3.0), _op(&"homing_strength", &"SET", 6.2), _op(&"target_range", &"SET", 12.0), _op(&"target_snap_radius", &"SET", 3.0), _op(&"chain_count", &"SET", 2), _op(&"chain_range", &"SET", 4.8), _op(&"chain_damage_multiplier", &"SET", 0.72), _op(&"critical_chance", &"SET", 0.24)],
        }),
        _concept(&"skill_blade_wave", "刃波", &"Skill", "向前方放出五道快速扇形刃波。", PHASE_SKILL, {
            "provides": [&"attack", &"projectile", &"hit", &"arcane"],
            "structural": {"active_skill_id": &"blade_wave", "action_type": &"projectile", "shape_type": &"cone", "emitter_type": &"player", "element": &"arcane", "color": Color("8fffd0")},
            "stats": [_op(&"damage", &"SET", 19.0), _op(&"cooldown", &"SET", 0.46), _op(&"projectile_speed", &"SET", 16.0), _op(&"projectile_count", &"SET", 5), _op(&"spread_degrees", &"SET", 50.0), _op(&"critical_chance", &"SET", 0.2)],
        }),
        _concept(&"skill_summon_core", "召喚核心", &"Skill", "召喚三顆魔力核心分批追蹤攻擊。", PHASE_SKILL, {
            "provides": [&"summon", &"minion", &"projectile", &"hit", &"arcane"],
            "structural": {"active_skill_id": &"summon_core", "action_type": &"summon", "shape_type": &"tracking", "emitter_type": &"impact", "element": &"arcane", "color": Color("ffd16c")},
            "stats": [_op(&"damage", &"SET", 18.0), _op(&"cooldown", &"SET", 1.05), _op(&"projectile_speed", &"SET", 10.5), _op(&"projectile_lifetime", &"SET", 3.0), _op(&"homing_strength", &"SET", 5.4), _op(&"critical_chance", &"SET", 0.15)],
        }),
        _concept(&"skill_heavy_slash", "重斬", &"Skill", "前方扇形的近戰物理重擊。", PHASE_SKILL, {
            "provides": [&"attack", &"melee", &"physical", &"hit", &"area"],
            "structural": {"active_skill_id": &"heavy_slash", "action_type": &"damage", "shape_type": &"cone", "emitter_type": &"player", "element": &"physical", "color": Color("d9e2ec")},
            "stats": [_op(&"damage", &"SET", 44.0), _op(&"cooldown", &"SET", 0.68), _op(&"projectile_count", &"SET", 5), _op(&"spread_degrees", &"SET", 52.0), _op(&"critical_chance", &"SET", 0.22), _op(&"critical_multiplier", &"ADD", 0.25)],
        }),
    ]
