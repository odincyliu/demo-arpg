class_name SkillRuntime
extends Node

signal event_fired(message: String, event_color: Color)
signal combat_report(report: Dictionary)

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const PROJECTILE_MANAGER_SCRIPT := preload("res://scripts/projectile_manager.gd")
const MINION_SCRIPT := preload("res://scripts/skill_minion.gd")
const MAX_PERSISTENT_EFFECTS: int = 128
const MAX_ACTIVE_MINIONS: int = 24

var _build_revision: int = 0
var _projectile_manager: ProjectileManager
var _scheduled_actions: Array[Dictionary] = []
var _held_groups: Dictionary = {}
var _persistent_effects: Array[Dictionary] = []
var _active_minions: Array[SkillMinion] = []
var _minion_pool: Array[SkillMinion] = []
var _cast_visual_sequence: int = 0
var _hit_visual_sequence: int = 0
var _channel_sustain_vfx: Node3D


func _ready() -> void:
    _projectile_manager = PROJECTILE_MANAGER_SCRIPT.new()
    _projectile_manager.projectile_impact.connect(_on_projectile_impact)
    _projectile_manager.projectile_expiry_burst.connect(_on_projectile_expiry_burst)
    _projectile_manager.projectile_returned.connect(_on_projectile_returned)
    _projectile_manager.projectile_remnant.connect(_on_projectile_remnant)
    _projectile_manager.projectile_event.connect(_on_projectile_event)
    add_child(_projectile_manager)


func _physics_process(delta: float) -> void:
    _process_scheduled(delta)
    _process_held(delta)
    _process_persistent(delta)


func set_build_revision(revision: int) -> void:
    _build_revision = revision
    for action: Dictionary in _scheduled_actions:
        _free_scheduled_vfx(action)
    _scheduled_actions.clear()
    _held_groups.clear()
    _free_channel_sustain_vfx()
    for effect: Dictionary in _persistent_effects:
        _free_persistent_vfx(effect)
    _persistent_effects.clear()
    if _projectile_manager != null:
        _projectile_manager.clear_active()
    for minion: SkillMinion in _active_minions.duplicate():
        minion.deactivate()


func get_active_projectile_count() -> int:
    return _projectile_manager.get_active_count() if _projectile_manager != null else 0


func get_projectile_pool_count() -> int:
    return _projectile_manager.get_pool_count() if _projectile_manager != null else 0


func get_rejected_projectile_count() -> int:
    return _projectile_manager.rejected_requests if _projectile_manager != null else 0


func get_active_minion_count() -> int:
    return _active_minions.size()


func get_held_count() -> int:
    var count := 0
    for raw_group: Variant in _held_groups.values():
        count += (raw_group as Dictionary).get("requests", []).size()
    return count


func get_persistent_effect_count() -> int:
    return _persistent_effects.size()


func get_scheduled_action_count() -> int:
    return _scheduled_actions.size()


func begin_channel(definition: SkillDefinition, source: Node3D) -> void:
    _free_channel_sustain_vfx()
    if definition != null and is_instance_valid(source):
        _channel_sustain_vfx = COMBAT_VFX.spawn_channel_sustain(source, definition)


func end_channel(definition: SkillDefinition, origin: Vector3, target_position: Vector3) -> void:
    _free_channel_sustain_vfx()
    COMBAT_VFX.spawn_channel_end(get_tree().current_scene, definition, origin, target_position)


