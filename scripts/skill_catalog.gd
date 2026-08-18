class_name SkillCatalog
extends RefCounted

const CATEGORY_ORDER: Array[StringName] = [
    &"Core", &"Trigger", &"Trajectory", &"Shape", &"Pattern", &"Effect", &"Transform",
]
const CATEGORY_LABELS: Dictionary = {
    &"Core": "Core",
    &"Trigger": "Trigger",
    &"Trajectory": "Trajectory",
    &"Shape": "Shape",
    &"Pattern": "Pattern",
    &"Effect": "Effect",
    &"Transform": "Transform",
}
const TRIGGER_EVENTS: Dictionary = {
    &"trigger_hit": &"hit",
    &"trigger_crit": &"critical",
    &"trigger_kill": &"kill",
    &"trigger_stun": &"stun",
    &"trigger_freeze": &"freeze",
    &"trigger_ignite": &"ignite",
    &"trigger_shock": &"electrified",
    &"trigger_damage_taken": &"damage_taken",
    &"trigger_channel": &"channel",
    &"trigger_return": &"return",
}
const CAPABILITY_LABELS: Dictionary = {
    &"can_hit": "Can Hit",
    &"movable_instance": "Movable Instance",
    &"can_store": "Can Be Stored",
    &"can_return": "Can Return",
    &"path_instance": "Path Instance",
    &"channel": "Channel",
}

static var _catalog: Dictionary = {}


static func get_default_build() -> SixLinkBuild:
    var build := SixLinkBuild.new()
    var ids: Array[StringName] = [
        &"core_frost_lance", &"pattern_multishot", &"pattern_hold",
        &"effect_freeze", &"trigger_freeze", &"core_shockwave",
    ]
    for slot_index: int in ids.size():
        var config := TriggerConfig.new() if ids[slot_index] == &"trigger_freeze" else null
        build.set_slot(SkillSlot.new().configure(slot_index, ids[slot_index], config))
    return SkillCompiler.compile_build(build).build


static func get_catalog() -> Dictionary:
    if _catalog.is_empty():
        _catalog = _build_catalog()
    return _catalog


static func get_component(component_id: StringName) -> SkillComponent:
    return get_catalog().get(component_id) as SkillComponent


static func get_components_by_category(category: StringName) -> Array[SkillComponent]:
    var result: Array[SkillComponent] = []
    for raw_component: Variant in get_catalog().values():
        var component := raw_component as SkillComponent
        if component != null and component.category == category:
            result.append(component)
    result.sort_custom(func(left: SkillComponent, right: SkillComponent) -> bool:
        return String(left.component_id) < String(right.component_id)
    )
    return result


static func get_trigger_event(component_id: StringName) -> StringName:
    return StringName(TRIGGER_EVENTS.get(component_id, &""))


static func get_category_label(category: StringName) -> String:
    return String(CATEGORY_LABELS.get(category, category))


static func _op(field: StringName, operation: StringName, value: Variant) -> Dictionary:
    return {"field": field, "op": operation, "value": value}


static func _component(
        component_id: StringName,
        name: String,
        category: StringName,
        summary: String,
        data: Dictionary = {}
) -> SkillComponent:
    return SkillComponent.new().configure(component_id, name, category, summary, data)


static func _core(
        component_id: StringName,
        name: String,
        summary: String,
        tags: Array[StringName],
        capabilities: Array[StringName],
        definition: Dictionary,
        stats: Array[Dictionary],
        origin_policy: StringName = &"source"
) -> SkillComponent:
    return _component(component_id, name, &"Core", summary, {
        "tags": tags,
        "capabilities": capabilities,
        "origin_policy": origin_policy,
        "definition": definition,
        "stats": stats,
    })


static func _build_catalog() -> Dictionary:
    var components: Array[SkillComponent] = []
    components.append_array(_core_components())
    components.append_array(_trigger_components())
    components.append_array(_trajectory_components())
    components.append_array(_shape_components())
    components.append_array(_pattern_components())
    components.append_array(_effect_components())
    components.append_array(_transform_components())
    var result: Dictionary = {}
    for component: SkillComponent in components:
        result[component.component_id] = component
    return result


