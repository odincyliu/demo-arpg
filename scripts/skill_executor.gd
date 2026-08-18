class_name SkillExecutor
extends Node

signal event_fired(message: String, event_color: Color)

const SKILL_RUNTIME_SCRIPT := preload("res://scripts/skill_runtime.gd")
const MAX_EVENTS_PER_CAST: int = 128
const MAX_EVENTS_PER_PHYSICS_FRAME: int = 48

var build: SixLinkBuild
var build_revision: int = 0
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
var _damage_accumulated: float = 0.0
var _channel_active: bool = false
var _channel_cast_id: int = 0
var _channel_tick_remaining: float = 0.0
var _channel_trigger_remaining: float = 0.0
var _channel_aim: Vector3 = Vector3.ZERO
var _channel_direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
    _runtime = SKILL_RUNTIME_SCRIPT.new()
    _runtime.event_fired.connect(_on_runtime_event)
    _runtime.combat_report.connect(_on_combat_report)
    add_child(_runtime)
    call_deferred("bind_damageables")


func configure(player: Node3D) -> void:
    source_player = player


func set_build(new_build: SixLinkBuild) -> void:
    stop_channel()
    build_revision += 1
    build = new_build
    if build != null:
        build.revision = build_revision
    _event_queue.clear()
    _cast_event_counts.clear()
    _trigger_occurrences.clear()
    _trigger_last_time.clear()
    _damage_accumulated = 0.0
    if _runtime != null:
        _runtime.set_build_revision(build_revision)
    bind_damageables()


func request_manual_cast(aim_position: Vector3, facing_direction: Vector3) -> bool:
    if build == null or not build.is_valid() or build.get_root_core().channelled:
        return false
    var cast_id := _begin_cast()
    return _enqueue(_cast_event(
        cast_id,
        build.get_root_core().compiled_slot_index,
        0,
        aim_position,
        null,
        facing_direction
    ))


func begin_channel(aim_position: Vector3, facing_direction: Vector3) -> bool:
    if build == null or not build.is_valid() or not build.get_root_core().channelled:
        return false
    if _channel_active:
        update_channel_target(aim_position, facing_direction)
        return true
    _channel_active = true
    _channel_cast_id = _begin_cast()
    _channel_tick_remaining = 0.0
    _channel_trigger_remaining = 0.0
    update_channel_target(aim_position, facing_direction)
    return true


func update_channel_target(aim_position: Vector3, facing_direction: Vector3) -> void:
    _channel_aim = aim_position
    _channel_direction = facing_direction.normalized() if facing_direction.length_squared() > 0.01 else Vector3.FORWARD


func stop_channel() -> void:
    if _channel_active and build != null and build.is_valid() and _runtime != null:
        var origin := source_player.global_position if is_instance_valid(source_player) else _channel_aim
        _runtime.end_channel(build.get_root_core(), origin, _channel_aim)
    _channel_active = false
    _channel_cast_id = 0
    _channel_tick_remaining = 0.0
    _channel_trigger_remaining = 0.0


func is_channeling() -> bool:
    return _channel_active


