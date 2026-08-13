class_name SkillGraphExecutor
extends Node

signal event_fired(message: String, event_color: Color)

const SKILL_RUNTIME_SCRIPT := preload("res://scripts/skill_runtime.gd")
const MAX_EVENTS_PER_CAST: int = 128
const MAX_EVENTS_PER_PHYSICS_FRAME: int = 48

var graph: SkillGraph
var graph_revision: int = 0
var source_player: Node3D
var counters: Dictionary = {
    "events_rejected": 0,
    "events_delayed": 0,
    "events_processed": 0,
}
var _runtime: SkillRuntime
var _event_queue: Array[CombatEvent] = []
var _cast_event_counts: Dictionary = {}
var _trigger_occurrences: Dictionary = {}
var _trigger_last_time: Dictionary = {}
var _next_cast_id: int = 1
var _elapsed_time: float = 0.0


func _ready() -> void:
    _runtime = SKILL_RUNTIME_SCRIPT.new()
    _runtime.event_fired.connect(_on_runtime_event)
    _runtime.hit_report.connect(_on_hit_report)
    add_child(_runtime)
    call_deferred("bind_damageables")


func configure(player: Node3D) -> void:
    source_player = player


func set_graph(new_graph: SkillGraph) -> void:
    graph_revision += 1
    graph = new_graph
    if graph != null:
        graph.revision = graph_revision
    _event_queue.clear()
    _cast_event_counts.clear()
    _trigger_occurrences.clear()
    _trigger_last_time.clear()
    if _runtime != null:
        _runtime.set_graph_revision(graph_revision)
    bind_damageables()


func request_manual_cast(aim_position: Vector3, facing_direction: Vector3) -> bool:
    if graph == null or not graph.is_valid():
        return false
    var root_node_id := graph.get_primary_skill_node_id()
    if root_node_id < 0:
        return false
    var cast_id := _begin_cast()
    return _enqueue(CombatEvent.new().configure({
        "cast_id": cast_id,
        "graph_revision": graph_revision,
        "source_skill_node_id": root_node_id,
        "target_skill_node_id": root_node_id,
        "event_type": &"cast",
        "world_position": aim_position,
        "source": source_player,
        "facing_direction": facing_direction,
    }))


func request_external_event(
        event_type: StringName,
        world_position: Vector3,
        target: Node3D = null
) -> bool:
    if graph == null or not graph.is_valid():
        return false
    var cast_id := _begin_cast()
    return _enqueue(CombatEvent.new().configure({
        "cast_id": cast_id,
        "graph_revision": graph_revision,
        "source_skill_node_id": -1,
        "event_type": event_type,
        "world_position": world_position,
        "target": target,
        "source": source_player,
        "facing_direction": _get_player_facing(),
    }))


func bind_damageables() -> void:
    if get_tree() == null:
        return
    for damageable: Node in get_tree().get_nodes_in_group("damageable"):
        if damageable.has_signal("dot_killed") and not damageable.is_connected("dot_killed", _on_dot_killed):
            damageable.connect("dot_killed", _on_dot_killed)


func get_queue_size() -> int:
    return _event_queue.size()


func get_active_projectile_count() -> int:
    return _runtime.get_active_projectile_count() if _runtime != null else 0


func get_projectile_pool_count() -> int:
    return _runtime.get_projectile_pool_count() if _runtime != null else 0


func get_rejected_projectile_count() -> int:
    return _runtime.get_rejected_projectile_count() if _runtime != null else 0


func process_queued_events(limit: int = MAX_EVENTS_PER_PHYSICS_FRAME) -> int:
    var processed := 0
    while processed < limit and not _event_queue.is_empty():
        var event: CombatEvent = _event_queue.pop_front()
        if event.graph_revision == graph_revision:
            _process_event(event)
        processed += 1
        counters["events_processed"] = int(counters["events_processed"]) + 1
    return processed


func _physics_process(delta: float) -> void:
    _elapsed_time += delta
    process_queued_events()
    if not _event_queue.is_empty():
        counters["events_delayed"] = int(counters["events_delayed"]) + _event_queue.size()
    elif _runtime != null and _runtime.get_active_projectile_count() == 0:
        _cast_event_counts.clear()


