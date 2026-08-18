class_name ProjectileManager
extends Node

signal projectile_impact(projectile: SkillProjectile, target: Node3D)
signal projectile_expiry_burst(projectile: SkillProjectile, world_position: Vector3)
signal projectile_returned(projectile: SkillProjectile)
signal projectile_remnant(projectile: SkillProjectile, world_position: Vector3)
signal projectile_event(message: String, event_color: Color)

const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const MAX_ACTIVE_PROJECTILES: int = 384
const MAX_RICH_VISUAL_PROJECTILES: int = 8

var rejected_requests: int = 0
var peak_active_count: int = 0
var suppressed_visual_requests: int = 0
var _active: Dictionary = {}
var _pool: Array[SkillProjectile] = []
var _spawn_sequence: int = 0


func request_projectile(
        parent: Node,
        definition: SkillDefinition,
        source: Node3D,
        origin: Vector3,
        direction: Vector3,
        context: Dictionary,
        can_split: bool = true
) -> SkillProjectile:
    if _active.size() >= MAX_ACTIVE_PROJECTILES:
        rejected_requests += 1
        return null
    var projectile: SkillProjectile
    if _pool.is_empty():
        projectile = PROJECTILE_SCRIPT.new()
        projectile.impact_requested.connect(_on_impact_requested)
        projectile.expiry_burst_requested.connect(_on_expiry_burst_requested)
        projectile.return_completed.connect(_on_return_completed)
        projectile.remnant_requested.connect(_on_remnant_requested)
        projectile.released.connect(_on_projectile_released)
        projectile.event_fired.connect(_on_projectile_event)
        parent.add_child(projectile)
    else:
        projectile = _pool.pop_back()
    _spawn_sequence += 1
    var enable_visual_effects := _active.size() < MAX_RICH_VISUAL_PROJECTILES
    if not enable_visual_effects:
        suppressed_visual_requests += 1
    projectile.activate(
        definition,
        source,
        origin,
        direction,
        context,
        can_split,
        enable_visual_effects
    )
    _active[projectile.get_instance_id()] = projectile
    _rebalance_visual_density()
    peak_active_count = maxi(peak_active_count, _active.size())
    return projectile


func get_active_count() -> int:
    return _active.size()


func get_pool_count() -> int:
    return _pool.size()


func clear_active() -> void:
    var projectiles: Array = _active.values()
    for raw_projectile: Variant in projectiles:
        var projectile := raw_projectile as SkillProjectile
        if projectile != null:
            projectile.deactivate()


func _on_impact_requested(projectile: SkillProjectile, target: Node3D) -> void:
    projectile_impact.emit(projectile, target)


func _on_expiry_burst_requested(projectile: SkillProjectile, world_position: Vector3) -> void:
    projectile_expiry_burst.emit(projectile, world_position)


func _on_return_completed(projectile: SkillProjectile) -> void:
    projectile_returned.emit(projectile)


func _on_remnant_requested(projectile: SkillProjectile, world_position: Vector3) -> void:
    projectile_remnant.emit(projectile, world_position)


func _on_projectile_released(projectile: SkillProjectile) -> void:
    _active.erase(projectile.get_instance_id())
    _rebalance_visual_density()
    if projectile not in _pool:
        _pool.append(projectile)


func _on_projectile_event(message: String, event_color: Color) -> void:
    projectile_event.emit(message, event_color)


func _rebalance_visual_density() -> void:
    var index := 0
    for raw_projectile: Variant in _active.values():
        var projectile := raw_projectile as SkillProjectile
        if projectile != null:
            projectile.set_visual_effects_enabled(index < MAX_RICH_VISUAL_PROJECTILES)
        index += 1