static func _core_components() -> Array[SkillComponent]:
    return [
        _core(&"core_slash", "Slash", "A short physical arc in front of the caster.",
            [&"melee", &"physical", &"hit", &"directional"], [&"can_hit"],
            {"active_skill_id": &"slash", "core_behavior": &"melee", "shape_type": &"cone", "element": &"physical", "color": Color("c7c7c7")},
            [_op(&"damage", &"SET", 34.0), _op(&"cooldown", &"SET", 0.45), _op(&"area_radius", &"SET", 3.4), _op(&"spread_degrees", &"SET", 72.0)]),
        _core(&"core_whirlblade", "Whirlblade", "A mobile channelling melee spin.",
            [&"melee", &"physical", &"hit", &"channel", &"aoe"], [&"can_hit", &"channel"],
            {"active_skill_id": &"whirlblade", "core_behavior": &"channel", "shape_type": &"circle", "element": &"physical", "color": Color("b6b6b6"), "channelled": true, "channel_can_move": true, "radial": true},
            [_op(&"damage", &"SET", 10.0), _op(&"cooldown", &"SET", 0.5), _op(&"area_radius", &"SET", 3.1), _op(&"channel_tick_interval", &"SET", 0.18)]),
        _core(&"core_dash_strike", "Dash Strike", "Dash forward and damage enemies on the path.",
            [&"melee", &"physical", &"movement", &"hit", &"directional"], [&"can_hit", &"path_instance"],
            {"active_skill_id": &"dash_strike", "core_behavior": &"dash", "shape_type": &"line", "element": &"physical", "color": Color("cccccc")},
            [_op(&"damage", &"SET", 30.0), _op(&"cooldown", &"SET", 0.7), _op(&"target_range", &"SET", 5.0)]),
        _core(&"core_shockwave", "Shockwave", "A broad physical wave that passes through every target once.",
            [&"physical", &"wave", &"directional", &"aoe", &"hit"], [&"can_hit", &"movable_instance", &"can_store", &"path_instance"],
            {"active_skill_id": &"shockwave", "core_behavior": &"wave", "shape_type": &"line", "element": &"physical", "color": Color("b2b2b2")},
            [_op(&"damage", &"SET", 28.0), _op(&"cooldown", &"SET", 0.55), _op(&"projectile_speed", &"SET", 12.0), _op(&"projectile_lifetime", &"SET", 1.2), _op(&"width_multiplier", &"SET", 1.6)]),
        _core(&"core_ground_burst", "Ground Burst", "A physical eruption at the target point.",
            [&"physical", &"ground", &"aoe", &"hit"], [&"can_hit"],
            {"active_skill_id": &"ground_burst", "core_behavior": &"ground", "shape_type": &"circle", "element": &"physical", "color": Color("949494"), "radial": true},
            [_op(&"damage", &"SET", 36.0), _op(&"cooldown", &"SET", 0.65), _op(&"area_radius", &"SET", 2.5), _op(&"target_range", &"SET", 10.0)], &"target"),
        _core(&"core_arrow_shot", "Arrow Shot", "A fast straight physical projectile.",
            [&"physical", &"projectile", &"attack", &"hit", &"directional"], [&"can_hit", &"movable_instance", &"can_store", &"can_return", &"path_instance"],
            {"active_skill_id": &"arrow_shot", "core_behavior": &"projectile", "shape_type": &"line", "element": &"physical", "color": Color("bdbdbd")},
            [_op(&"damage", &"SET", 30.0), _op(&"cooldown", &"SET", 0.42), _op(&"projectile_speed", &"SET", 20.0)]),
        _core(&"core_frost_lance", "Frost Lance", "A fast cold spell projectile.",
            [&"cold", &"projectile", &"spell", &"hit", &"directional"], [&"can_hit", &"movable_instance", &"can_store", &"can_return", &"path_instance"],
            {"active_skill_id": &"frost_lance", "core_behavior": &"projectile", "shape_type": &"line", "element": &"cold", "color": Color("cdcdcd")},
            [_op(&"damage", &"SET", 27.0), _op(&"cooldown", &"SET", 0.48), _op(&"projectile_speed", &"SET", 18.0)]),
        _core(&"core_flame_orb", "Flame Orb", "A black flame projectile that bursts on impact or expiry.",
            [&"fire", &"projectile", &"spell", &"hit", &"directional"], [&"can_hit", &"movable_instance", &"can_store", &"can_return", &"path_instance"],
            {"active_skill_id": &"flame_orb", "core_behavior": &"projectile", "shape_type": &"line", "element": &"fire", "color": Color("a3a3a3")},
            [_op(&"damage", &"SET", 34.0), _op(&"cooldown", &"SET", 0.55), _op(&"projectile_speed", &"SET", 13.0), _op(&"impact_radius", &"SET", 1.8)]),
        _core(&"core_frost_nova", "Frost Nova", "A cold spell centred on its cast position.",
            [&"cold", &"spell", &"aoe", &"hit"], [&"can_hit"],
            {"active_skill_id": &"frost_nova", "core_behavior": &"area", "shape_type": &"circle", "element": &"cold", "color": Color("c4c4c4"), "radial": true},
            [_op(&"damage", &"SET", 26.0), _op(&"cooldown", &"SET", 0.62), _op(&"area_radius", &"SET", 4.0)], &"event"),
        _core(&"core_chain_lightning", "Chain Lightning", "Strike a target and use the shared Chain operation.",
            [&"lightning", &"spell", &"hit"], [&"can_hit"],
            {"active_skill_id": &"chain_lightning", "core_behavior": &"chain", "shape_type": &"tracking", "element": &"lightning", "color": Color("cbcbcb")},
            [_op(&"damage", &"SET", 26.0), _op(&"cooldown", &"SET", 0.6), _op(&"chain_count", &"SET", 2), _op(&"chain_range", &"SET", 4.5), _op(&"chain_damage_multiplier", &"SET", 0.8), _op(&"target_range", &"SET", 12.0)]),
        _core(&"core_meteor", "Meteor", "A delayed high-damage fire impact at a target area.",
            [&"fire", &"spell", &"aoe", &"hit", &"ground"], [&"can_hit"],
            {"active_skill_id": &"meteor", "core_behavior": &"meteor", "shape_type": &"circle", "element": &"fire", "color": Color("9b9b9b"), "radial": true},
            [_op(&"damage", &"SET", 65.0), _op(&"cooldown", &"SET", 1.2), _op(&"repeat_interval", &"SET", 0.65), _op(&"area_radius", &"SET", 3.2), _op(&"target_range", &"SET", 12.0)], &"target"),
        _core(&"core_void_beam", "Void Beam", "A stationary chaos beam maintained while channelling.",
            [&"chaos", &"spell", &"beam", &"channel", &"hit", &"directional"], [&"can_hit", &"channel", &"path_instance"],
            {"active_skill_id": &"void_beam", "core_behavior": &"channel", "shape_type": &"line", "element": &"chaos", "color": Color("7d7d7d"), "channelled": true, "channel_can_move": false},
            [_op(&"damage", &"SET", 8.0), _op(&"cooldown", &"SET", 0.6), _op(&"target_range", &"SET", 11.0), _op(&"channel_tick_interval", &"SET", 0.12)]),
        _core(&"core_void_rift", "Void Rift", "A persistent chaos damage area.",
            [&"chaos", &"spell", &"ground", &"persistent"], [],
            {"active_skill_id": &"void_rift", "core_behavior": &"persistent", "shape_type": &"circle", "element": &"chaos", "color": Color("636363"), "radial": true},
            [_op(&"damage", &"SET", 9.0), _op(&"cooldown", &"SET", 0.9), _op(&"area_radius", &"SET", 3.0), _op(&"persistent_duration", &"SET", 3.0), _op(&"persistent_tick_interval", &"SET", 0.35)], &"target"),
        _core(&"core_summon", "Summon", "Create a temporary ranged follower.",
            [&"minion", &"spell", &"summon"], [],
            {"active_skill_id": &"summon", "core_behavior": &"summon", "shape_type": &"tracking", "element": &"neutral", "color": Color("b6b6b6")},
            [_op(&"damage", &"SET", 14.0), _op(&"cooldown", &"SET", 1.5), _op(&"summon_duration", &"SET", 10.0), _op(&"summon_attack_interval", &"SET", 0.8)], &"event"),
    ]


