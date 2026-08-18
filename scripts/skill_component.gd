class_name SkillComponent
extends Resource

@export var component_id: StringName = &""
@export var display_name: String = ""
@export var category: StringName = &""
@export_multiline var summary: String = ""
@export var runtime_operation_id: StringName = &""
@export var tags: Array[StringName] = []
@export var capabilities: Array[StringName] = []
@export var requires_tags_all: Array[StringName] = []
@export var requires_tags_any: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var requires_capabilities: Array[StringName] = []
@export var excluded_capabilities: Array[StringName] = []
@export var exclusive_group: StringName = &""
@export var origin_policy: StringName = &"source"
@export var definition_data: Dictionary = {}
@export var stat_operations: Array[Dictionary] = []


func configure(
        new_id: StringName,
        new_display_name: String,
        new_category: StringName,
        new_summary: String,
        data: Dictionary = {}
) -> SkillComponent:
    component_id = new_id
    display_name = new_display_name
    category = new_category
    summary = new_summary
    runtime_operation_id = StringName(data.get("runtime_operation_id", new_id))
    tags.assign(data.get("tags", []))
    capabilities.assign(data.get("capabilities", []))
    requires_tags_all.assign(data.get("requires_tags_all", []))
    requires_tags_any.assign(data.get("requires_tags_any", []))
    excluded_tags.assign(data.get("excluded_tags", []))
    requires_capabilities.assign(data.get("requires_capabilities", []))
    excluded_capabilities.assign(data.get("excluded_capabilities", []))
    exclusive_group = StringName(data.get("exclusive_group", &""))
    origin_policy = StringName(data.get("origin_policy", &"source"))
    definition_data = (data.get("definition", {}) as Dictionary).duplicate(true)
    stat_operations.assign(data.get("stats", []))
    return self


func is_core() -> bool:
    return category == &"Core"


func is_trigger() -> bool:
    return category == &"Trigger"


func is_support() -> bool:
    return category in [&"Trajectory", &"Shape", &"Pattern", &"Effect", &"Transform"]
