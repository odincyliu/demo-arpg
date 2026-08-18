class_name CompiledSkillBuild
extends RefCounted

var root_core: SkillDefinition
var triggered_core: SkillDefinition
var trigger_component: SkillComponent
var trigger_config: TriggerConfig
var trigger_slot_index: int = -1
var source_core_slot_index: int = -1
var target_core_slot_index: int = -1


func has_trigger() -> bool:
    return trigger_component != null and triggered_core != null


func get_core(slot_index: int) -> SkillDefinition:
    if root_core != null and root_core.compiled_slot_index == slot_index:
        return root_core
    if triggered_core != null and triggered_core.compiled_slot_index == slot_index:
        return triggered_core
    return null