static func _trigger_components() -> Array[SkillComponent]:
    return [
        _component(&"trigger_hit", "On Hit", &"Trigger", "Trigger when the source Core hits."),
        _component(&"trigger_crit", "On Crit", &"Trigger", "Trigger on a critical hit."),
        _component(&"trigger_kill", "On Kill", &"Trigger", "Trigger when the source Core kills."),
        _component(&"trigger_stun", "On Stun", &"Trigger", "Trigger when Stun is successfully applied."),
        _component(&"trigger_freeze", "On Freeze", &"Trigger", "Trigger when Freeze is successfully applied."),
        _component(&"trigger_ignite", "On Ignite", &"Trigger", "Trigger only on the inactive-to-Ignited transition."),
        _component(&"trigger_shock", "On Shock", &"Trigger", "Trigger only on the inactive-to-Electrified transition."),
        _component(&"trigger_damage_taken", "On Damage Taken", &"Trigger", "Trigger after accumulated player damage reaches its threshold."),
        _component(&"trigger_channel", "Channel Trigger", &"Trigger", "Trigger periodically while the source Core is channelled.", {"requires_capabilities": [&"channel"]}),
        _component(&"trigger_return", "On Return", &"Trigger", "Trigger when a returning instance reaches its owner.", {"requires_capabilities": [&"return_enabled"]}),
    ]


