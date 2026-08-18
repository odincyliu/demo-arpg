class_name SkillDefinition
extends Resource

const NUMERIC_FIELDS: Dictionary = {
    &"damage": TYPE_FLOAT,
    &"cooldown": TYPE_FLOAT,
    &"projectile_speed": TYPE_FLOAT,
    &"projectile_lifetime": TYPE_FLOAT,
    &"projectile_count": TYPE_INT,
    &"repeat_count": TYPE_INT,
    &"repeat_interval": TYPE_FLOAT,
    &"spread_degrees": TYPE_FLOAT,
    &"pierce_count": TYPE_INT,
    &"homing_strength": TYPE_FLOAT,
    &"rotation_speed": TYPE_FLOAT,
    &"area_radius": TYPE_FLOAT,
    &"impact_radius": TYPE_FLOAT,
    &"target_range": TYPE_FLOAT,
    &"chain_count": TYPE_INT,
    &"chain_range": TYPE_FLOAT,
    &"chain_damage_multiplier": TYPE_FLOAT,
    &"critical_chance": TYPE_FLOAT,
    &"critical_multiplier": TYPE_FLOAT,
    &"burn_duration": TYPE_FLOAT,
    &"burn_damage_per_second": TYPE_FLOAT,
    &"poison_duration": TYPE_FLOAT,
    &"poison_damage_per_second": TYPE_FLOAT,
    &"freeze_duration": TYPE_FLOAT,
    &"instance_count": TYPE_INT,
    &"phantom_count": TYPE_INT,
    &"phantom_damage_multiplier": TYPE_FLOAT,
    &"fork_count": TYPE_INT,
    &"return_speed_multiplier": TYPE_FLOAT,
    &"hold_max_stored": TYPE_INT,
    &"hold_auto_release": TYPE_FLOAT,
    &"remnant_duration": TYPE_FLOAT,
    &"remnant_tick_interval": TYPE_FLOAT,
    &"remnant_damage_multiplier": TYPE_FLOAT,
    &"size_multiplier": TYPE_FLOAT,
    &"width_multiplier": TYPE_FLOAT,
    &"ailment_buildup_multiplier": TYPE_FLOAT,
    &"channel_tick_interval": TYPE_FLOAT,
    &"persistent_duration": TYPE_FLOAT,
    &"persistent_tick_interval": TYPE_FLOAT,
    &"summon_duration": TYPE_FLOAT,
    &"summon_attack_interval": TYPE_FLOAT,
    &"shock_duration": TYPE_FLOAT,
    &"shock_damage_taken_multiplier": TYPE_FLOAT,
    &"bleed_duration": TYPE_FLOAT,
    &"bleed_damage_ratio": TYPE_FLOAT,
    &"poison_max_stacks": TYPE_INT,
    &"freeze_buildup": TYPE_FLOAT,
    &"stun_buildup": TYPE_FLOAT,
    &"knockback_distance": TYPE_FLOAT,
    &"pull_distance": TYPE_FLOAT,
}
const STRUCTURAL_FIELDS: Array[StringName] = [
    &"active_skill_id", &"shape_type", &"color", &"element", &"effect_type", &"radial",
    &"core_behavior", &"origin_policy", &"channelled", &"channel_can_move",
    &"return_enabled", &"hold_enabled", &"remnant_enabled",
]
const STAT_OPERATIONS: Array[StringName] = [&"SET", &"ADD", &"MULTIPLY"]

var preset_id: StringName = &""
var compiled_slot_index: int = -1
var display_name: String = ""
var description: String = ""
var components: Array[SkillComponent] = []
var tags: Array[StringName] = []
var capabilities: Array[StringName] = []
var runtime_operations: Array[StringName] = []