func _begin_cast() -> int:
    var cast_id := _next_cast_id
    _next_cast_id += 1
    _cast_event_counts[cast_id] = 0
    return cast_id


func _can_enqueue(cast_id: int) -> bool:
    return int(_cast_event_counts.get(cast_id, 0)) < MAX_EVENTS_PER_CAST


func _enqueue(event: CombatEvent) -> bool:
    if event.graph_revision != graph_revision:
        return false
    if not _can_enqueue(event.cast_id):
        counters["events_rejected"] = int(counters["events_rejected"]) + 1
        return false
    _cast_event_counts[event.cast_id] = int(_cast_event_counts.get(event.cast_id, 0)) + 1
    _event_queue.append(event)
    return true


func _process_event(event: CombatEvent) -> void:
    if graph == null:
        return
    if event.event_type == &"cast":
        _execute_skill(event)
    else:
        _execute_triggers(event)


func _execute_skill(event: CombatEvent) -> void:
    var definition := graph.get_compiled_skill(event.target_skill_node_id)
    if definition == null:
        return
    var aim_position := event.world_position
    var origin := _resolve_emitter_position(
        definition,
        event.world_position,
        aim_position,
        event.target,
        event.depth
    )
    var direction := aim_position - origin
    direction.y = 0.0
    if direction.length_squared() < 0.04:
        direction = event.facing_direction
    if direction.length_squared() < 0.04:
        direction = Vector3.FORWARD
    _runtime.cast_skill(
        definition,
        origin,
        direction.normalized(),
        source_player,
        event.to_context()
    )


func _execute_triggers(event: CombatEvent) -> void:
    var trigger_nodes: Array[SkillGraphNode] = []
    if event.event_type in [&"damaged", &"dash"]:
        for node: SkillGraphNode in graph.get_children(SkillGraph.PLAYER_EVENT_PARENT):
            trigger_nodes.append(node)
    elif event.source_skill_node_id >= 0:
        for node: SkillGraphNode in graph.get_children(event.source_skill_node_id):
            trigger_nodes.append(node)
    trigger_nodes.sort_custom(func(left: SkillGraphNode, right: SkillGraphNode) -> bool:
        return left.node_id < right.node_id
    )
    for trigger_node: SkillGraphNode in trigger_nodes:
        var concept := ConceptLibrary.get_concept(trigger_node.concept_id)
        if concept == null or concept.concept_kind != &"Trigger":
            continue
        if ConceptLibrary.get_trigger_type(trigger_node.concept_id) != event.event_type:
            continue
        if not _passes_trigger(trigger_node, event):
            continue
        var queued_any := false
        for child: SkillGraphNode in graph.get_children(trigger_node.node_id):
            var child_concept := ConceptLibrary.get_concept(child.concept_id)
            if child_concept == null or child_concept.concept_kind != &"Skill":
                continue
            var cast_event := CombatEvent.new().configure({
                "cast_id": event.cast_id,
                "graph_revision": graph_revision,
                "source_skill_node_id": child.node_id,
                "target_skill_node_id": child.node_id,
                "event_type": &"cast",
                "world_position": event.world_position,
                "target": event.target,
                "source": source_player,
                "damage_source": event.damage_source,
                "depth": event.depth + 1,
                "facing_direction": event.facing_direction,
                "applied_operations": event.applied_operations,
            })
            queued_any = _enqueue(cast_event) or queued_any
        if queued_any:
            _trigger_last_time[trigger_node.node_id] = _elapsed_time
            event_fired.emit(
                "觸發 → %s" % concept.display_name,
                Color("80d8ff")
            )


