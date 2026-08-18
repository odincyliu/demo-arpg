class_name PrototypeHud
extends CanvasLayer

signal build_changed(build: SixLinkBuild)
signal reset_requested

var _build: SixLinkBuild
var _runtime_build: SixLinkBuild
var _slot_buttons: Array[Button] = []
var _selected_slot_index: int = -1
var _editor_panel: PanelContainer
var _category_selector: OptionButton
var _component_selector: OptionButton
var _show_invalid_toggle: CheckButton
var _trigger_controls: VBoxContainer
var _damage_threshold_row: HBoxContainer
var _channel_interval_row: HBoxContainer
var _every_n: SpinBox
var _chance: SpinBox
var _internal_cooldown: SpinBox
var _health_ratio: SpinBox
var _damage_threshold: SpinBox
var _channel_interval: SpinBox
var _status_selector: OptionButton
var _info_label: Label
var _draft_label: Label
var _stats_label: Label
var _cooldown_bar: ProgressBar
var _cooldown_label: Label
var _health_label: Label
var _refreshing: bool = false


func _ready() -> void:
    add_to_group("six_link_builder_ui")
    _build = SkillCatalog.get_default_build()
    _runtime_build = _build.copy_build()
    _build_interface()
    _refresh_slots()
    set_runtime_build(_runtime_build)


func get_build() -> SixLinkBuild:
    return _build


func get_selected_slots() -> Array[SkillSlot]:
    var result: Array[SkillSlot] = []
    for slot: SkillSlot in _build.slots:
        result.append(slot.copy_slot())
    return result


func set_runtime_build(build: SixLinkBuild) -> void:
    if build == null or not build.is_valid():
        return
    _runtime_build = build.copy_build()
    var definition := build.get_root_core()
    _stats_label.text = "DMG %.0f  CD %.2f  x%d" % [
        definition.damage,
        definition.cooldown,
        definition.instance_count,
    ]
    _stats_label.tooltip_text = "%s\nTags: %s" % [definition.get_stats_text(), definition.get_tags_text()]
    _stats_label.add_theme_color_override("font_color", definition.color.lightened(0.18))


func update_runtime_budget(executor: SkillExecutor) -> void:
    if executor == null or _stats_label == null:
        return
    _stats_label.text = "%s  E%d Q%d P%d H%d M%d" % [
        _stats_label.text.split("  E")[0],
        int(executor.counters["events_rejected"]),
        executor.get_queue_size(),
        executor.get_active_projectile_count(),
        executor.get_held_count(),
        executor.get_active_minion_count(),
    ]


func update_cooldown(remaining: float, duration: float) -> void:
    _cooldown_bar.max_value = maxf(duration, 0.01)
    _cooldown_bar.value = maxf(duration - remaining, 0.0)
    _cooldown_label.text = "READY" if remaining <= 0.0 else "%.2fs" % remaining


func update_player_health(current_health: float, max_health: float) -> void:
    _health_label.text = "HP %.0f/%.0f" % [current_health, max_health]


func log_event(_message: String, _event_color: Color = Color.WHITE) -> void:
    pass


func edit_slot(
        slot_index: int,
        component_id: StringName,
        trigger_config: TriggerConfig = null
) -> bool:
    var result := SkillCompiler.preview_edit(_build, {
        "slot_index": slot_index,
        "component_id": component_id,
        "trigger_config": trigger_config,
    })
    _build = result.build
    _refresh_slots()
    build_changed.emit(_build)
    return result.valid


func clear_slot(slot_index: int) -> void:
    edit_slot(slot_index, &"")


func reset_build() -> void:
    _build = SkillCatalog.get_default_build()
    _close_editor()
    _refresh_slots()
    build_changed.emit(_build)


func get_available_candidates(
        slot_index: int,
        category: StringName,
        include_invalid: bool = true
) -> Array[Dictionary]:
    var candidates: Array[Dictionary] = []
    for component: SkillComponent in SkillCatalog.get_components_by_category(category):
        var state := SkillCompiler.get_candidate_state(_build, slot_index, component.component_id)
        if state.valid or include_invalid:
            candidates.append({
                "component_id": component.component_id,
                "valid": state.valid,
                "reason": state.reason,
                "summary": component.summary,
            })
    return candidates


