class_name SkillDefinition
extends Resource

const NUMERIC_FIELDS: Dictionary = {
    &"damage": TYPE_FLOAT,
    &"cooldown": TYPE_FLOAT,
    &"projectile_speed": TYPE_FLOAT,
    &"projectile_lifetime": TYPE_FLOAT,
    &"projectile_count": TYPE_INT,
    &"split_count": TYPE_INT,
    &"repeat_count": TYPE_INT,
    &"repeat_interval": TYPE_FLOAT,
    &"spread_degrees": TYPE_FLOAT,
    &"pierce_count": TYPE_INT,
    &"homing_strength": TYPE_FLOAT,
    &"rotation_speed": TYPE_FLOAT,
    &"projectile_acceleration": TYPE_FLOAT,
    &"bounce_count": TYPE_INT,
    &"area_radius": TYPE_FLOAT,
    &"target_range": TYPE_FLOAT,
    &"target_snap_radius": TYPE_FLOAT,
    &"explosion_radius": TYPE_FLOAT,
    &"explosion_damage_multiplier": TYPE_FLOAT,
    &"chain_count": TYPE_INT,
    &"chain_range": TYPE_FLOAT,
    &"chain_damage_multiplier": TYPE_FLOAT,
    &"splash_radius": TYPE_FLOAT,
    &"splash_damage_multiplier": TYPE_FLOAT,
    &"critical_chance": TYPE_FLOAT,
    &"critical_multiplier": TYPE_FLOAT,
    &"burn_duration": TYPE_FLOAT,
    &"burn_damage_per_second": TYPE_FLOAT,
    &"poison_duration": TYPE_FLOAT,
    &"poison_damage_per_second": TYPE_FLOAT,
    &"freeze_duration": TYPE_FLOAT,
    &"lifesteal_ratio": TYPE_FLOAT,
}
const STRUCTURAL_FIELDS: Array[StringName] = [
    &"active_skill_id", &"emitter_type", &"action_type", &"shape_type",
    &"color", &"element", &"modifier_type", &"effect_type", &"radial",
]
const STAT_OPERATIONS: Array[StringName] = [&"SET", &"ADD", &"MULTIPLY"]

var preset_id: StringName = &""
var compiled_node_id: int = -1
var display_name: String = ""
var description: String = ""
var concepts: Array[SkillConcept] = []
var tags: Array[StringName] = []
var runtime_operations: Array[StringName] = []

var active_skill_id: StringName = &""
var trigger_type: StringName = &"manual"
var emitter_type: StringName = &"player"
var action_type: StringName = &"projectile"
var shape_type: StringName = &"line"
var modifier_type: StringName = &"none"
var effect_type: StringName = &"none"
var modifier_types: Array[StringName] = []
var effect_types: Array[StringName] = []
var color: Color = Color("8bd8ff")
var element: StringName = &"arcane"
var damage: float = 28.0
var cooldown: float = 0.65
var projectile_speed: float = 13.0
var projectile_lifetime: float = 2.4
var projectile_count: int = 1
var split_count: int = 0
var repeat_count: int = 1
var repeat_interval: float = 0.0
var spread_degrees: float = 0.0
var radial: bool = false
var pierce_count: int = 0
var homing_strength: float = 0.0
var rotation_speed: float = 0.0
var projectile_acceleration: float = 0.0
var bounce_count: int = 0
var area_radius: float = 5.2
var target_range: float = 0.0
var target_snap_radius: float = 0.0
var explosion_radius: float = 0.0
var explosion_damage_multiplier: float = 0.0
var chain_count: int = 0
var chain_range: float = 0.0
var chain_damage_multiplier: float = 0.0
var splash_radius: float = 0.0
var splash_damage_multiplier: float = 0.0
var critical_chance: float = 0.1
var critical_multiplier: float = 1.75
var burn_duration: float = 0.0
var burn_damage_per_second: float = 0.0
var poison_duration: float = 0.0
var poison_damage_per_second: float = 0.0
var freeze_duration: float = 0.0
var lifesteal_ratio: float = 0.0


func apply_concept(concept: SkillConcept) -> String:
    if concept == null:
        return "Concept does not exist"
    concepts.append(concept)
    if concept.concept_kind == &"Skill":
        preset_id = concept.concept_id
        display_name = concept.display_name
        description = concept.summary
    if concept.runtime_operation_id != &"" and concept.runtime_operation_id not in runtime_operations:
        runtime_operations.append(concept.runtime_operation_id)

    for raw_field: Variant in concept.structural_changes:
        var field := StringName(raw_field)
        var error := apply_structural_change(field, concept.structural_changes[raw_field])
        if not error.is_empty():
            return error
    for stat_operation: Dictionary in concept.stat_operations:
        var error := apply_stat_operation(stat_operation)
        if not error.is_empty():
            return error
    return ""