func _passes_trigger(trigger_node: SkillGraphNode, event: CombatEvent) -> bool:
    var config := trigger_node.trigger_config
    if config == null:
        config = TriggerConfig.new()
    if source_player != null:
        var health_ratio := float(source_player.get("health")) / maxf(float(source_player.get("max_health")), 1.0)
        if health_ratio > config.max_player_health_ratio:
            return false
    if config.required_target_status != &"any":
        if not is_instance_valid(event.target) or not event.target.has_method("has_status"):
            return false
        if not bool(event.target.call("has_status", config.required_target_status)):
            return false
    var occurrence := int(_trigger_occurrences.get(trigger_node.node_id, 0)) + 1
    _trigger_occurrences[trigger_node.node_id] = occurrence
    if occurrence % config.every_n != 0:
        return false
    var last_time := float(_trigger_last_time.get(trigger_node.node_id, -INF))
    if _elapsed_time - last_time < config.internal_cooldown:
        return false
    if _deterministic_percent(event.cast_id, trigger_node.node_id, occurrence) >= config.chance:
        return false
    return _can_enqueue(event.cast_id)


func _deterministic_percent(cast_id: int, trigger_node_id: int, occurrence: int) -> float:
    var mixed := (cast_id * 73856093) ^ (trigger_node_id * 19349663) ^ (occurrence * 83492791)
    return float(absi(mixed) % 100000) / 1000.0


func _on_hit_report(report: Dictionary) -> void:
    if int(report.get("graph_revision", -1)) != graph_revision:
        return
    _enqueue(_event_from_report(report, &"hit"))
    if bool(report.get("critical", false)):
        _enqueue(_event_from_report(report, &"critical"))
    if bool(report.get("killed", false)):
        _enqueue(_event_from_report(report, &"kill"))


func _event_from_report(report: Dictionary, event_type: StringName) -> CombatEvent:
    var data := report.duplicate(true)
    data["event_type"] = event_type
    data["facing_direction"] = _get_player_facing()
    return CombatEvent.new().configure(data)


func _on_dot_killed(context: Dictionary, world_position: Vector3, target: Node3D) -> void:
    var report := context.duplicate(true)
    report["world_position"] = world_position
    report["target"] = target
    report["source"] = source_player
    report["damage_source"] = &"dot"
    report["critical"] = false
    report["killed"] = true
    _enqueue(_event_from_report(report, &"kill"))


func _resolve_emitter_position(
        definition: SkillDefinition,
        event_position: Vector3,
        mouse_position: Vector3,
        event_target: Node3D,
        event_depth: int
) -> Vector3:
    match definition.emitter_type:
        &"context":
            if event_depth > 0:
                if is_instance_valid(event_target):
                    return event_target.global_position + Vector3.UP * 0.05
                return event_position + Vector3.UP * 0.05
            if source_player != null:
                return source_player.global_position + Vector3.UP * 0.05
        &"enemy":
            if is_instance_valid(event_target) and event_target.is_in_group("damageable"):
                return event_target.global_position + Vector3.UP * 1.1
            var nearest := _find_nearest_dummy(mouse_position)
            if nearest != null:
                return nearest.global_position + Vector3.UP * 1.1
        &"impact":
            return event_position + Vector3.UP * 0.35
        &"mouse":
            if source_player != null and source_player.has_method("get_aim_world_position"):
                return source_player.call("get_aim_world_position") + Vector3.UP * 0.35
            return mouse_position + Vector3.UP * 0.35
        &"player":
            if source_player != null:
                if definition.action_type == &"damage" and definition.shape_type in [&"circle", &"rotate"]:
                    return source_player.global_position + Vector3.UP * 0.05
                return source_player.global_position + Vector3.UP * 1.15 + _get_player_facing() * 0.65
    return event_position + Vector3.UP * 0.35


func _find_nearest_dummy(world_position: Vector3) -> Node3D:
    var nearest: Node3D
    var nearest_distance := INF
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D:
            continue
        var target := candidate as Node3D
        var distance := target.global_position.distance_to(world_position)
        if distance < nearest_distance:
            nearest = target
            nearest_distance = distance
    return nearest


func _get_player_facing() -> Vector3:
    if source_player != null and source_player.has_method("get_facing_direction"):
        return source_player.call("get_facing_direction") as Vector3
    return Vector3.FORWARD


func _on_runtime_event(message: String, event_color: Color) -> void:
    event_fired.emit(message, event_color)