func _build_interface() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.offset_left = -625.0
    panel.offset_top = 10.0
    panel.offset_right = 625.0
    panel.offset_bottom = 86.0
    panel.add_theme_stylebox_override("panel", _panel_style())
    root.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 8)
    margin.add_theme_constant_override("margin_top", 6)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_bottom", 6)
    panel.add_child(margin)
    var strip := HBoxContainer.new()
    strip.alignment = BoxContainer.ALIGNMENT_CENTER
    strip.add_theme_constant_override("separation", 4)
    margin.add_child(strip)

    var title := Label.new()
    title.text = "SIX\nLINK"
    title.custom_minimum_size.x = 50.0
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_color_override("font_color", Color("8bd8ff"))
    strip.add_child(title)
    for slot_index: int in SixLinkBuild.MAX_SLOTS:
        if slot_index > 0:
            var link := Label.new()
            link.text = "—"
            link.add_theme_color_override("font_color", Color("56758d"))
            strip.add_child(link)
        var button := Button.new()
        button.custom_minimum_size = Vector2(128.0, 56.0)
        button.clip_text = true
        button.add_theme_font_size_override("font_size", 11)
        button.pressed.connect(_open_editor.bind(slot_index))
        strip.add_child(button)
        _slot_buttons.append(button)

    var status := VBoxContainer.new()
    status.custom_minimum_size.x = 190.0
    status.add_theme_constant_override("separation", 1)
    strip.add_child(status)
    _stats_label = Label.new()
    _stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _stats_label.add_theme_font_size_override("font_size", 10)
    status.add_child(_stats_label)
    var cooldown_row := HBoxContainer.new()
    cooldown_row.alignment = BoxContainer.ALIGNMENT_CENTER
    cooldown_row.add_theme_constant_override("separation", 4)
    status.add_child(cooldown_row)
    _cooldown_label = Label.new()
    _cooldown_label.text = "READY"
    _cooldown_label.custom_minimum_size.x = 42.0
    _cooldown_label.add_theme_font_size_override("font_size", 10)
    _cooldown_label.add_theme_color_override("font_color", Color("8bd8ff"))
    cooldown_row.add_child(_cooldown_label)
    _cooldown_bar = ProgressBar.new()
    _cooldown_bar.show_percentage = false
    _cooldown_bar.custom_minimum_size = Vector2(82.0, 12.0)
    cooldown_row.add_child(_cooldown_bar)
    _health_label = Label.new()
    _health_label.text = "HP 100/100"
    _health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _health_label.add_theme_font_size_override("font_size", 10)
    _health_label.add_theme_color_override("font_color", Color("ff8ca8"))
    status.add_child(_health_label)

    _build_editor(root)

    var hint := Label.new()
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_left = 14.0
    hint.offset_top = -28.0
    hint.offset_right = 850.0
    hint.offset_bottom = -7.0
    hint.text = "LMB move • RMB cast/hold • Space dash • Q damage • R reset"
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color("8ea5b7"))
    root.add_child(hint)


