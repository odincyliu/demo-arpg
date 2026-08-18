class_name SkillCompiler
extends RefCounted

const CATEGORY_PHASE: Dictionary = {
    &"Core": 0,
    &"Pattern": 10,
    &"Shape": 20,
    &"Transform": 25,
    &"Trajectory": 30,
    &"Effect": 40,
}


static func compile_build(source_build: SixLinkBuild) -> SkillCompileResult:
    var result := SkillCompileResult.new()
    result.build = source_build.copy_build() if source_build != null else SixLinkBuild.new()
    result.compiled_build = CompiledSkillBuild.new()
    if source_build == null:
        result.fail("Six-link build is missing")
        return _publish(result)

    var catalog := SkillCatalog.get_catalog()
    var saw_empty := false
    var nonempty_count := 0
    for slot: SkillSlot in result.build.slots:
        if slot.is_empty():
            saw_empty = true
            continue
        nonempty_count += 1
        if saw_empty:
            result.fail("Slot %d: valid builds cannot contain a gap" % (slot.slot_index + 1))
        if not catalog.has(slot.component_id):
            result.fail("Slot %d references an unknown Component: %s" % [slot.slot_index + 1, slot.component_id])
            continue
        _validate_schema(catalog[slot.component_id] as SkillComponent, result)

    if nonempty_count == 0:
        result.fail("Slot 1 must contain a Core")
        return _publish(result)

    var first := result.build.get_slot(0)
    var first_component := catalog.get(first.component_id) as SkillComponent
    if first_component == null or not first_component.is_core():
        result.fail("Slot 1 must contain a Core")
        return _publish(result)

    var current_core: SkillDefinition
    var current_exclusive_groups: Dictionary = {}
    var used_non_core_ids: Dictionary = {}
    var trigger_seen := false
    var pending_trigger := false
    var pending_trigger_slot := -1
    for slot_index: int in SixLinkBuild.MAX_SLOTS:
        var slot := result.build.get_slot(slot_index)
        if slot.is_empty():
            break
        var component := catalog.get(slot.component_id) as SkillComponent
        if component == null:
            continue
        if not component.is_core():
            if used_non_core_ids.has(component.component_id):
                result.fail("Slot %d: %s cannot appear twice in one build" % [slot_index + 1, component.display_name])
            used_non_core_ids[component.component_id] = true

        match component.category:
            &"Core":
                if slot_index > 0:
                    if not pending_trigger or slot_index != pending_trigger_slot + 1:
                        result.fail("Slot %d: a second Core must immediately follow a Trigger" % (slot_index + 1))
                    if result.compiled_build.triggered_core != null:
                        result.fail("Slot %d: V1 supports at most two Cores" % (slot_index + 1))
                current_core = _new_core(component, slot_index, result)
                current_exclusive_groups.clear()
                pending_trigger = false
                if slot_index == 0:
                    result.compiled_build.root_core = current_core
                    result.compiled_build.source_core_slot_index = slot_index
                else:
                    result.compiled_build.triggered_core = current_core
                    result.compiled_build.target_core_slot_index = slot_index
            &"Trigger":
                if current_core == null:
                    result.fail("Slot %d: a Trigger requires a Core on its left" % (slot_index + 1))
                    continue
                if trigger_seen:
                    result.fail("Slot %d: MaxTriggerDepth is 1" % (slot_index + 1))
                if slot_index >= SixLinkBuild.MAX_SLOTS - 1:
                    result.fail("Slot %d: a Trigger requires a Core in the next slot" % (slot_index + 1))
                elif not _next_slot_is_core(result.build, slot_index, catalog):
                    result.fail("Slot %d: a Trigger must be immediately followed by a Core" % (slot_index + 1))
                var trigger_error := _compatibility_error(component, current_core)
                if not trigger_error.is_empty():
                    result.fail("Slot %d '%s': %s" % [slot_index + 1, component.display_name, trigger_error])
                trigger_seen = true
                pending_trigger = true
                pending_trigger_slot = slot_index
                result.compiled_build.trigger_component = component
                result.compiled_build.trigger_config = slot.trigger_config.normalized_copy() if slot.trigger_config != null else TriggerConfig.new()
                result.compiled_build.trigger_slot_index = slot_index
                result.applied_slot_indices.append(slot_index)
            _:
                if current_core == null:
                    result.fail("Slot %d: a Component requires a Core on its left" % (slot_index + 1))
                    continue
                if pending_trigger:
                    result.fail("Slot %d: no Component may appear between a Trigger and its target Core" % (slot_index + 1))
                    continue
                var compatibility_error := _compatibility_error(component, current_core)
                if not compatibility_error.is_empty():
                    result.fail("Slot %d '%s': %s" % [slot_index + 1, component.display_name, compatibility_error])
                    continue
                if component.exclusive_group != &"" and current_exclusive_groups.has(component.exclusive_group):
                    result.fail("Slot %d: Core already has a %s Component" % [slot_index + 1, component.exclusive_group])
                    continue
                if component.exclusive_group != &"":
                    current_exclusive_groups[component.exclusive_group] = slot_index
                var apply_error := current_core.apply_component(component)
                if not apply_error.is_empty():
                    result.fail("Slot %d: %s" % [slot_index + 1, apply_error])
                    continue
                _merge_identity(current_core, component)
                result.applied_slot_indices.append(slot_index)

    if pending_trigger:
        result.fail("Slot %d: Trigger has no target Core" % (pending_trigger_slot + 1))
    if result.compiled_build.root_core != null:
        result.compiled_build.root_core = _compile_pipeline_core(
            result.build,
            result.compiled_build.root_core.compiled_slot_index,
            result,
            catalog
        )
    if result.compiled_build.triggered_core != null:
        result.compiled_build.triggered_core = _compile_pipeline_core(
            result.build,
            result.compiled_build.triggered_core.compiled_slot_index,
            result,
            catalog
        )
    if result.compiled_build.trigger_component != null and result.compiled_build.triggered_core == null:
        result.fail("Trigger chain is incomplete")
    elif result.compiled_build.has_trigger():
        result.compiled_build.triggered_core.trigger_type = SkillCatalog.get_trigger_event(
            result.compiled_build.trigger_component.component_id
        )
    if result.applied_slot_indices.size() != nonempty_count and result.errors.is_empty():
        result.fail("One or more non-empty slots were not applied")
    result.applied_slot_indices.sort()
    return _publish(result)


