class_name CombatEvent
extends RefCounted

var cast_id: int = 0
var graph_revision: int = 0
var source_skill_node_id: int = -1
var target_skill_node_id: int = -1
var event_type: StringName = &""
var world_position: Vector3 = Vector3.ZERO
var target: Node3D
var source: Node3D
var damage_source: StringName = &""
var depth: int = 0
var facing_direction: Vector3 = Vector3.FORWARD
var applied_operations: Array[StringName] = []


func configure(data: Dictionary) -> CombatEvent:
    cast_id = int(data.get("cast_id", 0))
    graph_revision = int(data.get("graph_revision", 0))
    source_skill_node_id = int(data.get("source_skill_node_id", -1))
    target_skill_node_id = int(data.get("target_skill_node_id", -1))
    event_type = StringName(data.get("event_type", &""))
    world_position = data.get("world_position", Vector3.ZERO) as Vector3
    target = data.get("target") as Node3D
    source = data.get("source") as Node3D
    damage_source = StringName(data.get("damage_source", &""))
    depth = int(data.get("depth", 0))
    facing_direction = data.get("facing_direction", Vector3.FORWARD) as Vector3
    applied_operations.assign(data.get("applied_operations", []))
    return self


func to_context() -> Dictionary:
    return {
        "cast_id": cast_id,
        "graph_revision": graph_revision,
        "source_skill_node_id": target_skill_node_id if target_skill_node_id >= 0 else source_skill_node_id,
        "depth": depth,
        "aim_position": world_position,
        "applied_operations": applied_operations.duplicate(),
    }