func _build_editor(root: Control) -> void:
    _editor_panel = PanelContainer.new()
    _editor_panel.anchor_left = 0.5
    _editor_panel.anchor_right = 0.5
    _editor_panel.offset_left = -550.0
    _editor_panel.offset_top = 102.0
    _editor_panel.offset_right = 550.0
    _editor_panel.offset_bottom = 420.0
    _editor_panel.add_theme_stylebox_override("panel", _panel_style(Color("122231"), 0.97))
    _editor_panel.visible = false
    _editor_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_editor_panel)

    var margin := MarginContainer.new()
    for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
        margin.add_theme_constant_override(side, 12)
    _editor_panel.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    margin.add_child(column)

    var header := HBoxContainer.new()
    column.add_child(header)
    _info_label = Label.new()
    _info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _info_label.add_theme_font_size_override("font_size", 15)
    _info_label.add_theme_color_override("font_color", Color("9de5ff"))
    header.add_child(_info_label)
    var clear_button := Button.new()
    clear_button.text = "Clear slot"
    clear_button.pressed.connect(_on_clear_pressed)
    header.add_child(clear_button)
    var reset_button := Button.new()
    reset_button.text = "Default"
    reset_button.pressed.connect(reset_build)
    header.add_child(reset_button)
    var close_button := Button.new()
    close_button.text = "Close"
    close_button.pressed.connect(_close_editor)
    header.add_child(close_button)

    var selector_row := HBoxContainer.new()
    selector_row.add_theme_constant_override("separation", 8)
    column.add_child(selector_row)
    selector_row.add_child(_field_label("Category", 70.0))
    _category_selector = OptionButton.new()
    _category_selector.custom_minimum_size.x = 150.0
    _category_selector.item_selected.connect(_on_category_selected)
    selector_row.add_child(_category_selector)
    selector_row.add_child(_field_label("Component", 82.0))
    _component_selector = OptionButton.new()
    _component_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _component_selector.item_selected.connect(_on_component_selected)
    selector_row.add_child(_component_selector)
    _show_invalid_toggle = CheckButton.new()
    _show_invalid_toggle.text = "Edit invalid draft"
    _show_invalid_toggle.button_pressed = true
    _show_invalid_toggle.toggled.connect(_on_show_invalid_toggled)
    selector_row.add_child(_show_invalid_toggle)

    _trigger_controls = VBoxContainer.new()
    _trigger_controls.add_theme_constant_override("separation", 5)
    column.add_child(_trigger_controls)
    var common_row := HBoxContainer.new()
    common_row.add_theme_constant_override("separation", 6)
    _trigger_controls.add_child(common_row)
    _every_n = _add_spin(common_row, "Every N", 1.0, 20.0, 1.0, 1.0)
    _chance = _add_spin(common_row, "Chance %", 0.0, 100.0, 0.1, 100.0)
    _internal_cooldown = _add_spin(common_row, "ICD", 0.0, 5.0, 0.01, 0.08)
    _health_ratio = _add_spin(common_row, "Max HP %", 0.0, 100.0, 1.0, 100.0)
    common_row.add_child(_field_label("Target status", 90.0))
    _status_selector = OptionButton.new()
    _status_selector.custom_minimum_size.x = 130.0
    for status: StringName in [&"any", &"ignite", &"freeze", &"electrified", &"stun", &"bleed", &"poison"]:
        _status_selector.add_item(String(status).capitalize())
        _status_selector.set_item_metadata(_status_selector.item_count - 1, status)
    common_row.add_child(_status_selector)

    _damage_threshold_row = HBoxContainer.new()
    _trigger_controls.add_child(_damage_threshold_row)
    _damage_threshold = _add_spin(_damage_threshold_row, "Accumulated damage % max HP", 1.0, 100.0, 1.0, 10.0)
    _channel_interval_row = HBoxContainer.new()
    _trigger_controls.add_child(_channel_interval_row)
    _channel_interval = _add_spin(_channel_interval_row, "Channel interval", 0.05, 5.0, 0.05, 0.5)

    var apply_button := Button.new()
    apply_button.text = "Apply to draft"
    apply_button.custom_minimum_size.y = 34.0
    apply_button.pressed.connect(_apply_editor_selection)
    column.add_child(apply_button)
    _draft_label = Label.new()
    _draft_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _draft_label.custom_minimum_size.y = 62.0
    column.add_child(_draft_label)


func _field_label(text: String, width: float) -> Label:
    var label := Label.new()
    label.text = text
    label.custom_minimum_size.x = width
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", Color("a8becd"))
    return label