static func preview_edit(build: SixLinkBuild, edit: Dictionary) -> SkillCompileResult:
    var candidate := build.copy_build() if build != null else SixLinkBuild.new()
    var slot_index := int(edit.get("slot_index", -1))
    if slot_index < 0 or slot_index >= SixLinkBuild.MAX_SLOTS:
        var invalid := SkillCompileResult.new()
        invalid.build = candidate
        invalid.compiled_build = CompiledSkillBuild.new()
        invalid.fail("Slot does not exist")
        return _publish(invalid)
    var component_id := StringName(edit.get("component_id", &""))
    var config := edit.get("trigger_config") as TriggerConfig
    candidate.set_slot(SkillSlot.new().configure(slot_index, component_id, config))
    return compile_build(candidate)


static func get_candidate_state(
        build: SixLinkBuild,
        slot_index: int,
        component_id: StringName,
        config: TriggerConfig = null
) -> NodeCompatibility:
    var result := preview_edit(build, {
        "slot_index": slot_index,
        "component_id": component_id,
        "trigger_config": config,
    })
    if result.valid:
        var component := SkillCatalog.get_component(component_id)
        return NodeCompatibility.accepted(result, component.summary if component != null else "")
    return NodeCompatibility.rejected("\n".join(result.errors), result)


static func get_owner_core_slot(build: SixLinkBuild, slot_index: int) -> int:
    for index: int in range(slot_index, -1, -1):
        var slot := build.get_slot(index)
        var component := SkillCatalog.get_component(slot.component_id) if slot != null else null
        if component != null and component.is_core():
            return index
    return -1


static func _new_core(component: SkillComponent, slot_index: int, result: SkillCompileResult) -> SkillDefinition:
    var definition := SkillDefinition.new()
    definition.compiled_slot_index = slot_index
    definition.tags.assign(component.tags)
    definition.capabilities.assign(component.capabilities)
    var error := definition.apply_component(component)
    if not error.is_empty():
        result.fail("Slot %d: %s" % [slot_index + 1, error])
    result.applied_slot_indices.append(slot_index)
    return definition


static func _merge_identity(definition: SkillDefinition, component: SkillComponent) -> void:
    for tag: StringName in component.tags:
        if tag not in definition.tags:
            definition.tags.append(tag)
    for capability: StringName in component.capabilities:
        if capability not in definition.capabilities:
            definition.capabilities.append(capability)
    definition.tags.sort()
    definition.capabilities.sort()


