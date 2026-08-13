class_name SkillRuntime
extends Node3D

signal event_fired(message: String, event_color: Color)
signal hit_report(report: Dictionary)

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const PROJECTILE_MANAGER_SCRIPT := preload("res://scripts/projectile_manager.gd")

var _graph_revision: int = 0
var _projectile_manager: ProjectileManager
var _cast_visual_sequence: int = 0
var _hit_visual_sequence: int = 0


func _ready() -> void:
    _projectile_manager = PROJECTILE_MANAGER_SCRIPT.new()
    _projectile_manager.projectile_impact.connect(_on_projectile_impact)
    _projectile_manager.projectile_event.connect(_on_projectile_event)
    add_child(_projectile_manager)


func set_graph_revision(revision: int) -> void:
    _graph_revision = revision
    if _projectile_manager != null:
        _projectile_manager.clear_active()


func get_active_projectile_count() -> int:
    return _projectile_manager.get_active_count() if _projectile_manager != null else 0


func get_projectile_pool_count() -> int:
    return _projectile_manager.get_pool_count() if _projectile_manager != null else 0


func get_rejected_projectile_count() -> int:
    return _projectile_manager.rejected_requests if _projectile_manager != null else 0


func cast_skill(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    if definition == null or int(context.get("graph_revision", -1)) != _graph_revision:
        return
    event_fired.emit("施放 → %s" % definition.display_name, definition.color)
    for repeat_index: int in definition.repeat_count:
        if repeat_index > 0:
            await get_tree().create_timer(definition.repeat_interval).timeout
            if not is_instance_valid(source) or int(context.get("graph_revision", -1)) != _graph_revision:
                return
            event_fired.emit(
                "%s → 第 %d/%d 段" % [
                    "連擊" if definition.has_modifier(&"combo") else "連射",
                    repeat_index + 1,
                    definition.repeat_count,
                ],
                definition.color
            )
        if _should_spawn_combat_visual(false):
            COMBAT_VFX.spawn_cast_layers(get_tree().current_scene, definition, origin, facing_direction)
        match definition.action_type:
            &"damage":
                _cast_direct_damage(definition, origin, facing_direction, source, context)
            &"summon":
                await _cast_summon(definition, origin, facing_direction, source, context)
            &"projectile":
                _spawn_shape_projectiles(definition, origin, facing_direction, source, context)


func _spawn_shape_projectiles(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary,
        can_split: bool = true
) -> void:
    if definition.radial:
        for index: int in definition.projectile_count:
            var angle := TAU * float(index) / float(definition.projectile_count)
            _spawn_projectile(
                definition,
                origin,
                Vector3.FORWARD.rotated(Vector3.UP, angle),
                source,
                context,
                can_split
            )
        return
    var start_angle := -definition.spread_degrees * 0.5
    var step := definition.spread_degrees / float(definition.projectile_count - 1) if definition.projectile_count > 1 else 0.0
    for index: int in definition.projectile_count:
        var angle_degrees := start_angle + step * float(index)
        _spawn_projectile(
            definition,
            origin,
            facing_direction.rotated(Vector3.UP, deg_to_rad(angle_degrees)),
            source,
            context,
            can_split
        )


func _spawn_projectile(
        definition: SkillDefinition,
        origin: Vector3,
        direction: Vector3,
        source: Node3D,
        context: Dictionary,
        can_split: bool
) -> void:
    _projectile_manager.request_projectile(
        get_tree().current_scene,
        definition,
        source,
        origin,
        direction,
        context,
        can_split
    )


func _cast_direct_damage(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    if definition.active_skill_id == &"thunder_orb":
        _cast_thunder_chain(definition, origin, facing_direction, source, context)
        return
    if definition.has_tag(&"melee") and definition.shape_type == &"tracking":
        _perform_melee_lunge(source, origin)
        origin = source.global_position if is_instance_valid(source) else origin
    var aim_position := context.get("aim_position", origin + facing_direction * 5.0) as Vector3
    var targets := _get_shape_targets(definition, origin, facing_direction, aim_position)
    for target: Node3D in targets:
        var direction := _flat_direction(origin, target.global_position, facing_direction)
        _deal_hit(definition, target, source, context, 1.0, &"direct", direction)
    COMBAT_VFX.spawn_pulse(
        get_tree().current_scene,
        origin + Vector3.UP * 0.5,
        definition.color,
        2.5 if definition.shape_type in [&"circle", &"rotate"] else 1.2
    )


func _cast_thunder_chain(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    var aim_position := context.get("aim_position", origin + facing_direction * definition.target_range) as Vector3
    var targets := _get_shape_targets(definition, origin, facing_direction, aim_position)
    if targets.is_empty():
        COMBAT_VFX.spawn_pulse(get_tree().current_scene, origin, definition.color, 0.35)
        event_fired.emit("雷光球 → 無有效目標", definition.color.darkened(0.15))
        return

    var chain_key := definition.get_operation_key(&"modifier_chain")
    var primary_context := _context_with_operation(context, chain_key, false)
    var chain_context := _context_with_operation(context, chain_key)
    var excluded_ids: Dictionary = {}
    var cast_id := int(context.get("cast_id", 0))
    for index: int in targets.size():
        var target := targets[index]
        excluded_ids[target.get_instance_id()] = true
        var hit_direction := _flat_direction(origin, target.global_position, facing_direction)
        COMBAT_VFX.spawn_chain_lightning(
            get_tree().current_scene,
            origin,
            target.global_position + Vector3.UP,
            definition.color,
            cast_id * 131 + index
        )
        _deal_hit(definition, target, source, primary_context, 1.0, &"direct", hit_direction)

    if definition.chain_count > 0:
        _chain_from(
            definition,
            targets[0],
            source,
            chain_context,
            facing_direction,
            excluded_ids
        )


func _cast_summon(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    for wave: int in 3:
        if int(context.get("graph_revision", -1)) != _graph_revision:
            return
        var summon_origin := _summon_origin(definition.shape_type, origin, facing_direction, wave)
        COMBAT_VFX.spawn_pulse(get_tree().current_scene, summon_origin, definition.color, 0.7)
        _spawn_shape_projectiles(definition, summon_origin, facing_direction, source, context)
        if wave < 2:
            await get_tree().create_timer(0.18).timeout


func _summon_origin(
        pattern: StringName,
        origin: Vector3,
        facing_direction: Vector3,
        wave: int
) -> Vector3:
    match pattern:
        &"circle":
            return origin + Vector3.FORWARD.rotated(Vector3.UP, TAU * float(wave) / 3.0) * 1.5 + Vector3.UP * 0.35
        &"cone":
            return origin + facing_direction.rotated(Vector3.UP, deg_to_rad(-26.0 + 26.0 * wave)) * 1.2 + Vector3.UP * 0.35
        &"line":
            return origin + facing_direction * (0.7 + 0.7 * wave) + Vector3.UP * 0.35
        _:
            var angle := TAU * float(wave) / 3.0
            return origin + Vector3(cos(angle), 0.35, sin(angle)) * 1.3


func _get_shape_targets(
        definition: SkillDefinition,
        origin: Vector3,
        facing_direction: Vector3,
        aim_position: Vector3
) -> Array[Node3D]:
    var matches: Array[Node3D] = []
    if definition.shape_type == &"tracking":
        var tracking_target := _get_tracking_target(definition, origin, aim_position)
        if tracking_target != null:
            matches.append(tracking_target)
        return matches
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D or not _is_valid_damageable_target(candidate as Node3D):
            continue
        var target := candidate as Node3D
        var offset := target.global_position - origin
        offset.y = 0.0
        var distance := offset.length()
        var forward_distance := offset.dot(facing_direction)
        var lateral_distance := absf(offset.cross(facing_direction).y)
        var is_match := false
        match definition.shape_type:
            &"circle":
                is_match = distance <= definition.area_radius
            &"cone":
                is_match = distance <= 8.5 and forward_distance > 0.0 and facing_direction.angle_to(offset.normalized()) <= deg_to_rad(31.0)
            &"rotate":
                is_match = distance <= 6.0
            &"line":
                is_match = forward_distance >= 0.0 and forward_distance <= 11.0 and lateral_distance <= 0.85
        if is_match:
            matches.append(target)
    matches.sort_custom(func(left: Node3D, right: Node3D) -> bool:
        var left_distance := left.global_position.distance_squared_to(origin)
        var right_distance := right.global_position.distance_squared_to(origin)
        if is_equal_approx(left_distance, right_distance):
            return left.get_instance_id() < right.get_instance_id()
        return left_distance < right_distance
    )
    return matches


func _get_tracking_target(
        definition: SkillDefinition,
        origin: Vector3,
        aim_position: Vector3
) -> Node3D:
    var maximum_range := definition.target_range if definition.target_range > 0.0 else INF
    var snap_radius := definition.target_snap_radius if definition.target_snap_radius > 0.0 else INF
    var nearest: Node3D
    var nearest_aim_distance := INF
    var nearest_origin_distance := INF
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D:
            continue
        var target := candidate as Node3D
        if not _is_valid_damageable_target(target):
            continue
        var origin_offset := target.global_position - origin
        origin_offset.y = 0.0
        var origin_distance := origin_offset.length()
        if origin_distance > maximum_range:
            continue
        var aim_offset := target.global_position - aim_position
        aim_offset.y = 0.0
        var aim_distance := aim_offset.length()
        if aim_distance > snap_radius:
            continue
        var is_better := aim_distance < nearest_aim_distance
        if is_equal_approx(aim_distance, nearest_aim_distance):
            is_better = origin_distance < nearest_origin_distance
            if is_equal_approx(origin_distance, nearest_origin_distance) and nearest != null:
                is_better = target.get_instance_id() < nearest.get_instance_id()
        if is_better:
            nearest = target
            nearest_aim_distance = aim_distance
            nearest_origin_distance = origin_distance
    return nearest


func _perform_melee_lunge(source: Node3D, origin: Vector3) -> void:
    if not is_instance_valid(source):
        return
    var target := _find_nearest_target(origin, 8.0, {})
    if target == null:
        return
    var offset := target.global_position - source.global_position
    offset.y = 0.0
    if offset.length() > 1.7:
        source.global_position += offset.normalized() * minf(offset.length() - 1.7, 1.4)
    COMBAT_VFX.spawn_bolt(
        get_tree().current_scene,
        origin + Vector3.UP,
        target.global_position + Vector3.UP,
        Color("d9e2ec")
    )


func _on_projectile_impact(projectile: SkillProjectile, target: Node3D) -> void:
    if projectile == null or not is_instance_valid(target):
        return
    var definition := projectile.definition
    var context := projectile.context
    var hit_direction := projectile.direction
    _deal_hit(definition, target, projectile.source, context, 1.0, &"projectile", hit_direction)
    event_fired.emit(
        "%s → %s" % ["命中", definition.display_name],
        definition.color
    )
    var split_key := definition.get_operation_key(&"modifier_split")
    if projectile.can_split and definition.split_count > 0 and split_key not in context.get("applied_operations", []):
        _spawn_split_projectiles(
            definition,
            target.global_position + Vector3.UP * 0.35,
            hit_direction,
            projectile.source,
            _context_with_operation(context, split_key)
        )
    projectile.resolve_impact(target)


func _deal_hit(
        definition: SkillDefinition,
        target: Node3D,
        source: Node3D,
        context: Dictionary,
        damage_multiplier: float,
        damage_source: StringName,
        hit_direction: Vector3
) -> void:
    if not is_instance_valid(target) or not target.has_method("take_damage"):
        return
    var critical := randf() <= definition.critical_chance
    var amount := definition.damage * damage_multiplier
    if critical:
        amount *= definition.critical_multiplier
    var health_before := float(target.get("health"))
    var killed := bool(target.call("take_damage", amount, definition.element, critical, definition.color))
    var actual_damage := minf(amount, maxf(health_before, 0.0))
    _apply_status_effects(definition, target, context)
    if definition.lifesteal_ratio > 0.0 and is_instance_valid(source) and source.has_method("heal"):
        source.call("heal", actual_damage * definition.lifesteal_ratio)
    var source_position := source.global_position + Vector3.UP if is_instance_valid(source) else target.global_position + Vector3.UP
    if _should_spawn_combat_visual(true):
        COMBAT_VFX.spawn_hit_layers(
            get_tree().current_scene,
            definition,
            target.global_position + Vector3.UP,
            source_position,
            hit_direction
        )
    hit_report.emit({
        "cast_id": int(context.get("cast_id", 0)),
        "graph_revision": int(context.get("graph_revision", 0)),
        "source_skill_node_id": int(context.get("source_skill_node_id", -1)),
        "world_position": target.global_position,
        "target": target,
        "source": source,
        "damage_source": damage_source,
        "depth": int(context.get("depth", 0)),
        "applied_operations": context.get("applied_operations", []).duplicate(),
        "critical": critical,
        "killed": killed,
        "amount": actual_damage,
    })
    event_fired.emit("%s → %s" % ["暴擊命中" if critical else "命中", definition.display_name], definition.color)
    _apply_secondary_operations(definition, target, source, context, hit_direction)


func _apply_status_effects(
        definition: SkillDefinition,
        target: Node3D,
        context: Dictionary
) -> void:
    if definition.burn_duration > 0.0 and target.has_method("apply_burn"):
        target.call("apply_burn", definition.burn_duration, definition.burn_damage_per_second, context)
    if definition.poison_duration > 0.0 and target.has_method("apply_poison"):
        target.call("apply_poison", definition.poison_duration, definition.poison_damage_per_second, context)
    if definition.freeze_duration > 0.0 and target.has_method("apply_freeze"):
        target.call("apply_freeze", definition.freeze_duration)


func _apply_secondary_operations(
        definition: SkillDefinition,
        primary_target: Node3D,
        source: Node3D,
        context: Dictionary,
        hit_direction: Vector3
) -> void:
    var operations: Array = context.get("applied_operations", [])
    var splash_key := definition.get_operation_key(&"modifier_splash")
    if definition.splash_radius > 0.0 and splash_key not in operations:
        _damage_area(
            definition,
            primary_target.global_position,
            primary_target,
            source,
            _context_with_operation(context, splash_key),
            definition.splash_radius,
            definition.splash_damage_multiplier,
            &"splash"
        )
        event_fired.emit("命中改造 → 擴散傷害", definition.color)
    var explosion_key := definition.get_operation_key(&"effect_explosion")
    if definition.explosion_radius > 0.0 and explosion_key not in operations:
        _damage_area(
            definition,
            primary_target.global_position,
            primary_target,
            source,
            _context_with_operation(context, explosion_key),
            definition.explosion_radius,
            definition.explosion_damage_multiplier,
            &"explosion"
        )
        event_fired.emit("後續效果 → 範圍爆炸", definition.color)
    var chain_key := definition.get_operation_key(&"modifier_chain")
    if definition.chain_count > 0 and chain_key not in operations:
        _chain_from(
            definition,
            primary_target,
            source,
            _context_with_operation(context, chain_key),
            hit_direction
        )


func _damage_area(
        definition: SkillDefinition,
        center: Vector3,
        primary_target: Node3D,
        source: Node3D,
        context: Dictionary,
        radius: float,
        multiplier: float,
        damage_source: StringName
) -> void:
    COMBAT_VFX.spawn_pulse(get_tree().current_scene, center + Vector3.UP, definition.color, radius)
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D or candidate == primary_target:
            continue
        var target := candidate as Node3D
        if target.global_position.distance_to(center) <= radius:
            _deal_hit(
                definition,
                target,
                source,
                context,
                multiplier,
                damage_source,
                _flat_direction(center, target.global_position, Vector3.FORWARD)
            )


func _chain_from(
        definition: SkillDefinition,
        first_target: Node3D,
        source: Node3D,
        context: Dictionary,
        fallback_direction: Vector3,
        initial_excluded_ids: Dictionary = {}
) -> void:
    var excluded := initial_excluded_ids.duplicate()
    excluded[first_target.get_instance_id()] = true
    var current := first_target
    var multiplier := definition.chain_damage_multiplier
    var completed_jumps := 0
    for jump_index: int in definition.chain_count:
        var next_target := _find_nearest_target(current.global_position, definition.chain_range, excluded)
        if next_target == null:
            break
        excluded[next_target.get_instance_id()] = true
        COMBAT_VFX.spawn_chain_lightning(
            get_tree().current_scene,
            current.global_position + Vector3.UP,
            next_target.global_position + Vector3.UP,
            definition.color,
            int(context.get("cast_id", 0)) * 131 + jump_index + 41
        )
        _deal_hit(
            definition,
            next_target,
            source,
            context,
            multiplier,
            &"chain",
            _flat_direction(current.global_position, next_target.global_position, fallback_direction)
        )
        current = next_target
        multiplier *= 0.82
        completed_jumps += 1
    if completed_jumps > 0:
        event_fired.emit("後續效果 → 連鎖 %d 跳" % completed_jumps, definition.color)


func _spawn_split_projectiles(
        definition: SkillDefinition,
        origin: Vector3,
        forward_direction: Vector3,
        source: Node3D,
        context: Dictionary
) -> void:
    var count := definition.split_count
    var spread := 38.0
    var step := spread / float(maxi(count - 1, 1))
    var start := -spread * 0.5
    for index: int in count:
        var angle := 0.0 if count == 1 else start + step * float(index)
        _spawn_projectile(
            definition,
            origin,
            forward_direction.rotated(Vector3.UP, deg_to_rad(angle)),
            source,
            context,
            false
        )
    event_fired.emit("命中分裂 → %d 道子攻擊" % count, definition.color)


func _context_with_operation(
        context: Dictionary,
        operation_key: StringName,
        increment_depth: bool = true
) -> Dictionary:
    var result := context.duplicate(true)
    var operations: Array[StringName] = []
    operations.assign(context.get("applied_operations", []))
    if operation_key not in operations:
        operations.append(operation_key)
    result["applied_operations"] = operations
    result["depth"] = int(context.get("depth", 0)) + (1 if increment_depth else 0)
    return result


func _find_nearest_target(
        from_position: Vector3,
        maximum_distance: float,
        excluded_ids: Dictionary
) -> Node3D:
    var nearest: Node3D
    var nearest_distance := maximum_distance
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D or excluded_ids.has(candidate.get_instance_id()):
            continue
        var target := candidate as Node3D
        if not _is_valid_damageable_target(target):
            continue
        var distance := target.global_position.distance_to(from_position)
        if distance < nearest_distance or (
                is_equal_approx(distance, nearest_distance)
                and nearest != null
                and target.get_instance_id() < nearest.get_instance_id()
        ):
            nearest = target
            nearest_distance = distance
    return nearest


func _is_valid_damageable_target(target: Node3D) -> bool:
    if not is_instance_valid(target) or not target.is_in_group("damageable"):
        return false
    if target.has_method("is_alive"):
        return bool(target.call("is_alive"))
    if target is CollisionObject3D:
        return (target as CollisionObject3D).collision_layer != 0
    return true


func _flat_direction(from_position: Vector3, to_position: Vector3, fallback: Vector3) -> Vector3:
    var result := to_position - from_position
    result.y = 0.0
    return result.normalized() if result.length_squared() > 0.01 else fallback


func _on_projectile_event(message: String, event_color: Color) -> void:
    event_fired.emit(message, event_color)


func _should_spawn_combat_visual(is_hit: bool) -> bool:
    var active_count := get_active_projectile_count()
    var divisor := 1
    if active_count >= 288:
        divisor = 16
    elif active_count >= 192:
        divisor = 4
    elif active_count >= 96:
        divisor = 2
    if is_hit:
        _hit_visual_sequence += 1
        return _hit_visual_sequence % divisor == 0
    _cast_visual_sequence += 1
    return _cast_visual_sequence % divisor == 0
