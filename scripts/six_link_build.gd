class_name SixLinkBuild
extends Resource

const MAX_SLOTS: int = 6

var slots: Array[SkillSlot] = []
var compiled: CompiledSkillBuild
var validation_errors: PackedStringArray = []
var validation_warnings: PackedStringArray = []
var applied_slot_indices: Array[int] = []
var revision: int = 0


func _init() -> void:
    for slot_index: int in MAX_SLOTS:
        slots.append(SkillSlot.new().configure(slot_index, &""))


func set_slot(slot: SkillSlot) -> void:
    if slot == null or slot.slot_index < 0 or slot.slot_index >= MAX_SLOTS:
        return
    slots[slot.slot_index] = slot.copy_slot()


func clear_slot(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= MAX_SLOTS:
        return
    slots[slot_index] = SkillSlot.new().configure(slot_index, &"")


func get_slot(slot_index: int) -> SkillSlot:
    if slot_index < 0 or slot_index >= slots.size():
        return null
    return slots[slot_index]


func get_root_core() -> SkillDefinition:
    return compiled.root_core if compiled != null else null


func get_triggered_core() -> SkillDefinition:
    return compiled.triggered_core if compiled != null else null


func is_valid() -> bool:
    return validation_errors.is_empty() and get_root_core() != null


func copy_build() -> SixLinkBuild:
    var result := SixLinkBuild.new()
    for slot: SkillSlot in slots:
        result.set_slot(slot)
    result.compiled = compiled
    result.validation_errors = validation_errors.duplicate()
    result.validation_warnings = validation_warnings.duplicate()
    result.applied_slot_indices.assign(applied_slot_indices)
    result.revision = revision
    return result