static func _trajectory_components() -> Array[SkillComponent]:
    return [
        _component(&"trajectory_pierce", "Pierce", &"Trajectory", "Pass through three extra targets.", {"requires_tags_all": [&"projectile"], "stats": [_op(&"pierce_count", &"ADD", 3)]}),
        _component(&"trajectory_fork", "Fork", &"Trajectory", "Split into two successors on the first hit.", {"requires_tags_all": [&"projectile"], "stats": [_op(&"fork_count", &"SET", 2)]}),
        _component(&"trajectory_chain", "Chain", &"Trajectory", "Redirect to two nearby valid targets using the shared Chain operation.", {"requires_capabilities": [&"can_hit"], "stats": [_op(&"chain_count", &"ADD", 2), _op(&"chain_range", &"SET", 4.8), _op(&"chain_damage_multiplier", &"SET", 0.78)]}),
        _component(&"trajectory_return", "Return", &"Trajectory", "Return once to the owner after reaching the end.", {"requires_capabilities": [&"can_return"], "definition": {"return_enabled": true}, "stats": [_op(&"return_speed_multiplier", &"SET", 1.2)]}),
        _component(&"trajectory_homing", "Homing", &"Trajectory", "Continuously steer toward a valid target.", {"requires_capabilities": [&"movable_instance"], "excluded_tags": [&"beam"], "stats": [_op(&"homing_strength", &"SET", 5.4)]}),
    ]


static func _shape_components() -> Array[SkillComponent]:
    return [
        _component(&"shape_nova", "Nova", &"Shape", "Convert a directional Core into a radial release.", {"requires_tags_all": [&"directional"], "exclusive_group": &"Shape", "definition": {"shape_type": &"circle", "radial": true}, "stats": [_op(&"projectile_count", &"SET", 12)]}),
        _component(&"shape_cone", "Cone", &"Shape", "Arrange instances in a forward fan.", {"requires_capabilities": [&"can_hit"], "exclusive_group": &"Shape", "definition": {"shape_type": &"cone", "radial": false}, "stats": [_op(&"spread_degrees", &"SET", 52.0)]}),
        _component(&"shape_line", "Line", &"Shape", "Arrange simultaneous instances in parallel.", {"requires_capabilities": [&"can_hit"], "exclusive_group": &"Shape", "definition": {"shape_type": &"line", "radial": false}}),
        _component(&"shape_orbit", "Orbit", &"Shape", "Move instances around the caster.", {"requires_capabilities": [&"movable_instance"], "exclusive_group": &"Shape", "excluded_tags": [&"beam", &"ground"], "definition": {"shape_type": &"rotate", "radial": true}, "stats": [_op(&"rotation_speed", &"SET", 2.5), _op(&"projectile_count", &"SET", 6), _op(&"projectile_lifetime", &"MULTIPLY", 1.5)]}),
    ]


static func _pattern_components() -> Array[SkillComponent]:
    return [
        _component(&"pattern_phantom", "Phantom", &"Pattern", "A phantom performs the same cast simultaneously at reduced damage.", {"stats": [_op(&"phantom_count", &"ADD", 1), _op(&"phantom_damage_multiplier", &"SET", 0.7)]}),
        _component(&"pattern_repeat", "Repeat", &"Pattern", "The same caster repeats the Core three times.", {"stats": [_op(&"repeat_count", &"SET", 3), _op(&"repeat_interval", &"SET", 0.12)]}),
        _component(&"pattern_multishot", "Multishot", &"Pattern", "Create three simultaneous instances.", {"stats": [_op(&"instance_count", &"SET", 3), _op(&"damage", &"MULTIPLY", 0.72)]}),
        _component(&"pattern_hold", "Hold", &"Pattern", "Store created instances and release them together.", {"requires_capabilities": [&"can_store"], "definition": {"hold_enabled": true}, "stats": [_op(&"hold_max_stored", &"SET", 5), _op(&"hold_auto_release", &"SET", 1.5)]}),
        _component(&"pattern_remnant", "Remnant", &"Pattern", "Leave a short-lived damaging trail along the travelled path.", {"requires_capabilities": [&"path_instance"], "definition": {"remnant_enabled": true}, "stats": [_op(&"remnant_duration", &"SET", 2.0), _op(&"remnant_tick_interval", &"SET", 0.35), _op(&"remnant_damage_multiplier", &"SET", 0.25)]}),
    ]