var active_skill_id: StringName = &""
var core_behavior: StringName = &"projectile"
var origin_policy: StringName = &"source"
var trigger_type: StringName = &""
var shape_type: StringName = &"line"
var modifier_types: Array[StringName] = []
var effect_types: Array[StringName] = []
var color: Color = Color("8bd8ff")
var element: StringName = &"arcane"
var damage: float = 28.0
var cooldown: float = 0.65
var projectile_speed: float = 13.0
var projectile_lifetime: float = 2.4
var projectile_count: int = 1
var repeat_count: int = 1
var repeat_interval: float = 0.0
var spread_degrees: float = 0.0
var radial: bool = false
var pierce_count: int = 0
var homing_strength: float = 0.0
var rotation_speed: float = 0.0
var area_radius: float = 5.2
var impact_radius: float = 0.0
var target_range: float = 0.0
var chain_count: int = 0
var chain_range: float = 0.0
var chain_damage_multiplier: float = 0.0
var critical_chance: float = 0.1
var critical_multiplier: float = 1.75
var burn_duration: float = 0.0
var burn_damage_per_second: float = 0.0
var poison_duration: float = 0.0
var poison_damage_per_second: float = 0.0
var freeze_duration: float = 0.0
var instance_count: int = 1
var phantom_count: int = 0
var phantom_damage_multiplier: float = 0.7
var fork_count: int = 0
var return_enabled: bool = false
var return_speed_multiplier: float = 1.0
var hold_enabled: bool = false
var hold_max_stored: int = 5
var hold_auto_release: float = 1.5
var remnant_enabled: bool = false
var remnant_duration: float = 2.0
var remnant_tick_interval: float = 0.35
var remnant_damage_multiplier: float = 0.25
var size_multiplier: float = 1.0
var width_multiplier: float = 1.0
var ailment_buildup_multiplier: float = 1.0
var channelled: bool = false
var channel_can_move: bool = false
var channel_tick_interval: float = 0.18
var persistent_duration: float = 0.0
var persistent_tick_interval: float = 0.35
var summon_duration: float = 10.0
var summon_attack_interval: float = 0.8
var shock_duration: float = 0.0
var shock_damage_taken_multiplier: float = 1.0
var bleed_duration: float = 0.0
var bleed_damage_ratio: float = 0.0
var poison_max_stacks: int = 10
var freeze_buildup: float = 0.0
var stun_buildup: float = 0.0
var knockback_distance: float = 0.0
var pull_distance: float = 0.0


func apply_component(component: SkillComponent) -> String:
    if component == null:
        return "Component does not exist"
    components.append(component)
    if component.category == &"Core":
        preset_id = component.component_id
        display_name = component.display_name
        description = component.summary
        origin_policy = component.origin_policy
    if component.runtime_operation_id != &"" and component.runtime_operation_id not in runtime_operations:
        runtime_operations.append(component.runtime_operation_id)
    if component.category in [&"Trajectory", &"Pattern", &"Transform"]:
        var visual_operation := StringName(String(component.component_id).get_slice("_", 1))
        if visual_operation != &"" and visual_operation not in modifier_types:
            modifier_types.append(visual_operation)
    for raw_field: Variant in component.definition_data:
        var field := StringName(raw_field)
        var error := apply_structural_change(field, component.definition_data[raw_field])
        if not error.is_empty():
            return error
    for stat_operation: Dictionary in component.stat_operations:
        var error := apply_stat_operation(stat_operation)
        if not error.is_empty():
            return error
    return ""


func apply_structural_change(field: StringName, value: Variant) -> String:
    if field not in STRUCTURAL_FIELDS:
        return "Unknown structural field: %s" % field
    match field:
        &"active_skill_id", &"shape_type", &"element", &"core_behavior", &"origin_policy":
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
        &"channelled", &"channel_can_move", &"return_enabled", &"hold_enabled", &"remnant_enabled":
            if not value is bool:
                return "%s must be a bool" % field
            set(String(field), bool(value))
        &"effect_type":
            var effect := StringName(value)
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


func has_capability(capability: StringName) -> bool:
    if capability == &"return_enabled":
        return return_enabled
    return capability in capabilities


