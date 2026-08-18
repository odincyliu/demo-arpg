class_name CombatEvent
extends RefCounted

var cast_id: int = 0
var build_revision: int = 0
var source_core_slot_index: int = -1
var target_core_slot_index: int = -1
var event_type: StringName = &""
var world_position: Vector3 = Vector3.ZERO
var target: Node3D
var source: Node3D
var damage_source: StringName = &""
var generation: int = 0
var amount: float = 0.0
var facing_direction: Vector3 = Vector3.FORWARD
var applied_operations: Array[StringName] = []


func configure(data: Dictionary) -> CombatEvent:
    cast_id = int(data.get("cast_id", 0))
    build_revision = int(data.get("build_revision", 0))
    source_core_slot_index = int(data.get("source_core_slot_index", -1))
    target_core_slot_index = int(data.get("target_core_slot_index", -1))
    event_type = StringName(data.get("event_type", &""))
    world_position = data.get("world_position", Vector3.ZERO) as Vector3
    target = data.get("target") as Node3D
    source = data.get("source") as Node3D
    damage_source = StringName(data.get("damage_source", &""))
    generation = int(data.get("generation", 0))
    amount = float(data.get("amount", 0.0))
    facing_direction = data.get("facing_direction", Vector3.FORWARD) as Vector3
    applied_operations.assign(data.get("applied_operations", []))
    return self


func to_context() -> Dictionary:
    return {
        "cast_id": cast_id,
        "build_revision": build_revision,
        "source_core_slot_index": target_core_slot_index if target_core_slot_index >= 0 else source_core_slot_index,
        "target_core_slot_index": target_core_slot_index,
        "generation": generation,
        "aim_position": world_position,
        "applied_operations": applied_operations.duplicate(),
    }