func request_player_damage(amount: float, world_position: Vector3) -> bool:
    if build == null or not build.is_valid() or amount <= 0.0:
        return false
    if not build.compiled.has_trigger() or SkillCatalog.get_trigger_event(build.compiled.trigger_component.component_id) != &"damage_taken":
        return false
    _damage_accumulated += amount
    var config := build.compiled.trigger_config
    var max_health := float(source_player.get("max_health")) if source_player != null else 100.0
    var threshold := maxf(max_health * config.damage_threshold_ratio, 1.0)
    if _damage_accumulated < threshold:
        return false
    _damage_accumulated = fmod(_damage_accumulated, threshold)
    var cast_id := _begin_cast()
    return _enqueue(CombatEvent.new().configure({
        "cast_id": cast_id,
        "build_revision": build_revision,
        "source_core_slot_index": build.compiled.source_core_slot_index,
        "event_type": &"damage_taken",
        "world_position": world_position,
        "source": source_player,
        "amount": amount,
        "generation": 0,
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


func get_active_minion_count() -> int:
    return _runtime.get_active_minion_count() if _runtime != null else 0


func get_held_count() -> int:
    return _runtime.get_held_count() if _runtime != null else 0


func get_persistent_effect_count() -> int:
    return _runtime.get_persistent_effect_count() if _runtime != null else 0


func get_scheduled_action_count() -> int:
    return _runtime.get_scheduled_action_count() if _runtime != null else 0


func process_queued_events(limit: int = MAX_EVENTS_PER_PHYSICS_FRAME) -> int:
    var processed := 0
    while processed < limit and not _event_queue.is_empty():
        var event: CombatEvent = _event_queue.pop_front()
        if event.build_revision == build_revision:
            _process_event(event)
        processed += 1
        counters["events_processed"] = int(counters["events_processed"]) + 1
    return processed


func _physics_process(delta: float) -> void:
    _elapsed_time += delta
    _process_channel(delta)
    process_queued_events()
    if not _event_queue.is_empty():
        counters["events_delayed"] = int(counters["events_delayed"]) + _event_queue.size()
    elif _runtime != null and _runtime.get_active_projectile_count() == 0 and not _channel_active:
        _cast_event_counts.clear()


func _process_channel(delta: float) -> void:
    if not _channel_active or build == null or not build.is_valid():
        return
    var root := build.get_root_core()
    _channel_tick_remaining -= delta
    if _channel_tick_remaining <= 0.0:
        _channel_tick_remaining += root.channel_tick_interval
        _enqueue(_cast_event(
            _channel_cast_id,
            root.compiled_slot_index,
            0,
            _channel_aim,
            null,
            _channel_direction
        ))
    if build.compiled.has_trigger() and SkillCatalog.get_trigger_event(build.compiled.trigger_component.component_id) == &"channel":
        _channel_trigger_remaining -= delta
        if _channel_trigger_remaining <= 0.0:
            _channel_trigger_remaining += build.compiled.trigger_config.channel_interval
            _enqueue(CombatEvent.new().configure({
                "cast_id": _channel_cast_id,
                "build_revision": build_revision,
                "source_core_slot_index": root.compiled_slot_index,
                "event_type": &"channel",
                "world_position": _channel_aim,
                "source": source_player,
                "generation": 0,
                "facing_direction": _channel_direction,
            }))


func _begin_cast() -> int:
    var cast_id := _next_cast_id
    _next_cast_id += 1
    _cast_event_counts[cast_id] = 0
    return cast_id


func _can_enqueue(cast_id: int) -> bool:
    return int(_cast_event_counts.get(cast_id, 0)) < MAX_EVENTS_PER_CAST


func _enqueue(event: CombatEvent) -> bool:
    if event.build_revision != build_revision or not _can_enqueue(event.cast_id):
        counters["events_rejected"] = int(counters["events_rejected"]) + 1
        return false
    _cast_event_counts[event.cast_id] = int(_cast_event_counts.get(event.cast_id, 0)) + 1
    _event_queue.append(event)
    return true


func _cast_event(
        cast_id: int,
        slot_index: int,
        generation: int,
        world_position: Vector3,
        target: Node3D,
        facing_direction: Vector3
) -> CombatEvent:
    return CombatEvent.new().configure({
        "cast_id": cast_id,
        "build_revision": build_revision,
        "source_core_slot_index": slot_index,
        "target_core_slot_index": slot_index,
        "event_type": &"cast",
        "world_position": world_position,
        "target": target,
        "source": source_player,
        "generation": generation,
        "facing_direction": facing_direction,
    })


func _process_event(event: CombatEvent) -> void:
    if build == null or not build.is_valid():
        return
    if event.event_type == &"cast":
        _execute_core(event)
    else:
        _evaluate_trigger(event)


func _execute_core(event: CombatEvent) -> void:
    var definition := build.compiled.get_core(event.target_core_slot_index)
    if definition == null:
        return
    var origin := _resolve_origin(definition, event)
    var direction := event.world_position - origin
    direction.y = 0.0
    if direction.length_squared() < 0.04:
        direction = event.facing_direction
    if direction.length_squared() < 0.04:
        direction = Vector3.FORWARD
    _runtime.cast_skill(definition, origin, direction.normalized(), source_player, event.to_context())


func _evaluate_trigger(event: CombatEvent) -> void:
    if event.generation >= 1 or not build.compiled.has_trigger():
        return
    var trigger_event := SkillCatalog.get_trigger_event(build.compiled.trigger_component.component_id)
    if trigger_event != event.event_type:
        return
    if trigger_event not in [&"damage_taken", &"channel"] and event.source_core_slot_index != build.compiled.source_core_slot_index:
        return
    if not _passes_trigger(event):
        return
    var target_core := build.compiled.triggered_core
    var cast_event := _cast_event(
        event.cast_id,
        target_core.compiled_slot_index,
        1,
        event.world_position,
        event.target,
        event.facing_direction
    )
    if _enqueue(cast_event):
        _trigger_last_time[build.compiled.trigger_slot_index] = _elapsed_time
        event_fired.emit("%s -> %s" % [build.compiled.trigger_component.display_name, target_core.display_name], Color("80d8ff"))


func _passes_trigger(event: CombatEvent) -> bool:
    var config := build.compiled.trigger_config if build.compiled.trigger_config != null else TriggerConfig.new()
    if source_player != null:
        var health_ratio := float(source_player.get("health")) / maxf(float(source_player.get("max_health")), 1.0)
        if health_ratio > config.max_player_health_ratio:
            return false
    if config.required_target_status != &"any":
        if not is_instance_valid(event.target) or not event.target.has_method("has_status"):
            return false
        if not bool(event.target.call("has_status", config.required_target_status)):
            return false
    var trigger_slot := build.compiled.trigger_slot_index
    var occurrence := int(_trigger_occurrences.get(trigger_slot, 0)) + 1
    _trigger_occurrences[trigger_slot] = occurrence
    if occurrence % config.every_n != 0:
        return false
    var last_time := float(_trigger_last_time.get(trigger_slot, -INF))
    if _elapsed_time - last_time < config.internal_cooldown:
        return false
    if _deterministic_percent(event.cast_id, trigger_slot, occurrence) >= config.chance:
        return false
    return _can_enqueue(event.cast_id)


func _deterministic_percent(cast_id: int, trigger_slot: int, occurrence: int) -> float:
    var mixed := (cast_id * 73856093) ^ (trigger_slot * 19349663) ^ (occurrence * 83492791)
    return float(absi(mixed) % 100000) / 1000.0


func _on_combat_report(report: Dictionary) -> void:
    if int(report.get("build_revision", -1)) != build_revision:
        return
    var events: Array[StringName] = []
    events.assign(report.get("events", []))
    for event_type: StringName in events:
        var data := report.duplicate(true)
        data["event_type"] = event_type
        data["facing_direction"] = report.get("facing_direction", _get_player_facing())
        _enqueue(CombatEvent.new().configure(data))


func _on_dot_killed(context: Dictionary, world_position: Vector3, target: Node3D) -> void:
    var data := context.duplicate(true)
    data["event_type"] = &"kill"
    data["events"] = [&"kill"]
    data["world_position"] = world_position
    data["target"] = target
    data["source"] = source_player
    data["damage_source"] = &"dot"
    data["facing_direction"] = _get_player_facing()
    _on_combat_report(data)


func _resolve_origin(definition: SkillDefinition, event: CombatEvent) -> Vector3:
    match definition.origin_policy:
        &"event":
            if is_instance_valid(event.target):
                return event.target.global_position + Vector3.UP * 0.1
            return event.world_position + Vector3.UP * 0.1
        &"target":
            return event.world_position + Vector3.UP * 0.1
        _:
            if event.generation > 0 and is_instance_valid(event.target):
                return event.target.global_position + Vector3.UP * 0.1
            if source_player != null:
                return source_player.global_position + Vector3.UP * 1.05
    return event.world_position + Vector3.UP * 0.1


func _get_player_facing() -> Vector3:
    if source_player != null and source_player.has_method("get_facing_direction"):
        return source_player.call("get_facing_direction") as Vector3
    return Vector3.FORWARD


func _on_runtime_event(message: String, event_color: Color) -> void:
    event_fired.emit(message, event_color)
