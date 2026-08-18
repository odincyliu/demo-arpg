class_name SkillMinion
extends Node3D

signal attack_requested(minion: SkillMinion, target: Node3D, definition: SkillDefinition, context: Dictionary)
signal released(minion: SkillMinion)

var definition: SkillDefinition
var owner_source: Node3D
var context: Dictionary = {}
var _remaining: float = 0.0
var _attack_remaining: float = 0.0
var _orbit_phase: float = 0.0
var _active: bool = false


func _ready() -> void:
    _build_visual()
    set_physics_process(false)


func activate(
        new_definition: SkillDefinition,
        source: Node3D,
        origin: Vector3,
        new_context: Dictionary,
        orbit_phase: float
) -> void:
    definition = new_definition
    owner_source = source
    context = new_context.duplicate(true)
    global_position = origin
    _remaining = definition.summon_duration
    _attack_remaining = 0.15
    _orbit_phase = orbit_phase
    _active = true
    visible = true
    set_physics_process(true)
    add_to_group("skill_minion")


func deactivate() -> void:
    if not _active:
        return
    _active = false
    visible = false
    set_physics_process(false)
    remove_from_group("skill_minion")
    released.emit(self)


func _physics_process(delta: float) -> void:
    if not _active or definition == null or not is_instance_valid(owner_source):
        deactivate()
        return
    _remaining -= delta
    if _remaining <= 0.0:
        deactivate()
        return
    _orbit_phase += delta * 0.75
    var desired := owner_source.global_position + Vector3(
        cos(_orbit_phase) * 2.1,
        1.25 + sin(_orbit_phase * 1.7) * 0.18,
        sin(_orbit_phase) * 2.1
    )
    global_position = global_position.lerp(desired, 1.0 - exp(-5.5 * delta))
    _attack_remaining -= delta
    if _attack_remaining <= 0.0:
        _attack_remaining += definition.summon_attack_interval
        var target := _nearest_target(11.0)
        if target != null:
            attack_requested.emit(self, target, definition, context)


func _nearest_target(maximum_distance: float) -> Node3D:
    var nearest: Node3D
    var nearest_distance := maximum_distance
    for candidate: Node in get_tree().get_nodes_in_group("damageable"):
        if not candidate is Node3D or not candidate.has_method("is_alive") or not bool(candidate.call("is_alive")):
            continue
        var distance := global_position.distance_to((candidate as Node3D).global_position)
        if distance < nearest_distance:
            nearest = candidate as Node3D
            nearest_distance = distance
    return nearest


func _build_visual() -> void:
    var core := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.28
    mesh.height = 0.56
    core.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("ffd16c")
    material.emission_enabled = true
    material.emission = Color("ffd16c")
    material.emission_energy_multiplier = 2.4
    core.material_override = material
    add_child(core)
    var light := OmniLight3D.new()
    light.light_color = Color("ffd16c")
    light.light_energy = 1.2
    light.omni_range = 2.8
    add_child(light)
