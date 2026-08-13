class_name SkillGraph
extends Resource

const MAX_NODES: int = 6
const ROOT_PARENT: int = -1
const PLAYER_EVENT_PARENT: int = -2

var nodes: Array[SkillGraphNode] = []
var compiled_skills: Dictionary = {}
var validation_errors: PackedStringArray = []
var validation_warnings: PackedStringArray = []
var applied_node_ids: Array[int] = []
var revision: int = 0


func _init() -> void:
    for node_id: int in MAX_NODES:
        nodes.append(SkillGraphNode.new().configure(node_id, &"", ROOT_PARENT))


func set_node(node: SkillGraphNode) -> void:
    if node == null or node.node_id < 0 or node.node_id >= MAX_NODES:
        return
    nodes[node.node_id] = node.copy_node()


func clear_node(node_id: int) -> void:
    if node_id < 0 or node_id >= MAX_NODES:
        return
    nodes[node_id] = SkillGraphNode.new().configure(node_id, &"", ROOT_PARENT)


func get_graph_node(node_id: int) -> SkillGraphNode:
    if node_id < 0 or node_id >= nodes.size():
        return null
    return nodes[node_id]


func get_children(parent_node_id: int) -> Array[SkillGraphNode]:
    var children: Array[SkillGraphNode] = []
    for node: SkillGraphNode in nodes:
        if not node.is_empty() and node.parent_node_id == parent_node_id:
            children.append(node)
    children.sort_custom(func(left: SkillGraphNode, right: SkillGraphNode) -> bool:
        return left.node_id < right.node_id
    )
    return children


func get_primary_skill_node_id() -> int:
    for node: SkillGraphNode in nodes:
        if not node.is_empty() and node.parent_node_id == ROOT_PARENT:
            return node.node_id
    return -1


func get_primary_skill() -> SkillDefinition:
    return compiled_skills.get(get_primary_skill_node_id()) as SkillDefinition


func get_compiled_skill(node_id: int) -> SkillDefinition:
    return compiled_skills.get(node_id) as SkillDefinition


func is_valid() -> bool:
    return validation_errors.is_empty() and get_primary_skill() != null


func copy_graph() -> SkillGraph:
    var result := SkillGraph.new()
    for node: SkillGraphNode in nodes:
        result.set_node(node)
    result.compiled_skills = compiled_skills.duplicate()
    result.validation_errors = validation_errors.duplicate()
    result.validation_warnings = validation_warnings.duplicate()
    result.applied_node_ids.assign(applied_node_ids)
    result.revision = revision
    return result