func _add_spin(
        parent: HBoxContainer,
        label_text: String,
        minimum: float,
        maximum: float,
        step: float,
        value: float
) -> SpinBox:
    parent.add_child(_field_label(label_text, maxf(54.0, label_text.length() * 6.5)))
    var spin := SpinBox.new()
    spin.min_value = minimum
    spin.max_value = maximum
    spin.step = step
    spin.value = value
    spin.custom_minimum_size.x = 72.0
    parent.add_child(spin)
    return spin


func _open_editor(slot_index: int) -> void:
    _selected_slot_index = slot_index
    _editor_panel.visible = true
    _refreshing = true
    _info_label.text = "Slot %d — %s" % [slot_index + 1, "Core required" if slot_index == 0 else "left-to-right Component"]
    _populate_categories()
    var slot := _build.get_slot(slot_index)
    var current := SkillCatalog.get_component(slot.component_id) if slot != null else null
    var desired_category: StringName = &"Core" if slot_index == 0 else (current.category if current != null else &"Pattern")
    _select_metadata(_category_selector, desired_category)
    _populate_components(desired_category)
    if current != null:
        _select_metadata(_component_selector, current.component_id)
    _load_trigger_config(slot.trigger_config if slot != null else null)
    _refreshing = false
    _refresh_editor_state()


func _close_editor() -> void:
    _selected_slot_index = -1
    if _editor_panel != null:
        _editor_panel.visible = false


func _populate_categories() -> void:
    _category_selector.clear()
    var categories: Array[StringName] = []
    if _selected_slot_index == 0:
        categories.append(&"Core")
    else:
        categories.assign(SkillCatalog.CATEGORY_ORDER)
    for category: StringName in categories:
        _category_selector.add_item(SkillCatalog.get_category_label(category))
        _category_selector.set_item_metadata(_category_selector.item_count - 1, category)


func _populate_components(category: StringName) -> void:
    _component_selector.clear()
    var include_invalid := _show_invalid_toggle.button_pressed
    for candidate: Dictionary in get_available_candidates(_selected_slot_index, category, true):
        if not bool(candidate["valid"]) and not include_invalid:
            continue
        var component := SkillCatalog.get_component(StringName(candidate["component_id"]))
        var prefix := "" if bool(candidate["valid"]) else "⚠ "
        _component_selector.add_item(prefix + component.display_name)
        var item_index := _component_selector.item_count - 1
        _component_selector.set_item_metadata(item_index, component.component_id)
        _component_selector.set_item_tooltip(item_index, component.summary if bool(candidate["valid"]) else String(candidate["reason"]))
    if _component_selector.item_count == 0:
        _component_selector.add_item("No candidates")
        _component_selector.set_item_metadata(0, &"")
        _component_selector.set_item_disabled(0, true)


func _load_trigger_config(config: TriggerConfig) -> void:
    var source := config if config != null else TriggerConfig.new()
    _every_n.value = source.every_n
    _chance.value = source.chance
    _internal_cooldown.value = source.internal_cooldown
    _health_ratio.value = source.max_player_health_ratio * 100.0
    _damage_threshold.value = source.damage_threshold_ratio * 100.0
    _channel_interval.value = source.channel_interval
    _select_metadata(_status_selector, source.required_target_status)


func _make_trigger_config() -> TriggerConfig:
    var config := TriggerConfig.new()
    config.every_n = int(_every_n.value)
    config.chance = _chance.value
    config.internal_cooldown = _internal_cooldown.value
    config.max_player_health_ratio = _health_ratio.value / 100.0
    config.damage_threshold_ratio = _damage_threshold.value / 100.0
    config.channel_interval = _channel_interval.value
    config.required_target_status = StringName(_status_selector.get_item_metadata(_status_selector.selected))
    return config


func _selected_component_id() -> StringName:
    if _component_selector.item_count == 0 or _component_selector.selected < 0:
        return &""
    return StringName(_component_selector.get_item_metadata(_component_selector.selected))