func finalize() -> void:
    damage = clampf(damage, 1.0, 100000.0)
    cooldown = clampf(cooldown, 0.08, 60.0)
    projectile_speed = clampf(projectile_speed, 1.0, 100.0)
    projectile_lifetime = clampf(projectile_lifetime, 0.25, 15.0)
    projectile_count = clampi(projectile_count, 1, 64)
    repeat_count = clampi(repeat_count, 1, 6)
    repeat_interval = clampf(repeat_interval, 0.0, 2.0)
    pierce_count = clampi(pierce_count, 0, 32)
    area_radius = clampf(area_radius, 0.5, 30.0)
    impact_radius = clampf(impact_radius, 0.0, 30.0)
    target_range = clampf(target_range, 0.0, 30.0)
    chain_count = clampi(chain_count, 0, 16)
    chain_range = clampf(chain_range, 0.0, 30.0)
    chain_damage_multiplier = clampf(chain_damage_multiplier, 0.0, 5.0)
    critical_chance = clampf(critical_chance, 0.0, 1.0)
    critical_multiplier = clampf(critical_multiplier, 1.0, 10.0)
    instance_count = clampi(instance_count, 1, 64)
    phantom_count = clampi(phantom_count, 0, 4)
    phantom_damage_multiplier = clampf(phantom_damage_multiplier, 0.05, 1.0)
    fork_count = clampi(fork_count, 0, 8)
    return_speed_multiplier = clampf(return_speed_multiplier, 0.1, 4.0)
    hold_max_stored = clampi(hold_max_stored, 1, 32)
    hold_auto_release = clampf(hold_auto_release, 0.05, 10.0)
    remnant_duration = clampf(remnant_duration, 0.1, 10.0)
    remnant_tick_interval = clampf(remnant_tick_interval, 0.05, 2.0)
    remnant_damage_multiplier = clampf(remnant_damage_multiplier, 0.0, 5.0)
    size_multiplier = clampf(size_multiplier, 0.1, 5.0)
    width_multiplier = clampf(width_multiplier, 0.1, 5.0)
    ailment_buildup_multiplier = clampf(ailment_buildup_multiplier, 0.1, 10.0)
    channel_tick_interval = clampf(channel_tick_interval, 0.05, 2.0)
    persistent_duration = clampf(persistent_duration, 0.0, 30.0)
    persistent_tick_interval = clampf(persistent_tick_interval, 0.05, 5.0)
    summon_duration = clampf(summon_duration, 0.5, 60.0)
    summon_attack_interval = clampf(summon_attack_interval, 0.1, 10.0)
    shock_damage_taken_multiplier = clampf(shock_damage_taken_multiplier, 1.0, 5.0)
    poison_max_stacks = clampi(poison_max_stacks, 1, 64)


func has_modifier(modifier_id: StringName) -> bool:
    return modifier_id in modifier_types


func has_effect(effect_id: StringName) -> bool:
    return effect_id in effect_types


func has_tag(tag: StringName) -> bool:
    return tag in tags


func has_component(component_id: StringName) -> bool:
    for component: SkillComponent in components:
        if component.component_id == component_id:
            return true
    return false


func get_stats_text() -> String:
    var details := "Damage %.0f | Cooldown %.2fs" % [damage, cooldown]
    if core_behavior in [&"projectile", &"wave", &"summon"]:
        details += " | Projectiles %d" % projectile_count
    if repeat_count > 1:
        details += " | Repeats %d" % repeat_count
    if core_behavior not in [&"projectile", &"wave", &"summon"] and shape_type in [&"circle", &"rotate"]:
        details += " | Area %.1fm" % area_radius
    if target_range > 0.0:
        details += " | Range %.1fm" % target_range
    if impact_radius > 0.0:
        details += " | Impact %.1fm" % impact_radius
    if pierce_count > 0:
        details += "\nPierce %d" % pierce_count
    if chain_count > 0:
        details += " | Chain %d" % chain_count
    if homing_strength > 0.0:
        details += " | Homing"
    return details


func get_tags_text() -> String:
    var display_tags: PackedStringArray = []
    for tag: StringName in tags:
        display_tags.append(String(tag).capitalize())
    return " / ".join(display_tags)


func get_inline_chain_text() -> String:
    var steps: PackedStringArray = []
    for component: SkillComponent in components:
        steps.append(component.display_name)
    return " -> ".join(steps)
