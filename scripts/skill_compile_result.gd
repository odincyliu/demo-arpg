class_name SkillCompileResult
extends RefCounted

var valid: bool = false
var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var applied_node_ids: Array[int] = []
var compiled_skills: Dictionary = {}
var graph: SkillGraph


func fail(message: String) -> void:
    if message not in errors:
        errors.append(message)
    valid = false


func finish() -> SkillCompileResult:
    valid = errors.is_empty()
    return self