func _refresh_editor_state() -> void:
    if _selected_slot_index < 0:
        return
    var component_id := _selected_component_id()
    var component := SkillCatalog.get_component(component_id)
    var is_trigger := component != null and component.is_trigger()
    _trigger_controls.visible = is_trigger
    _damage_threshold_row.visible = component_id == &"trigger_damage_taken"
    _channel_interval_row.visible = component_id == &"trigger_channel"
    var config := _make_trigger_config() if is_trigger else null
    var state := SkillCompiler.get_candidate_state(_build, _selected_slot_index, component_id, config)
    if component == null:
        _draft_label.text = "Choose a Component."
        return
    _draft_label.text = "%s\n%s" % [
        component.summary,
        "Valid — combat will adopt this build." if state.valid else "Draft invalid — runtime stays on the last valid build:\n%s" % state.reason,
    ]
    _draft_label.add_theme_color_override("font_color", Color("93e6b4") if state.valid else Color("ff9a9f"))


func _refresh_slots() -> void:
    if _slot_buttons.size() != SixLinkBuild.MAX_SLOTS:
        return
    var errors_by_slot: Dictionary = {}
    for error: String in _build.validation_errors:
        var slot_number := _extract_slot_number(error)
        if slot_number >= 0:
            errors_by_slot[slot_number] = error
    for slot_index: int in SixLinkBuild.MAX_SLOTS:
        var button := _slot_buttons[slot_index]
        var slot := _build.get_slot(slot_index)
        var component := SkillCatalog.get_component(slot.component_id) if slot != null else null
        if component == null:
            button.text = "%d  EMPTY\n%s" % [slot_index + 1, "CORE REQUIRED" if slot_index == 0 else "Click to edit"]
            button.tooltip_text = "Slot %d is empty" % (slot_index + 1)
            button.modulate = Color("ff8e9a") if errors_by_slot.has(slot_index) else Color("a7b4bf")
            continue
        var owner := SkillCompiler.get_owner_core_slot(_build, slot_index)
        var binding := "ROOT" if component.is_core() and slot_index == 0 else (
            "TRIGGER CORE" if component.is_core() else "→ Core %d" % (owner + 1)
        )
        button.text = "%d  %s\n%s • %s" % [slot_index + 1, component.display_name, component.category, binding]
        button.tooltip_text = component.summary
        if errors_by_slot.has(slot_index):
            button.tooltip_text += "\n\n" + String(errors_by_slot[slot_index])
            button.modulate = Color("ff8994")
        else:
            button.modulate = Color.WHITE


func _extract_slot_number(error: String) -> int:
    if not error.begins_with("Slot "):
        return -1
    var suffix := error.trim_prefix("Slot ")
    var separator := suffix.find(":")
    if separator < 0:
        separator = suffix.find(" ")
    return int(suffix.left(separator)) - 1 if separator > 0 else -1


func _apply_editor_selection() -> void:
    var component_id := _selected_component_id()
    if component_id == &"" or _selected_slot_index < 0:
        return
    var component := SkillCatalog.get_component(component_id)
    edit_slot(_selected_slot_index, component_id, _make_trigger_config() if component != null and component.is_trigger() else null)
    _open_editor(_selected_slot_index)


func _on_clear_pressed() -> void:
    if _selected_slot_index >= 0:
        clear_slot(_selected_slot_index)
        _open_editor(_selected_slot_index)


func _on_category_selected(_index: int) -> void:
    if _refreshing:
        return
    _populate_components(StringName(_category_selector.get_item_metadata(_category_selector.selected)))
    _refresh_editor_state()


func _on_component_selected(_index: int) -> void:
    if not _refreshing:
        _refresh_editor_state()


func _on_show_invalid_toggled(_enabled: bool) -> void:
    if _selected_slot_index < 0:
        return
    var category := StringName(_category_selector.get_item_metadata(_category_selector.selected))
    _populate_components(category)
    _refresh_editor_state()


func _select_metadata(selector: OptionButton, metadata: Variant) -> void:
    for item_index: int in selector.item_count:
        if selector.get_item_metadata(item_index) == metadata:
            selector.select(item_index)
            return


func _panel_style(color: Color = Color("101c27"), opacity: float = 0.94) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(color, opacity)
    style.border_color = Color("3b647b")
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    return style
