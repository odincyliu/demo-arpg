class_name SkillConcept
extends Resource

@export var concept_id: StringName = &""
@export var display_name: String = ""
@export var concept_kind: StringName = &""
@export_multiline var summary: String = ""
@export var runtime_operation_id: StringName = &""
@export var compile_phase: int = 0
@export var exclusive_group: StringName = &""
@export var requires_all: Array[StringName] = []
@export var requires_any: Array[StringName] = []
@export var excludes: Array[StringName] = []
@export var provides: Array[StringName] = []
@export var removes: Array[StringName] = []
@export var adapters: Array[StringName] = []
@export var structural_changes: Dictionary = {}
@export var stat_operations: Array[Dictionary] = []


func configure(
        new_id: StringName,
        new_display_name: String,
        new_kind: StringName,
        new_summary: String,
        operation_id: StringName,
        phase: int,
        data: Dictionary = {}
) -> SkillConcept:
    concept_id = new_id
    display_name = new_display_name
    concept_kind = new_kind
    summary = new_summary
    runtime_operation_id = operation_id
    compile_phase = phase
    exclusive_group = StringName(data.get("exclusive_group", &""))
    requires_all.assign(data.get("requires_all", []))
    requires_any.assign(data.get("requires_any", []))
    excludes.assign(data.get("excludes", []))
    provides.assign(data.get("provides", []))
    removes.assign(data.get("removes", []))
    adapters.assign(data.get("adapters", []))
    structural_changes = data.get("structural", {}).duplicate(true)
    stat_operations.assign(data.get("stats", []))
    return self


func is_support() -> bool:
    return concept_kind in [&"Emitter", &"Action", &"Pattern", &"Modifier", &"Effect"]