func cast_skill(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    if definition == null or int(context.get("build_revision", -1)) != _build_revision:
        return
    _cast_visual_sequence += 1
    if _should_spawn_combat_visual(false) and not is_instance_valid(_channel_sustain_vfx):
        COMBAT_VFX.spawn_cast_layers(get_tree().current_scene, definition, origin, facing_direction)
    _execute_cast_wave(definition, origin, facing_direction, source, context)
    for repeat_index: int in range(1, definition.repeat_count):
        _scheduled_actions.append({
            "kind": &"cast",
            "remaining": definition.repeat_interval * repeat_index,
            "definition": definition,
            "origin": origin,
            "direction": facing_direction,
            "source": source,
            "context": context.duplicate(true),
        })


func _execute_cast_wave(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    var caster_count := 1 + definition.phantom_count
    var perpendicular := Vector3(-facing_direction.z, 0.0, facing_direction.x)
    for caster_index: int in caster_count:
        var cast_origin := origin
        var cast_context := context.duplicate(true)
        if caster_index > 0:
            var side := -1.0 if caster_index % 2 == 1 else 1.0
            cast_origin += perpendicular * side * (0.9 + float(caster_index / 2) * 0.5)
            cast_context["damage_multiplier"] = float(cast_context.get("damage_multiplier", 1.0)) * definition.phantom_damage_multiplier
            cast_context["phantom"] = true
        _execute_core(definition, cast_origin, facing_direction, source, cast_context)


func _execute_core(
        definition: SkillDefinition,
        origin: Vector3,
        direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    match definition.core_behavior:
        &"projectile", &"wave":
            _spawn_projectile_pattern(definition, origin, direction, source, context)
        &"chain":
            _cast_chain(definition, origin, direction, source, context)
        &"meteor":
            var impact_position := context.get("aim_position", origin) as Vector3
            var fall_duration := maxf(definition.repeat_interval, 0.1)
            var descent_vfx := COMBAT_VFX.spawn_meteor_descent(
                get_tree().current_scene,
                impact_position,
                fall_duration,
                definition.area_radius
            )
            _scheduled_actions.append({
                "kind": &"meteor",
                "remaining": fall_duration,
                "definition": definition,
                "origin": impact_position,
                "direction": direction,
                "source": source,
                "context": context.duplicate(true),
                "vfx": descent_vfx,
            })
        &"persistent":
            _add_persistent(definition, context.get("aim_position", origin), source, context, 1.0)
        &"summon":
            for instance_index: int in definition.instance_count:
                _spawn_minion(definition, source, origin, context, instance_index)
        &"dash":
            if is_instance_valid(source):
                var dash_origin := source.global_position
                source.global_position += direction * definition.target_range
                COMBAT_VFX.spawn_dash_sequence(
                    get_tree().current_scene,
                    dash_origin,
                    source.global_position,
                    source.rotation.y
                )
                _damage_line(definition, dash_origin, direction, source, context)
        _:
            for _instance_index: int in definition.instance_count:
                _cast_direct_damage(definition, origin, direction, source, context)


func _spawn_projectile_pattern(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    var base_count := maxi(definition.projectile_count, 1)
    var total_count := mini(base_count * definition.instance_count, 64)
    var directions: Array[Vector3] = []
    if definition.radial or definition.shape_type in [&"circle", &"rotate"]:
        for index: int in total_count:
            directions.append(facing_direction.rotated(Vector3.UP, TAU * float(index) / float(total_count)))
    elif definition.shape_type == &"cone" or total_count > 1:
        var spread := definition.spread_degrees if definition.spread_degrees > 0.0 else 24.0
        var step := spread / float(maxi(total_count - 1, 1))
        for index: int in total_count:
            var angle := 0.0 if total_count == 1 else -spread * 0.5 + step * index
            directions.append(facing_direction.rotated(Vector3.UP, deg_to_rad(angle)))
    else:
        directions.append(facing_direction)
    for projectile_direction: Vector3 in directions:
        var projectile_context := context.duplicate(true)
        projectile_context["base_direction"] = facing_direction
        var angle_offset := atan2(
            facing_direction.cross(projectile_direction).y,
            facing_direction.dot(projectile_direction)
        )
        if definition.hold_enabled:
            _store_projectile(definition, source, origin, projectile_direction, angle_offset, projectile_context)
        else:
            _request_projectile(definition, source, origin, projectile_direction, projectile_context, true)


func _store_projectile(
        definition: SkillDefinition,
        source: Node3D,
        origin: Vector3,
        direction: Vector3,
        angle_offset: float,
        context: Dictionary
) -> void:
    var source_id := source.get_instance_id() if is_instance_valid(source) else 0
    var key := "%d:%d" % [source_id, definition.compiled_slot_index]
    if not _held_groups.has(key):
        _held_groups[key] = {
            "elapsed": 0.0,
            "definition": definition,
            "source": source,
            "requests": [],
        }
    var group := _held_groups[key] as Dictionary
    var requests: Array = group["requests"]
    requests.append({
        "origin": origin,
        "direction": direction,
        "angle_offset": angle_offset,
        "context": context.duplicate(true),
    })
    COMBAT_VFX.spawn_pulse(get_tree().current_scene, origin, definition.color, 0.24)
    if requests.size() >= definition.hold_max_stored:
        _release_held_group(key)


func _process_held(delta: float) -> void:
    for raw_key: Variant in _held_groups.keys().duplicate():
        var key := String(raw_key)
        if not _held_groups.has(key):
            continue
        var group := _held_groups[key] as Dictionary
        group["elapsed"] = float(group.get("elapsed", 0.0)) + delta
        var definition := group["definition"] as SkillDefinition
        if float(group["elapsed"]) >= definition.hold_auto_release:
            _release_held_group(key)


func _release_held_group(key: String) -> void:
    if not _held_groups.has(key):
        return
    var group := _held_groups[key] as Dictionary
    _held_groups.erase(key)
    var definition := group["definition"] as SkillDefinition
    var source := group["source"] as Node3D
    var release_direction := Vector3.FORWARD
    if is_instance_valid(source) and source.has_method("get_aim_world_position"):
        release_direction = source.call("get_aim_world_position") - source.global_position
        release_direction.y = 0.0
    if release_direction.length_squared() < 0.04 and is_instance_valid(source) and source.has_method("get_facing_direction"):
        release_direction = source.call("get_facing_direction") as Vector3
    release_direction = release_direction.normalized() if release_direction.length_squared() > 0.01 else Vector3.FORWARD
    for raw_request: Variant in group["requests"]:
        var request := raw_request as Dictionary
        var direction := release_direction.rotated(Vector3.UP, float(request["angle_offset"]))
        var origin := request["origin"] as Vector3
        if is_instance_valid(source):
            origin = source.global_position + Vector3.UP * 1.05
        _request_projectile(definition, source, origin, direction, request["context"] as Dictionary, true)
    event_fired.emit("Hold released %d %s instances" % [(group["requests"] as Array).size(), definition.display_name], definition.color)


func _request_projectile(
        definition: SkillDefinition,
        source: Node3D,
        origin: Vector3,
        direction: Vector3,
        context: Dictionary,
        can_fork: bool
) -> SkillProjectile:
    return _projectile_manager.request_projectile(
        get_tree().current_scene,
        definition,
        source,
        origin,
        direction,
        context,
        can_fork
    )


func _cast_direct_damage(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    var aim_position := context.get("aim_position", origin + facing_direction * 5.0) as Vector3
    var query_origin := aim_position if definition.origin_policy == &"target" else origin
    for target: Node3D in _get_shape_targets(definition, query_origin, facing_direction, aim_position):
        _deal_hit(definition, target, source, context, facing_direction)


func _damage_line(
        definition: SkillDefinition,
        origin: Vector3,
        direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    for target: Node3D in _get_shape_targets(definition, origin, direction, origin + direction * definition.target_range):
        _deal_hit(definition, target, source, context, direction)


func _cast_chain(
        definition: SkillDefinition,
        origin: Vector3,
        direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    var target := _get_tracking_target(definition, origin, context.get("aim_position", origin + direction * 8.0))
    if target == null:
        return
    var first_direction := target.global_position - origin
    first_direction.y = 0.0
    if first_direction.length_squared() <= 0.01:
        first_direction = direction
    COMBAT_VFX.spawn_chain_lightning(
        get_tree().current_scene,
        origin,
        target.global_position + Vector3.UP,
        definition.color,
        absi(hash([int(context.get("cast_id", 0)), 0]))
    )
    _deal_hit(definition, target, source, context, first_direction.normalized())
    _chain_from(definition, target, source, context, {target.get_instance_id(): true})


func _on_projectile_impact(projectile: SkillProjectile, target: Node3D) -> void:
    if projectile == null or projectile.definition == null:
        return
    var definition := projectile.definition
    var context := projectile.context
    _deal_hit(definition, target, projectile.source, context, projectile.direction)
    if definition.impact_radius > 0.0:
        _damage_area(
            definition,
            target.global_position,
            definition.impact_radius * definition.size_multiplier,
            projectile.source,
            context,
            0.72,
            target
        )
    if definition.fork_count > 0 and projectile.can_split:
        var spread := 36.0
        for index: int in definition.fork_count:
            var angle := -spread * 0.5 + spread * float(index) / float(maxi(definition.fork_count - 1, 1))
            _request_projectile(
                definition,
                projectile.source,
                projectile.global_position + Vector3.UP * 0.05,
                projectile.direction.rotated(Vector3.UP, deg_to_rad(angle)),
                context,
                false
            )
    if definition.chain_count > 0:
        _chain_from(definition, target, projectile.source, context, {target.get_instance_id(): true})
    if definition.core_behavior != &"wave":
        projectile.resolve_impact(target)


func _on_projectile_expiry_burst(projectile: SkillProjectile, world_position: Vector3) -> void:
    if projectile == null or projectile.definition == null:
        return
    var definition := projectile.definition
    _damage_area(
        definition,
        world_position,
        definition.impact_radius * definition.size_multiplier,
        projectile.source,
        projectile.context,
        0.72
    )
    COMBAT_VFX.spawn_pulse(get_tree().current_scene, world_position, definition.color, definition.impact_radius)


func _on_projectile_returned(projectile: SkillProjectile) -> void:
    if projectile == null:
        return
    var report := projectile.context.duplicate(true)
    report["events"] = [&"return"]
    report["world_position"] = projectile.global_position
    report["target"] = projectile.source
    report["source"] = projectile.source
    report["source_core_slot_index"] = projectile.definition.compiled_slot_index
    report["generation"] = int(report.get("generation", 0))
    report["facing_direction"] = projectile.direction
    combat_report.emit(report)


func _on_projectile_remnant(projectile: SkillProjectile, world_position: Vector3) -> void:
    if projectile == null or projectile.definition == null:
        return
    _add_persistent(projectile.definition, world_position, projectile.source, projectile.context, projectile.definition.remnant_damage_multiplier, true)


func _add_persistent(
        definition: SkillDefinition,
        world_position: Vector3,
        source: Node3D,
        context: Dictionary,
        damage_multiplier: float,
        is_remnant: bool = false
) -> void:
    if _persistent_effects.size() >= MAX_PERSISTENT_EFFECTS:
        var evicted_effect: Dictionary = _persistent_effects.pop_front()
        _free_persistent_vfx(evicted_effect)
    var duration: float = definition.remnant_duration if is_remnant else definition.persistent_duration
    var radius: float = maxf(0.8, definition.area_radius * (0.38 if is_remnant else 1.0))
    var vfx_node: Node3D = COMBAT_VFX.spawn_persistent_field(
        get_tree().current_scene,
        definition,
        world_position,
        radius,
        duration,
        is_remnant
    )
    _persistent_effects.append({
        "definition": definition,
        "position": world_position,
        "source": source,
        "context": context.duplicate(true),
        "remaining": duration,
        "tick": 0.0,
        "interval": definition.remnant_tick_interval if is_remnant else definition.persistent_tick_interval,
        "damage_multiplier": damage_multiplier,
        "radius": radius,
        "vfx_node": vfx_node,
    })


func _process_persistent(delta: float) -> void:
    for index: int in range(_persistent_effects.size() - 1, -1, -1):
        var effect := _persistent_effects[index]
        if int((effect["context"] as Dictionary).get("build_revision", -1)) != _build_revision:
            _free_persistent_vfx(effect)
            _persistent_effects.remove_at(index)
            continue
        effect["remaining"] = float(effect["remaining"]) - delta
        effect["tick"] = float(effect["tick"]) - delta
        if float(effect["tick"]) <= 0.0:
            effect["tick"] = float(effect["interval"])
            _damage_area(
                effect["definition"] as SkillDefinition,
                effect["position"] as Vector3,
                float(effect["radius"]),
                effect["source"] as Node3D,
                effect["context"] as Dictionary,
                float(effect["damage_multiplier"])
            )
        if float(effect["remaining"]) <= 0.0:
            _free_persistent_vfx(effect)
            _persistent_effects.remove_at(index)


func _free_persistent_vfx(effect: Dictionary) -> void:
    var vfx_node := effect.get("vfx_node") as Node
    if is_instance_valid(vfx_node):
        vfx_node.queue_free()


func _spawn_minion(
        definition: SkillDefinition,
        source: Node3D,
        origin: Vector3,
        context: Dictionary,
        index: int
) -> void:
    if _active_minions.size() >= MAX_ACTIVE_MINIONS:
        return
    var minion: SkillMinion
    if _minion_pool.is_empty():
        minion = MINION_SCRIPT.new()
        minion.attack_requested.connect(_on_minion_attack)
        minion.released.connect(_on_minion_released)
        get_tree().current_scene.add_child(minion)
    else:
        minion = _minion_pool.pop_back()
    minion.activate(definition, source, origin, context, TAU * float(index) / float(maxi(definition.instance_count, 1)))
    _active_minions.append(minion)


func _on_minion_attack(
        minion: SkillMinion,
        target: Node3D,
        definition: SkillDefinition,
        context: Dictionary
) -> void:
    var direction := target.global_position - minion.global_position
    direction.y = 0.0
    _deal_hit(definition, target, minion, context, direction.normalized(), 1.0, true)
    COMBAT_VFX.spawn_bolt(get_tree().current_scene, minion.global_position, target.global_position + Vector3.UP, definition.color)


func _on_minion_released(minion: SkillMinion) -> void:
    _active_minions.erase(minion)
    if minion not in _minion_pool:
        _minion_pool.append(minion)


func _process_scheduled(delta: float) -> void:
    for index: int in range(_scheduled_actions.size() - 1, -1, -1):
        var action := _scheduled_actions[index]
        action["remaining"] = float(action["remaining"]) - delta
        if float(action["remaining"]) > 0.0:
            continue
        _scheduled_actions.remove_at(index)
        var context := action["context"] as Dictionary
        if int(context.get("build_revision", -1)) != _build_revision:
            continue
        var definition := action["definition"] as SkillDefinition
        if StringName(action["kind"]) == &"cast":
            _execute_cast_wave(definition, action["origin"], action["direction"], action["source"], context)
        else:
            _free_scheduled_vfx(action)
            COMBAT_VFX.spawn_meteor_impact(
                get_tree().current_scene,
                action["origin"],
                definition.area_radius
            )
            _cast_direct_damage(definition, action["origin"], action["direction"], action["source"], context)


func _free_scheduled_vfx(action: Dictionary) -> void:
    var vfx := action.get("vfx") as Node3D
    if is_instance_valid(vfx):
        vfx.queue_free()


func _free_channel_sustain_vfx() -> void:
    if is_instance_valid(_channel_sustain_vfx):
        _channel_sustain_vfx.queue_free()
    _channel_sustain_vfx = null


func _deal_hit(
        definition: SkillDefinition,
        target: Node3D,
        source: Node3D,
        context: Dictionary,
        direction: Vector3,
        damage_multiplier: float = 1.0,
        emit_hit_event: bool = true
) -> void:
    if not _is_valid_damageable_target(target):
        return
    var critical := randf() <= definition.critical_chance
    var amount := definition.damage * float(context.get("damage_multiplier", 1.0)) * damage_multiplier
    if critical:
        amount *= definition.critical_multiplier
    var killed := bool(target.call("take_damage", amount, definition.element, critical, definition.color))
    _hit_visual_sequence += 1
    if _should_spawn_combat_visual(true):
        var source_position := source.global_position if is_instance_valid(source) else target.global_position - direction
        COMBAT_VFX.spawn_hit_layers(get_tree().current_scene, definition, target.global_position + Vector3.UP, source_position, direction)
    var events: Array[StringName] = []
    if emit_hit_event:
        events.append(&"hit")
        if critical:
            events.append(&"critical")
    if not killed:
        _apply_effects(definition, target, source, context, direction, events)
    if killed:
        events.append(&"kill")
    var report := context.duplicate(true)
    report["build_revision"] = _build_revision
    report["source_core_slot_index"] = definition.compiled_slot_index
    report["target_core_slot_index"] = definition.compiled_slot_index
    report["world_position"] = target.global_position
    report["target"] = target
    report["source"] = source
    report["generation"] = int(context.get("generation", 0))
    report["events"] = events
    report["critical"] = critical
    report["killed"] = killed
    report["amount"] = amount
    report["facing_direction"] = direction
    combat_report.emit(report)


func _apply_effects(
        definition: SkillDefinition,
        target: Node3D,
        source: Node3D,
        context: Dictionary,
        direction: Vector3,
        events: Array[StringName]
) -> void:
    var status_context := context.duplicate(true)
    status_context["source_core_slot_index"] = definition.compiled_slot_index
    status_context["generation"] = int(context.get("generation", 0))
    if definition.has_effect(&"ignite") and target.has_method("apply_ignite"):
        var ignite_dps := maxf(definition.burn_damage_per_second, definition.damage * 0.15)
        if bool(target.call("apply_ignite", definition.burn_duration, ignite_dps, status_context)):
            events.append(&"ignite")
    if definition.has_effect(&"poison") and target.has_method("apply_poison_stack"):
        target.call("apply_poison_stack", definition.poison_duration, maxf(definition.poison_damage_per_second, definition.damage * 0.08), definition.poison_max_stacks, status_context)
    if definition.has_effect(&"bleed") and target.has_method("apply_bleed"):
        target.call("apply_bleed", definition.bleed_duration, definition.damage * definition.bleed_damage_ratio, status_context)
    if definition.has_effect(&"freeze") and target.has_method("add_freeze_buildup"):
        if bool(target.call("add_freeze_buildup", definition.freeze_buildup * definition.ailment_buildup_multiplier, definition.freeze_duration)):
            events.append(&"freeze")
    if definition.has_effect(&"electrified") and target.has_method("apply_electrified"):
        if bool(target.call("apply_electrified", definition.shock_duration, definition.shock_damage_taken_multiplier)):
            events.append(&"electrified")
    if definition.has_effect(&"stun") and target.has_method("add_stun_buildup"):
        if bool(target.call("add_stun_buildup", definition.stun_buildup * definition.ailment_buildup_multiplier, 1.5)):
            events.append(&"stun")
    if definition.has_effect(&"knockback") and target.has_method("apply_displacement"):
        target.call("apply_displacement", direction, definition.knockback_distance)
    if definition.has_effect(&"pull") and target.has_method("apply_displacement"):
        var pull_direction := Vector3.ZERO
        if is_instance_valid(source):
            pull_direction = source.global_position - target.global_position
            pull_direction.y = 0.0
        target.call("apply_displacement", pull_direction.normalized(), definition.pull_distance)


func _chain_from(
        definition: SkillDefinition,
        first_target: Node3D,
        source: Node3D,
        context: Dictionary,
        excluded_ids: Dictionary
) -> void:
    var current := first_target
    var multiplier := definition.chain_damage_multiplier if definition.chain_damage_multiplier > 0.0 else 0.78
    for jump_index: int in definition.chain_count:
        var next_target := _find_nearest_target(current.global_position, definition.chain_range, excluded_ids)
        if next_target == null:
            break
        excluded_ids[next_target.get_instance_id()] = true
        COMBAT_VFX.spawn_chain_lightning(
            get_tree().current_scene,
            current.global_position + Vector3.UP,
            next_target.global_position + Vector3.UP,
            definition.color,
            absi(hash([int(context.get("cast_id", 0)), jump_index + 1]))
        )
        var direction := next_target.global_position - current.global_position
        direction.y = 0.0
        _deal_hit(definition, next_target, source, context, direction.normalized(), pow(multiplier, jump_index + 1))
        current = next_target


func _damage_area(
        definition: SkillDefinition,
        centre: Vector3,
        radius: float,
        source: Node3D,
        context: Dictionary,
        damage_multiplier: float,
        excluded_target: Node3D = null
) -> void:
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D:
            continue
        var target := candidate as Node3D
        if target == excluded_target:
            continue
        if target.global_position.distance_to(centre) <= radius:
            var direction := target.global_position - centre
            direction.y = 0.0
            _deal_hit(definition, target, source, context, direction.normalized(), damage_multiplier, definition.has_tag(&"hit"))


func _get_shape_targets(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        aim_position: Vector3
) -> Array[Node3D]:
    if definition.shape_type == &"tracking":
        var tracking := _get_tracking_target(definition, origin, aim_position)
        return [tracking] if tracking != null else []
    var result: Array[Node3D] = []
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D or not _is_valid_damageable_target(candidate as Node3D):
            continue
        var target := candidate as Node3D
        var offset := target.global_position - origin
        offset.y = 0.0
        var distance := offset.length()
        var forward := offset.dot(facing_direction)
        var lateral := absf(offset.cross(facing_direction).y)
        var matches := false
        match definition.shape_type:
            &"circle", &"rotate":
                matches = distance <= definition.area_radius
            &"cone":
                matches = distance <= definition.area_radius and forward > 0.0 and facing_direction.angle_to(offset.normalized()) <= deg_to_rad(maxf(definition.spread_degrees, 50.0) * 0.5)
            _:
                var line_range := definition.target_range if definition.target_range > 0.0 else maxf(definition.area_radius, 6.0)
                matches = forward >= 0.0 and forward <= line_range and lateral <= 0.85 * definition.width_multiplier
        if matches:
            result.append(target)
    return result


func _get_tracking_target(definition: SkillDefinition, origin: Vector3, aim_position: Vector3) -> Node3D:
    var best: Node3D
    var best_aim_distance := INF
    var maximum_range := definition.target_range if definition.target_range > 0.0 else 14.0
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D or not _is_valid_damageable_target(candidate as Node3D):
            continue
        var target := candidate as Node3D
        if target.global_position.distance_to(origin) > maximum_range:
            continue
        var distance := target.global_position.distance_to(aim_position)
        if distance < best_aim_distance:
            best = target
            best_aim_distance = distance
    return best


func _find_nearest_target(from_position: Vector3, maximum_distance: float, excluded_ids: Dictionary) -> Node3D:
    var nearest: Node3D
    var nearest_distance := maximum_distance
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D or excluded_ids.has(candidate.get_instance_id()) or not _is_valid_damageable_target(candidate as Node3D):
            continue
        var distance := (candidate as Node3D).global_position.distance_to(from_position)
        if distance < nearest_distance:
            nearest = candidate as Node3D
            nearest_distance = distance
    return nearest


func _is_valid_damageable_target(target: Node3D) -> bool:
    return is_instance_valid(target) and target.is_in_group("damageable") and (not target.has_method("is_alive") or bool(target.call("is_alive")))


func _on_projectile_event(message: String, event_color: Color) -> void:
    event_fired.emit(message, event_color)


func _should_spawn_combat_visual(is_hit: bool) -> bool:
    var active_count := get_active_projectile_count()
    var divisor := 1
    if active_count > 160:
        divisor = 12
    elif active_count > 64:
        divisor = 6
    elif active_count > 24:
        divisor = 3
    var sequence := _hit_visual_sequence if is_hit else _cast_visual_sequence
    return sequence % divisor == 0
