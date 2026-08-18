class_name SkillCompileResult
extends RefCounted

var valid: bool = false
var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var applied_slot_indices: Array[int] = []
var compiled_build: CompiledSkillBuild
var build: SixLinkBuild


func fail(message: String) -> void:
    if message not in errors:
        errors.append(message)
    valid = false


func finish() -> SkillCompileResult:
    valid = errors.is_empty()
    return self