static func _effect_components() -> Array[SkillComponent]:
    return [
        _component(&"effect_ignite", "Ignite", &"Effect", "Fire hits apply a non-stacking burn.", {"requires_tags_all": [&"fire", &"hit"], "definition": {"effect_type": &"ignite"}, "stats": [_op(&"burn_duration", &"SET", 3.0), _op(&"burn_damage_per_second", &"SET", 5.0)]}),
        _component(&"effect_freeze", "Freeze", &"Effect", "Cold hits build Freeze until the threshold is crossed.", {"requires_tags_all": [&"cold", &"hit"], "definition": {"effect_type": &"freeze"}, "stats": [_op(&"freeze_duration", &"SET", 2.0), _op(&"freeze_buildup", &"SET", 35.0)]}),
        _component(&"effect_shock", "Shock", &"Effect", "Lightning hits apply the Electrified ailment and 20% increased damage taken.", {"requires_tags_all": [&"lightning", &"hit"], "definition": {"effect_type": &"electrified"}, "stats": [_op(&"shock_duration", &"SET", 3.0), _op(&"shock_damage_taken_multiplier", &"SET", 1.2)]}),
        _component(&"effect_bleed", "Bleed", &"Effect", "Physical hits apply a non-stacking physical damage over time effect.", {"requires_tags_all": [&"physical", &"hit"], "definition": {"effect_type": &"bleed"}, "stats": [_op(&"bleed_duration", &"SET", 4.0), _op(&"bleed_damage_ratio", &"SET", 0.12)]}),
        _component(&"effect_poison", "Poison", &"Effect", "Physical or Chaos hits add stacking poison damage.", {"requires_tags_all": [&"hit"], "requires_tags_any": [&"physical", &"chaos"], "definition": {"effect_type": &"poison"}, "stats": [_op(&"poison_duration", &"SET", 4.0), _op(&"poison_damage_per_second", &"SET", 3.0), _op(&"poison_max_stacks", &"SET", 10)]}),
        _component(&"effect_knockback", "Knockback", &"Effect", "Push targets away from the impact direction.", {"requires_tags_all": [&"hit"], "definition": {"effect_type": &"knockback"}, "stats": [_op(&"knockback_distance", &"SET", 2.0)]}),
        _component(&"effect_pull", "Pull", &"Effect", "Pull targets toward the effect centre.", {"requires_tags_all": [&"hit"], "definition": {"effect_type": &"pull"}, "stats": [_op(&"pull_distance", &"SET", 2.0)]}),
        _component(&"effect_stun", "Stun", &"Effect", "Hits build break value until Stun is applied.", {"requires_tags_all": [&"hit"], "definition": {"effect_type": &"stun"}, "stats": [_op(&"stun_buildup", &"SET", 35.0)]}),
    ]


static func _transform_components() -> Array[SkillComponent]:
    return [
        _component(&"transform_giant", "Giant", &"Transform", "Increase scale and damage while slowing the Core.", {"stats": [_op(&"size_multiplier", &"MULTIPLY", 1.6), _op(&"width_multiplier", &"MULTIPLY", 1.6), _op(&"damage", &"MULTIPLY", 1.35), _op(&"projectile_speed", &"MULTIPLY", 0.8), _op(&"cooldown", &"MULTIPLY", 1.25)]}),
        _component(&"transform_expanded", "Expanded", &"Transform", "Increase area, wave width and cone width without adding damage.", {"stats": [_op(&"area_radius", &"MULTIPLY", 1.5), _op(&"width_multiplier", &"MULTIPLY", 1.5), _op(&"spread_degrees", &"MULTIPLY", 1.5)]}),
        _component(&"transform_compressed", "Compressed", &"Transform", "Reduce area while concentrating damage and buildup.", {"stats": [_op(&"area_radius", &"MULTIPLY", 0.65), _op(&"width_multiplier", &"MULTIPLY", 0.65), _op(&"damage", &"MULTIPLY", 1.35), _op(&"ailment_buildup_multiplier", &"MULTIPLY", 1.4)]}),
    ]