func apply_structural_change(field: StringName, value: Variant) -> String:
    if field not in STRUCTURAL_FIELDS:
        return "Unknown structural field: %s" % field
    match field:
        &"active_skill_id", &"emitter_type", &"action_type", &"shape_type", &"element":
            if not value is StringName and not value is String:
                return "%s must be a StringName" % field
            set(String(field), StringName(value))
        &"color":
            if not value is Color:
                return "color must be a Color"
            color = value as Color
        &"radial":
            if not value is bool:
                return "radial must be a bool"
            radial = bool(value)
        &"modifier_type":
            var modifier := StringName(value)
            modifier_type = modifier
            if modifier != &"none" and modifier not in modifier_types:
                modifier_types.append(modifier)
        &"effect_type":
            var effect := StringName(value)
            effect_type = effect
            if effect != &"none" and effect not in effect_types:
                effect_types.append(effect)
    return ""


func apply_stat_operation(operation: Dictionary) -> String:
    var field := StringName(operation.get("field", &""))
    var operation_type := StringName(operation.get("op", &""))
    var value: Variant = operation.get("value")
    if not NUMERIC_FIELDS.has(field):
        return "Unknown numeric field: %s" % field
    if operation_type not in STAT_OPERATIONS:
        return "Disallowed numeric operation: %s" % operation_type
    if not value is int and not value is float:
        return "%s has an invalid numeric value type" % field

    var current: Variant = get(String(field))
    var calculated: float
    match operation_type:
        &"SET":
            calculated = float(value)
        &"ADD":
            calculated = float(current) + float(value)
        &"MULTIPLY":
            calculated = float(current) * float(value)
    if int(NUMERIC_FIELDS[field]) == TYPE_INT:
        set(String(field), int(round(calculated)))
    else:
        set(String(field), calculated)
    return ""


func set_capabilities(capabilities: Dictionary) -> void:
    tags.clear()
    for raw_tag: Variant in capabilities:
        tags.append(StringName(raw_tag))
    tags.sort()


func finalize() -> void:
    damage = clampf(damage, 1.0, 100000.0)
    cooldown = clampf(cooldown, 0.08, 60.0)
    projectile_speed = clampf(projectile_speed, 1.0, 100.0)
    projectile_lifetime = clampf(projectile_lifetime, 0.25, 15.0)
    projectile_count = clampi(projectile_count, 1, 64)
    split_count = clampi(split_count, 0, 16)
    repeat_count = clampi(repeat_count, 1, 6)
    repeat_interval = clampf(repeat_interval, 0.0, 2.0)
    pierce_count = clampi(pierce_count, 0, 32)
    bounce_count = clampi(bounce_count, 0, 16)
    area_radius = clampf(area_radius, 0.5, 30.0)
    target_range = clampf(target_range, 0.0, 30.0)
    target_snap_radius = clampf(target_snap_radius, 0.0, 12.0)
    chain_count = clampi(chain_count, 0, 16)
    chain_range = clampf(chain_range, 0.0, 30.0)
    chain_damage_multiplier = clampf(chain_damage_multiplier, 0.0, 5.0)
    critical_chance = clampf(critical_chance, 0.0, 1.0)
    critical_multiplier = clampf(critical_multiplier, 1.0, 10.0)
    lifesteal_ratio = clampf(lifesteal_ratio, 0.0, 1.0)


func has_modifier(modifier_id: StringName) -> bool:
    return modifier_id in modifier_types


func has_effect(effect_id: StringName) -> bool:
    return effect_id in effect_types


func has_tag(tag: StringName) -> bool:
    return tag in tags


func get_operation_key(operation_id: StringName) -> StringName:
    return StringName("%d:%s" % [compiled_node_id, operation_id])


func get_stats_text() -> String:
    var details := "Damage %.0f | Cooldown %.2fs" % [damage, cooldown]
    if action_type in [&"projectile", &"summon"]:
        details += " | Projectiles %d" % projectile_count
    if repeat_count > 1:
        details += " | Repeats %d" % repeat_count
    if action_type == &"damage" and shape_type in [&"circle", &"rotate"]:
        details += " | Area %.1fm" % area_radius
    if target_range > 0.0:
        details += " | Range %.1fm | Snap %.1fm" % [target_range, target_snap_radius]
    if pierce_count > 0:
        details += "\nPierce %d" % pierce_count
    if chain_count > 0:
        details += " | Chain %d" % chain_count
    if explosion_radius > 0.0:
        details += " | Explosion %.1fm" % explosion_radius
    if homing_strength > 0.0:
        details += " | Homing"
    if splash_radius > 0.0:
        details += " | Splash %.1fm" % splash_radius
    return details


func get_tags_text() -> String:
    var display_tags: PackedStringArray = []
    for tag: StringName in tags:
        display_tags.append(String(tag).capitalize())
    return " / ".join(display_tags)


func get_inline_chain_text() -> String:
    var steps: PackedStringArray = []
    for concept: SkillConcept in concepts:
        steps.append(concept.display_name)
    return " -> ".join(steps)
