class_name TrainingDummy
extends StaticBody3D

signal dot_killed(context: Dictionary, world_position: Vector3, target: Node3D)

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")

@export var dummy_index: int = 1
@export var max_health: float = 320.0

var health: float = 320.0
var _dead: bool = false
var _burn_remaining: float = 0.0
var _burn_damage_per_second: float = 0.0
var _burn_tick: float = 1.0
var _burn_context: Dictionary = {}
var _poison_remaining: float = 0.0
var _poison_damage_per_second: float = 0.0
var _poison_tick: float = 1.0
var _poison_context: Dictionary = {}
var _freeze_remaining: float = 0.0
var _body_material: StandardMaterial3D
var _health_label: Label3D
var _visual_root: Node3D
var _hit_tween: Tween


func _ready() -> void:
    add_to_group("damageable")
    collision_layer = 2
    collision_mask = 0
    health = max_health
    _build_visuals()
    _update_label()


func _process(delta: float) -> void:
    if _dead:
        return

    if _burn_remaining > 0.0:
        _burn_remaining = maxf(_burn_remaining - delta, 0.0)
        _burn_tick -= delta
        if _burn_tick <= 0.0:
            _burn_tick += 1.0
            if take_damage(_burn_damage_per_second, &"burn", false, Color("ff9b55")):
                dot_killed.emit(_burn_context.duplicate(true), global_position, self)

    if _poison_remaining > 0.0:
        _poison_remaining = maxf(_poison_remaining - delta, 0.0)
        _poison_tick -= delta
        if _poison_tick <= 0.0:
            _poison_tick += 1.0
            if take_damage(_poison_damage_per_second, &"poison", false, Color("85e05d")):
                dot_killed.emit(_poison_context.duplicate(true), global_position, self)

    _freeze_remaining = maxf(_freeze_remaining - delta, 0.0)
    _update_label()


func take_damage(
        amount: float,
        _element: StringName = &"arcane",
        critical: bool = false,
        hit_color: Color = Color.WHITE
) -> bool:
    if _dead or amount <= 0.0:
        return false

    health = maxf(health - amount, 0.0)
    var scene_root := get_tree().current_scene
    COMBAT_VFX.spawn_damage_number(
        self,
        global_position + Vector3(0.0, 3.35, 0.0),
        amount,
        hit_color,
        critical
    )
    COMBAT_VFX.spawn_pulse(
        scene_root,
        global_position + Vector3(0.0, 1.1, 0.0),
        hit_color,
        0.7 if critical else 0.45
    )
    _animate_hit(hit_color, critical)
    _update_label()

    if health <= 0.0:
        _begin_respawn()
        return true
    return false


func apply_burn(duration: float, damage_per_second: float, context: Dictionary = {}) -> void:
    _burn_remaining = maxf(_burn_remaining, duration)
    _burn_damage_per_second = maxf(_burn_damage_per_second, damage_per_second)
    _burn_tick = minf(_burn_tick, 0.25)
    _burn_context = context.duplicate(true)


func apply_poison(duration: float, damage_per_second: float, context: Dictionary = {}) -> void:
    _poison_remaining = maxf(_poison_remaining, duration)
    _poison_damage_per_second = maxf(_poison_damage_per_second, damage_per_second)
    _poison_tick = minf(_poison_tick, 0.25)
    _poison_context = context.duplicate(true)


func apply_freeze(duration: float) -> void:
    _freeze_remaining = maxf(_freeze_remaining, duration)


func has_status(status: StringName) -> bool:
    match status:
        &"burn":
            return _burn_remaining > 0.0
        &"poison":
            return _poison_remaining > 0.0
        &"frozen":
            return _freeze_remaining > 0.0
    return true


func is_alive() -> bool:
    return not _dead and health > 0.0


func reset_dummy() -> void:
    health = max_health
    _dead = false
    _burn_remaining = 0.0
    _burn_damage_per_second = 0.0
    _burn_tick = 1.0
    _burn_context.clear()
    _poison_remaining = 0.0
    _poison_damage_per_second = 0.0
    _poison_tick = 1.0
    _poison_context.clear()
    _freeze_remaining = 0.0
    collision_layer = 2
    if _body_material != null:
        _body_material.albedo_color = Color("9b5d37")
        _body_material.emission_energy_multiplier = 0.0
    if _visual_root != null:
        _visual_root.scale = Vector3.ONE
        _visual_root.rotation = Vector3.ZERO
    _update_label()


