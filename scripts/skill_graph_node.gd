class_name SkillGraphNode
extends Resource

@export_range(0, 5, 1) var node_id: int = 0
@export var concept_id: StringName = &""
@export var parent_node_id: int = -1
@export var trigger_config: TriggerConfig


func configure(
        new_node_id: int,
        new_concept_id: StringName,
        new_parent_node_id: int = -1,
        new_trigger_config: TriggerConfig = null
) -> SkillGraphNode:
    node_id = new_node_id
    concept_id = new_concept_id
    parent_node_id = new_parent_node_id
    trigger_config = new_trigger_config.normalized_copy() if new_trigger_config != null else null
    return self


func is_empty() -> bool:
    return concept_id == &""


func copy_node() -> SkillGraphNode:
    return SkillGraphNode.new().configure(node_id, concept_id, parent_node_id, trigger_config)

