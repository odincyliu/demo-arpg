class_name SkillSlot
extends Resource

@export_range(0, 5, 1) var slot_index: int = 0
@export var component_id: StringName = &""
@export var trigger_config: TriggerConfig


func configure(
        new_slot_index: int,
        new_component_id: StringName,
        new_trigger_config: TriggerConfig = null
) -> SkillSlot:
    slot_index = new_slot_index
    component_id = new_component_id
    trigger_config = new_trigger_config.normalized_copy() if new_trigger_config != null else null
    return self


func is_empty() -> bool:
    return component_id == &""


func copy_slot() -> SkillSlot:
    return SkillSlot.new().configure(slot_index, component_id, trigger_config)