func _begin_respawn() -> void:
    if _dead:
        return
    _dead = true
    collision_layer = 0
    _body_material.albedo_color = Color("51473f")
    var collapse_tween := create_tween()
    collapse_tween.set_trans(Tween.TRANS_BACK)
    collapse_tween.tween_property(_visual_root, "scale", Vector3(1.18, 0.14, 1.18), 0.17)
    _health_label.text = "Dummy %02d\nRespawning..." % dummy_index
    await get_tree().create_timer(1.5).timeout
    reset_dummy()


func _update_label() -> void:
    if _health_label == null or _dead:
        return
    var statuses: PackedStringArray = []
    if _burn_remaining > 0.0:
        statuses.append("Burning %.1fs" % _burn_remaining)
    if _poison_remaining > 0.0:
        statuses.append("Poisoned %.1fs" % _poison_remaining)
    if _freeze_remaining > 0.0:
        statuses.append("Frozen %.1fs" % _freeze_remaining)
    if is_equal_approx(health, max_health) and statuses.is_empty():
        _health_label.text = ""
        return
    var status_text := "\n" + " / ".join(statuses) if not statuses.is_empty() else ""
    _health_label.text = "HP %.0f / %.0f%s" % [health, max_health, status_text]


func _build_visuals() -> void:
    _visual_root = Node3D.new()
    add_child(_visual_root)

    _body_material = StandardMaterial3D.new()
    _body_material.albedo_color = Color("9b5d37")
    _body_material.roughness = 0.92

    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.46
    trunk_mesh.bottom_radius = 0.58
    trunk_mesh.height = 2.2
    trunk.mesh = trunk_mesh
    trunk.material_override = _body_material
    trunk.position.y = 1.1
    _visual_root.add_child(trunk)

    var crossbar := MeshInstance3D.new()
    var crossbar_mesh := BoxMesh.new()
    crossbar_mesh.size = Vector3(1.7, 0.24, 0.28)
    crossbar.mesh = crossbar_mesh
    crossbar.material_override = _body_material
    crossbar.position.y = 1.55
    _visual_root.add_child(crossbar)

    var cap := MeshInstance3D.new()
    var cap_mesh := CylinderMesh.new()
    cap_mesh.top_radius = 0.5
    cap_mesh.bottom_radius = 0.5
    cap_mesh.height = 0.08
    cap.mesh = cap_mesh
    cap.material_override = _body_material
    cap.position.y = 2.2
    _visual_root.add_child(cap)

    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 0.6
    shape.height = 2.2
    collision.shape = shape
    collision.position.y = 1.1
    add_child(collision)

    _health_label = Label3D.new()
    _health_label.font_size = 24
    _health_label.outline_size = 7
    _health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _health_label.no_depth_test = true
    _health_label.position.y = 3.0
    add_child(_health_label)


func _animate_hit(hit_color: Color, critical: bool) -> void:
    if _hit_tween != null and _hit_tween.is_valid():
        _hit_tween.kill()
    _body_material.emission_enabled = true
    _body_material.emission = hit_color.lightened(0.2)
    _body_material.emission_energy_multiplier = 3.1 if critical else 1.8
    _visual_root.scale = (
        Vector3(1.16, 0.82, 1.16)
        if critical
        else Vector3(1.07, 0.92, 1.07)
    )
    _visual_root.rotation_degrees = Vector3(
        randf_range(-4.0, 4.0),
        0.0,
        randf_range(-7.0, 7.0)
    )

    _hit_tween = create_tween()
    _hit_tween.set_parallel(true)
    _hit_tween.set_trans(Tween.TRANS_BACK)
    _hit_tween.set_ease(Tween.EASE_OUT)
    _hit_tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.16)
    _hit_tween.tween_property(_visual_root, "rotation", Vector3.ZERO, 0.16)
    _hit_tween.tween_property(_body_material, "emission_energy_multiplier", 0.0, 0.13)