static func _compile_pipeline_core(
        build: SixLinkBuild,
        core_slot_index: int,
        result: SkillCompileResult,
        catalog: Dictionary
) -> SkillDefinition:
    var entries: Array[Dictionary] = []
    for slot_index: int in range(core_slot_index, SixLinkBuild.MAX_SLOTS):
        var slot := build.get_slot(slot_index)
        if slot == null or slot.is_empty():
            break
        var component := catalog.get(slot.component_id) as SkillComponent
        if component == null:
            continue
        if slot_index > core_slot_index and (component.is_core() or component.is_trigger()):
            break
        entries.append({
            "slot_index": slot_index,
            "phase": int(CATEGORY_PHASE.get(component.category, 100)),
            "component": component,
        })
    entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_phase := int(left["phase"])
        var right_phase := int(right["phase"])
        if left_phase == right_phase:
            return int(left["slot_index"]) < int(right["slot_index"])
        return left_phase < right_phase
    )
    var definition := SkillDefinition.new()
    definition.compiled_slot_index = core_slot_index
    for entry: Dictionary in entries:
        var component := entry["component"] as SkillComponent
        if component.is_core():
            definition.tags.assign(component.tags)
            definition.capabilities.assign(component.capabilities)
        var error := definition.apply_component(component)
        if not error.is_empty():
            result.fail("Slot %d: %s" % [int(entry["slot_index"]) + 1, error])
        _merge_identity(definition, component)
    definition.finalize()
    return definition


static func _compatibility_error(component: SkillComponent, definition: SkillDefinition) -> String:
    for tag: StringName in component.requires_tags_all:
        if not definition.has_tag(tag):
            return "Requires tag %s" % String(tag).capitalize()
    if not component.requires_tags_any.is_empty():
        var any_tag := false
        for tag: StringName in component.requires_tags_any:
            if definition.has_tag(tag):
                any_tag = true
        if not any_tag:
            return "Requires one of: %s" % _labels(component.requires_tags_any)
    for tag: StringName in component.excluded_tags:
        if definition.has_tag(tag):
            return "Conflicts with tag %s" % String(tag).capitalize()
    for capability: StringName in component.requires_capabilities:
        if not definition.has_capability(capability):
            return "Requires %s" % SkillCatalog.CAPABILITY_LABELS.get(capability, String(capability).capitalize())
    for capability: StringName in component.excluded_capabilities:
        if definition.has_capability(capability):
            return "Conflicts with %s" % SkillCatalog.CAPABILITY_LABELS.get(capability, String(capability).capitalize())
    return ""


static func _labels(values: Array[StringName]) -> String:
    var labels: PackedStringArray = []
    for value: StringName in values:
        labels.append(String(value).capitalize())
    return " / ".join(labels)


static func _next_slot_is_core(build: SixLinkBuild, slot_index: int, catalog: Dictionary) -> bool:
    var next_slot := build.get_slot(slot_index + 1)
    if next_slot == null or next_slot.is_empty():
        return false
    var next_component := catalog.get(next_slot.component_id) as SkillComponent
    return next_component != null and next_component.is_core()


static func _validate_schema(component: SkillComponent, result: SkillCompileResult) -> void:
    if component.category not in SkillCatalog.CATEGORY_ORDER:
        result.fail("Component %s has an invalid Category" % component.component_id)
    if component.runtime_operation_id == &"":
        result.fail("Component %s has no Runtime operation ID" % component.component_id)
    for operation: Dictionary in component.stat_operations:
        var field := StringName(operation.get("field", &""))
        var operation_type := StringName(operation.get("op", &""))
        var value: Variant = operation.get("value")
        if not SkillDefinition.NUMERIC_FIELDS.has(field):
            result.fail("Component %s uses unknown field %s" % [component.component_id, field])
        elif operation_type not in SkillDefinition.STAT_OPERATIONS:
            result.fail("Component %s uses disallowed operation %s" % [component.component_id, operation_type])
        elif not value is int and not value is float:
            result.fail("Component %s has an invalid value for %s" % [component.component_id, field])
    for raw_field: Variant in component.definition_data:
        if StringName(raw_field) not in SkillDefinition.STRUCTURAL_FIELDS:
            result.fail("Component %s uses unknown structural field %s" % [component.component_id, raw_field])


static func _publish(result: SkillCompileResult) -> SkillCompileResult:
    result.finish()
    result.build.compiled = result.compiled_build if result.valid else null
    result.build.validation_errors = result.errors.duplicate()
    result.build.validation_warnings = result.warnings.duplicate()
    result.build.applied_slot_indices.assign(result.applied_slot_indices)
    return result
