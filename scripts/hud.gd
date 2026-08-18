class_name PrototypeHud
extends CanvasLayer

signal build_changed(build: SixLinkBuild)
signal reset_requested

const EMPTY_SLOT_COLOR := Color("263746")
const ACTIVE_SLOT_COLOR := Color("15394a")
const INVALID_SLOT_COLOR := Color("4b2730")
const LOCKED_SLOT_COLOR := Color("17232d")
const ACCENT_COLOR := Color("62d7ff")
const VALID_COLOR := Color("7de8a8")
const INVALID_COLOR := Color("ff8f9b")

var _build: SixLinkBuild
var _runtime_build: SixLinkBuild
var _slot_buttons: Array[Button] = []
var _selected_slot_index: int = -1
var _active_category: StringName = &""
var _refreshing_selectors: bool = false

var _builder_panel: PanelContainer
var _editor_panel: PanelContainer
var _category_selector: OptionButton
var _component_selector: OptionButton
var _apply_selection_button: Button
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
var _build_status_label: Label
var _active_build_label: Label
var _stats_label: Label
var _cooldown_bar: ProgressBar
var _cooldown_label: Label
var _health_label: Label
var _runtime_stats_base: String = "No active Core"


func _ready() -> void:
    add_to_group("six_link_builder_ui")
    _build = SkillCompiler.compile_build(SixLinkBuild.new()).build
    _build_interface()
    _refresh_slots()
    _refresh_runtime_summary()
    get_viewport().size_changed.connect(_apply_responsive_layout)
    _apply_responsive_layout()


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
    _active_build_label.text = definition.display_name
    _active_build_label.add_theme_color_override("font_color", definition.color.lightened(0.18))
    _runtime_stats_base = "DMG %.0f  CD %.2f  ×%d" % [
        definition.damage,
        definition.cooldown,
        definition.instance_count,
    ]
    _stats_label.tooltip_text = "%s\nTags: %s" % [definition.get_stats_text(), definition.get_tags_text()]
    _refresh_runtime_summary()


func update_runtime_budget(executor: SkillExecutor) -> void:
    if executor == null or _stats_label == null:
        return
    if _runtime_build == null:
        _stats_label.text = _runtime_stats_base
        return
    _stats_label.text = "%s  ·  P%d H%d M%d" % [
        _runtime_stats_base,
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
    _build = SkillCompiler.compile_build(SixLinkBuild.new()).build
    _close_editor()
    _refresh_slots()
    build_changed.emit(_build)


func load_default_preset() -> void:
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
        var pending := _is_forward_pending_trigger(component, slot_index, state)
        if state.valid or include_invalid:
            candidates.append({
                "component_id": component.component_id,
                "valid": state.valid,
                "pending": pending,
                "reason": state.reason,
                "summary": component.summary,
            })
    return candidates


func _build_interface() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    _builder_panel = PanelContainer.new()
    _builder_panel.anchor_left = 0.5
    _builder_panel.anchor_right = 0.5
    _builder_panel.offset_top = 10.0
    _builder_panel.offset_bottom = 166.0
    _builder_panel.add_theme_stylebox_override("panel", _panel_style(Color("0c1721"), 0.97, ACCENT_COLOR.darkened(0.45)))
    root.add_child(_builder_panel)

    var margin := MarginContainer.new()
    _set_margins(margin, 12)
    _builder_panel.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    margin.add_child(column)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    column.add_child(header)
    var title := Label.new()
    title.text = "MODULAR SIX-LINK"
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override("font_color", ACCENT_COLOR)
    header.add_child(title)
    _build_status_label = Label.new()
    _build_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _build_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _build_status_label.add_theme_font_size_override("font_size", 12)
    header.add_child(_build_status_label)
    var preset_button := Button.new()
    preset_button.text = "LOAD FROST PRESET"
    preset_button.tooltip_text = "Frost Lance → Multishot → Hold → Freeze → On Freeze → Shockwave"
    preset_button.pressed.connect(load_default_preset)
    header.add_child(preset_button)
    var clear_all_button := Button.new()
    clear_all_button.text = "CLEAR ALL"
    clear_all_button.pressed.connect(reset_build)
    header.add_child(clear_all_button)

    var chain_row := HBoxContainer.new()
    chain_row.alignment = BoxContainer.ALIGNMENT_CENTER
    chain_row.add_theme_constant_override("separation", 4)
    column.add_child(chain_row)
    for slot_index: int in SixLinkBuild.MAX_SLOTS:
        if slot_index > 0:
            var link := Label.new()
            link.text = "—"
            link.custom_minimum_size.x = 14.0
            link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            link.add_theme_font_size_override("font_size", 16)
            link.add_theme_color_override("font_color", Color("55758b"))
            chain_row.add_child(link)
        var button := Button.new()
        button.custom_minimum_size = Vector2(148.0, 76.0)
        button.clip_text = true
        button.add_theme_font_size_override("font_size", 11)
        button.pressed.connect(_open_editor.bind(slot_index))
        chain_row.add_child(button)
        _slot_buttons.append(button)

    var status_separator := VSeparator.new()
    status_separator.custom_minimum_size.x = 8.0
    chain_row.add_child(status_separator)
    var status := VBoxContainer.new()
    status.custom_minimum_size.x = 190.0
    status.add_theme_constant_override("separation", 1)
    chain_row.add_child(status)
    var active_caption := Label.new()
    active_caption.text = "ACTIVE CORE"
    active_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    active_caption.add_theme_font_size_override("font_size", 9)
    active_caption.add_theme_color_override("font_color", Color("718a9d"))
    status.add_child(active_caption)
    _active_build_label = Label.new()
    _active_build_label.text = "NONE"
    _active_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _active_build_label.add_theme_font_size_override("font_size", 13)
    _active_build_label.add_theme_color_override("font_color", Color("9aa9b4"))
    status.add_child(_active_build_label)
    _stats_label = Label.new()
    _stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _stats_label.add_theme_font_size_override("font_size", 9)
    _stats_label.add_theme_color_override("font_color", Color("9bb0bf"))
    status.add_child(_stats_label)
    var cooldown_row := HBoxContainer.new()
    cooldown_row.alignment = BoxContainer.ALIGNMENT_CENTER
    cooldown_row.add_theme_constant_override("separation", 4)
    status.add_child(cooldown_row)
    _cooldown_label = Label.new()
    _cooldown_label.text = "READY"
    _cooldown_label.custom_minimum_size.x = 42.0
    _cooldown_label.add_theme_font_size_override("font_size", 9)
    _cooldown_label.add_theme_color_override("font_color", ACCENT_COLOR)
    cooldown_row.add_child(_cooldown_label)
    _cooldown_bar = ProgressBar.new()
    _cooldown_bar.show_percentage = false
    _cooldown_bar.custom_minimum_size = Vector2(74.0, 10.0)
    cooldown_row.add_child(_cooldown_bar)
    _health_label = Label.new()
    _health_label.text = "HP 100/100"
    _health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _health_label.add_theme_font_size_override("font_size", 9)
    _health_label.add_theme_color_override("font_color", Color("ff8ca8"))
    status.add_child(_health_label)

    _build_editor(root)

    var hint := Label.new()
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_left = 14.0
    hint.offset_top = -28.0
    hint.offset_right = 900.0
    hint.offset_bottom = -7.0
    hint.text = "LMB move • RMB cast/hold • Space dash • Q damage • R reset arena"
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color("8ea5b7"))
    root.add_child(hint)


func _build_editor(root: Control) -> void:
    _editor_panel = PanelContainer.new()
    _editor_panel.anchor_left = 0.5
    _editor_panel.anchor_right = 0.5
    _editor_panel.offset_top = 176.0
    _editor_panel.offset_bottom = 365.0
    _editor_panel.add_theme_stylebox_override("panel", _panel_style(Color("101f2b"), 0.985, Color("3c718d")))
    _editor_panel.visible = false
    _editor_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_editor_panel)

    var margin := MarginContainer.new()
    _set_margins(margin, 14)
    _editor_panel.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 9)
    margin.add_child(column)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 8)
    column.add_child(header)
    _info_label = Label.new()
    _info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _info_label.add_theme_font_size_override("font_size", 17)
    _info_label.add_theme_color_override("font_color", Color("b4edff"))
    header.add_child(_info_label)
    var clear_button := Button.new()
    clear_button.text = "CLEAR SLOT"
    clear_button.pressed.connect(_on_clear_pressed)
    header.add_child(clear_button)
    var close_button := Button.new()
    close_button.text = "CLOSE"
    close_button.pressed.connect(_close_editor)
    header.add_child(close_button)

    var selector_row := HBoxContainer.new()
    selector_row.add_theme_constant_override("separation", 8)
    column.add_child(selector_row)
    selector_row.add_child(_field_label("CATEGORY", 74.0))
    _category_selector = OptionButton.new()
    _category_selector.custom_minimum_size.x = 170.0
    _category_selector.item_selected.connect(_on_category_selected)
    selector_row.add_child(_category_selector)
    selector_row.add_child(_field_label("COMPONENT", 88.0))
    _component_selector = OptionButton.new()
    _component_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _component_selector.item_selected.connect(_on_component_selected)
    selector_row.add_child(_component_selector)
    _apply_selection_button = Button.new()
    _apply_selection_button.text = "APPLY TO SLOT"
    _apply_selection_button.custom_minimum_size.x = 130.0
    _apply_selection_button.pressed.connect(_on_apply_selection)
    selector_row.add_child(_apply_selection_button)

    _trigger_controls = VBoxContainer.new()
    _trigger_controls.add_theme_constant_override("separation", 5)
    column.add_child(_trigger_controls)
    var trigger_caption := Label.new()
    trigger_caption.text = "TRIGGER SETTINGS"
    trigger_caption.add_theme_font_size_override("font_size", 11)
    trigger_caption.add_theme_color_override("font_color", Color("ffc36b"))
    _trigger_controls.add_child(trigger_caption)
    var common_row := HBoxContainer.new()
    common_row.add_theme_constant_override("separation", 5)
    _trigger_controls.add_child(common_row)
    _every_n = _add_spin(common_row, "Every N", 1.0, 20.0, 1.0, 1.0)
    _chance = _add_spin(common_row, "Chance %", 0.0, 100.0, 0.1, 100.0)
    _internal_cooldown = _add_spin(common_row, "ICD", 0.0, 5.0, 0.01, 0.08)
    _health_ratio = _add_spin(common_row, "Max HP %", 0.0, 100.0, 1.0, 100.0)
    common_row.add_child(_field_label("Target status", 84.0))
    _status_selector = OptionButton.new()
    _status_selector.custom_minimum_size.x = 118.0
    for status_name: StringName in [&"any", &"ignite", &"freeze", &"electrified", &"stun", &"bleed", &"poison"]:
        _status_selector.add_item(String(status_name).capitalize())
        _status_selector.set_item_metadata(_status_selector.item_count - 1, status_name)
    common_row.add_child(_status_selector)
    _damage_threshold_row = HBoxContainer.new()
    _trigger_controls.add_child(_damage_threshold_row)
    _damage_threshold = _add_spin(_damage_threshold_row, "Accumulated damage % max HP", 1.0, 100.0, 1.0, 10.0)
    _channel_interval_row = HBoxContainer.new()
    _trigger_controls.add_child(_channel_interval_row)
    _channel_interval = _add_spin(_channel_interval_row, "Channel interval", 0.05, 5.0, 0.05, 0.5)

    _draft_label = Label.new()
    _draft_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _draft_label.custom_minimum_size.y = 42.0
    _draft_label.add_theme_font_size_override("font_size", 11)
    column.add_child(_draft_label)


func _field_label(text: String, width: float) -> Label:
    var label := Label.new()
    label.text = text
    label.custom_minimum_size.x = width
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 10)
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
    parent.add_child(_field_label(label_text, maxf(48.0, label_text.length() * 5.8)))
    var spin := SpinBox.new()
    spin.min_value = minimum
    spin.max_value = maximum
    spin.step = step
    spin.value = value
    spin.custom_minimum_size.x = 66.0
    parent.add_child(spin)
    return spin


func _open_editor(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= SixLinkBuild.MAX_SLOTS:
        return
    var slot := _build.get_slot(slot_index)
    if slot.is_empty() and not _slot_can_be_filled(slot_index):
        return
    _selected_slot_index = slot_index
    _editor_panel.visible = true
    var current := SkillCatalog.get_component(slot.component_id)
    _info_label.text = "SLOT %d  ·  %s" % [
        slot_index + 1,
        "CHOOSE ROOT CORE" if slot_index == 0 else "CHOOSE COMPONENT",
    ]
    _active_category = _preferred_category(slot_index, current)
    _refreshing_selectors = true
    _populate_categories()
    _populate_components(_active_category)
    if current != null:
        _select_metadata(_component_selector, current.component_id)
    _load_trigger_config(slot.trigger_config)
    _refreshing_selectors = false
    _refresh_selection_state()
    _refresh_slots()


func _close_editor() -> void:
    _selected_slot_index = -1
    if _editor_panel != null:
        _editor_panel.visible = false
    _refresh_slots()


func _preferred_category(slot_index: int, current: SkillComponent) -> StringName:
    if slot_index == 0 or _previous_slot_is_trigger(slot_index):
        return &"Core"
    if current != null:
        return current.category
    return &"Pattern"


func _populate_categories() -> void:
    _category_selector.clear()
    var categories: Array[StringName] = []
    if _selected_slot_index == 0 or _previous_slot_is_trigger(_selected_slot_index):
        categories.append(&"Core")
    else:
        categories.assign(SkillCatalog.CATEGORY_ORDER)
    if _active_category not in categories:
        _active_category = categories[0]
    for category: StringName in categories:
        _category_selector.add_item(SkillCatalog.get_category_label(category))
        _category_selector.set_item_metadata(_category_selector.item_count - 1, category)
    _select_metadata(_category_selector, _active_category)


func _populate_components(category: StringName) -> void:
    _active_category = category
    _component_selector.clear()
    var first_selectable := -1
    for candidate: Dictionary in get_available_candidates(_selected_slot_index, category, true):
        var component := SkillCatalog.get_component(StringName(candidate["component_id"]))
        if component == null:
            continue
        var valid := bool(candidate["valid"])
        var pending := bool(candidate["pending"])
        var selectable := valid or pending
        var prefix := "" if valid else ("→ " if pending else "⚠ ")
        var suffix := "  ·  next slot must be Core" if pending else ""
        _component_selector.add_item(prefix + component.display_name + suffix)
        var item_index := _component_selector.item_count - 1
        _component_selector.set_item_metadata(item_index, component.component_id)
        _component_selector.set_item_disabled(item_index, not selectable)
        _component_selector.set_item_tooltip(item_index, component.summary if valid else "%s\n\n%s" % [
            component.summary,
            "Select this Trigger, then choose its Core in the next slot." if pending else candidate["reason"],
        ])
        if selectable and first_selectable < 0:
            first_selectable = item_index
    if first_selectable >= 0:
        _component_selector.select(first_selectable)
    elif _component_selector.item_count > 0:
        _component_selector.select(0)


func _selected_component_id() -> StringName:
    if _component_selector.item_count == 0 or _component_selector.selected < 0:
        return &""
    return StringName(_component_selector.get_item_metadata(_component_selector.selected))


func _on_apply_selection() -> void:
    var component_id := _selected_component_id()
    if _selected_slot_index < 0 or component_id == &"":
        return
    var edited_slot := _selected_slot_index
    var previous_slot := _build.get_slot(edited_slot)
    var was_empty := previous_slot == null or previous_slot.is_empty()
    var component := SkillCatalog.get_component(component_id)
    var config := _make_trigger_config() if component != null and component.is_trigger() else null
    edit_slot(edited_slot, component_id, config)
    if was_empty and edited_slot < SixLinkBuild.MAX_SLOTS - 1:
        _open_editor(edited_slot + 1)
        return
    _open_editor(edited_slot)


func _refresh_selection_state() -> void:
    if _selected_slot_index < 0:
        _trigger_controls.visible = false
        return
    var component_id := _selected_component_id()
    var component := SkillCatalog.get_component(component_id)
    var is_trigger := component != null and component.is_trigger()
    _trigger_controls.visible = is_trigger
    _editor_panel.offset_bottom = 475.0 if is_trigger else 365.0
    _damage_threshold_row.visible = is_trigger and component_id == &"trigger_damage_taken"
    _channel_interval_row.visible = is_trigger and component_id == &"trigger_channel"
    if component == null:
        _apply_selection_button.disabled = true
        _draft_label.text = "Choose a Component."
        _draft_label.add_theme_color_override("font_color", INVALID_COLOR)
        return
    var config := _make_trigger_config() if is_trigger else null
    var state := SkillCompiler.get_candidate_state(_build, _selected_slot_index, component_id, config)
    var pending := _is_forward_pending_trigger(component, _selected_slot_index, state)
    _apply_selection_button.disabled = not state.valid and not pending
    if state.valid:
        _draft_label.text = "%s  ·  Compatible with this slot." % component.summary
        _draft_label.add_theme_color_override("font_color", VALID_COLOR)
    elif pending:
        _draft_label.text = "%s  ·  Apply it, then choose a Core in Slot %d." % [
            component.summary,
            _selected_slot_index + 2,
        ]
        _draft_label.add_theme_color_override("font_color", Color("ffc56f"))
    else:
        _draft_label.text = "%s  ·  %s" % [component.summary, state.reason]
        _draft_label.add_theme_color_override("font_color", INVALID_COLOR)


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


func _refresh_slots() -> void:
    if _slot_buttons.size() != SixLinkBuild.MAX_SLOTS:
        return
    var errors_by_slot: Dictionary = {}
    for error: String in _build.validation_errors:
        var slot_number := _extract_slot_number(error)
        if slot_number >= 0:
            errors_by_slot[slot_number] = error
    var filled_count := 0
    for slot: SkillSlot in _build.slots:
        if not slot.is_empty():
            filled_count += 1
    if filled_count == 0:
        _build_status_label.text = "Choose a Core, then spend up to five slots on behavior."
        _build_status_label.add_theme_color_override("font_color", Color("a7bac7"))
    elif _build.is_valid():
        _build_status_label.text = "Build active  ·  Click any filled slot to replace it."
        _build_status_label.add_theme_color_override("font_color", VALID_COLOR)
    else:
        _build_status_label.text = "Draft incomplete  ·  Combat keeps the last valid build."
        _build_status_label.add_theme_color_override("font_color", INVALID_COLOR)

    for slot_index: int in SixLinkBuild.MAX_SLOTS:
        var button := _slot_buttons[slot_index]
        var slot := _build.get_slot(slot_index)
        var component := SkillCatalog.get_component(slot.component_id) if slot != null else null
        var can_fill := _slot_can_be_filled(slot_index)
        button.disabled = component == null and not can_fill
        if component == null:
            var prompt := "CHOOSE CORE" if slot_index == 0 else (
                "ADD COMPONENT" if can_fill else "FILL SLOT %d FIRST" % slot_index
            )
            button.text = "SLOT %d\n＋ %s" % [slot_index + 1, prompt]
            button.tooltip_text = "Start with a Core" if slot_index == 0 else (
                "Choose the previous slot first" if not can_fill else "Choose a Component for Slot %d" % (slot_index + 1)
            )
            var fill_color := EMPTY_SLOT_COLOR if can_fill else LOCKED_SLOT_COLOR
            var border_color := ACCENT_COLOR if can_fill else Color("314250")
            if errors_by_slot.has(slot_index):
                fill_color = INVALID_SLOT_COLOR
                border_color = INVALID_COLOR
                button.tooltip_text += "\n\n" + String(errors_by_slot[slot_index])
            _style_slot_button(button, fill_color, border_color, slot_index == _selected_slot_index)
            continue
        var owner := SkillCompiler.get_owner_core_slot(_build, slot_index)
        var binding := "ROOT CORE" if component.is_core() and slot_index == 0 else (
            "TRIGGERED CORE" if component.is_core() else "CORE %d" % (owner + 1)
        )
        button.text = "SLOT %d  ·  %s\n%s  →  %s" % [
            slot_index + 1,
            component.category.to_upper(),
            component.display_name,
            binding,
        ]
        button.tooltip_text = component.summary
        var fill_color := ACTIVE_SLOT_COLOR
        var border_color := _category_color(component.category)
        if errors_by_slot.has(slot_index):
            fill_color = INVALID_SLOT_COLOR
            border_color = INVALID_COLOR
            button.tooltip_text += "\n\n" + String(errors_by_slot[slot_index])
        _style_slot_button(button, fill_color, border_color, slot_index == _selected_slot_index)


func _style_slot_button(button: Button, fill: Color, border: Color, selected: bool) -> void:
    button.add_theme_stylebox_override("normal", _button_style(fill, border, 3 if selected else 1))
    button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.08), border.lightened(0.18), 2))
    button.add_theme_stylebox_override("pressed", _button_style(fill.lightened(0.13), ACCENT_COLOR, 3))
    button.add_theme_stylebox_override("disabled", _button_style(LOCKED_SLOT_COLOR, Color("2b3a46"), 1))
    button.add_theme_color_override("font_color", Color("e9f8ff"))
    button.add_theme_color_override("font_disabled_color", Color("62717c"))


func _slot_can_be_filled(slot_index: int) -> bool:
    if slot_index == 0:
        return true
    var current := _build.get_slot(slot_index)
    if current != null and not current.is_empty():
        return true
    var previous := _build.get_slot(slot_index - 1)
    return previous != null and not previous.is_empty()


func _previous_slot_is_trigger(slot_index: int) -> bool:
    if slot_index <= 0:
        return false
    var previous := _build.get_slot(slot_index - 1)
    var component := SkillCatalog.get_component(previous.component_id) if previous != null else null
    return component != null and component.is_trigger()


func _is_forward_pending_trigger(
        component: SkillComponent,
        slot_index: int,
        state: NodeCompatibility
) -> bool:
    if component == null or not component.is_trigger() or state.valid:
        return false
    if slot_index >= SixLinkBuild.MAX_SLOTS - 1:
        return false
    var next_slot := _build.get_slot(slot_index + 1)
    if next_slot == null or not next_slot.is_empty():
        return false
    var reasons := state.reason.split("\n", false)
    if reasons.is_empty():
        return false
    for reason: String in reasons:
        if (
            not reason.contains("must be immediately followed by a Core")
            and not reason.contains("Trigger has no target Core")
            and reason != "Trigger chain is incomplete"
        ):
            return false
    return true


func _extract_slot_number(error: String) -> int:
    if not error.begins_with("Slot "):
        return -1
    var suffix := error.trim_prefix("Slot ")
    var separator := suffix.find(":")
    if separator < 0:
        separator = suffix.find(" ")
    return int(suffix.left(separator)) - 1 if separator > 0 else -1


func _on_clear_pressed() -> void:
    if _selected_slot_index < 0:
        return
    var slot_index := _selected_slot_index
    clear_slot(slot_index)
    _open_editor(slot_index)


func _on_category_selected(index: int) -> void:
    if _refreshing_selectors or index < 0:
        return
    _active_category = StringName(_category_selector.get_item_metadata(index))
    _refreshing_selectors = true
    _populate_components(_active_category)
    _refreshing_selectors = false
    _load_config_for_selected_component()
    _refresh_selection_state()


func _on_component_selected(_index: int) -> void:
    if _refreshing_selectors:
        return
    _load_config_for_selected_component()
    _refresh_selection_state()


func _load_config_for_selected_component() -> void:
    var selected_id := _selected_component_id()
    var slot := _build.get_slot(_selected_slot_index) if _selected_slot_index >= 0 else null
    if (
        slot != null
        and slot.component_id == selected_id
        and slot.trigger_config != null
    ):
        _load_trigger_config(slot.trigger_config)
        return
    _load_trigger_config(null)


func _select_metadata(selector: OptionButton, metadata: Variant) -> void:
    for item_index: int in selector.item_count:
        if selector.get_item_metadata(item_index) == metadata:
            selector.select(item_index)
            return


func _refresh_runtime_summary() -> void:
    if _runtime_build == null:
        _active_build_label.text = "NONE"
        _runtime_stats_base = "Choose Slot 1 to enable casting"
        _stats_label.text = _runtime_stats_base
        return
    _stats_label.text = _runtime_stats_base


func _apply_responsive_layout() -> void:
    if _builder_panel == null or _editor_panel == null:
        return
    var viewport_width := float(get_viewport().get_visible_rect().size.x)
    var panel_width := minf(maxf(viewport_width - 28.0, 920.0), 1380.0)
    _builder_panel.offset_left = -panel_width * 0.5
    _builder_panel.offset_right = panel_width * 0.5
    var editor_width := minf(maxf(viewport_width - 80.0, 900.0), 1220.0)
    _editor_panel.offset_left = -editor_width * 0.5
    _editor_panel.offset_right = editor_width * 0.5


func _set_margins(container: MarginContainer, margin: int) -> void:
    container.add_theme_constant_override("margin_left", margin)
    container.add_theme_constant_override("margin_top", margin)
    container.add_theme_constant_override("margin_right", margin)
    container.add_theme_constant_override("margin_bottom", margin)


func _category_color(category: StringName) -> Color:
    return {
        &"Core": Color("70d7ff"),
        &"Trigger": Color("ffc56f"),
        &"Trajectory": Color("8dd5ff"),
        &"Shape": Color("ba9bff"),
        &"Pattern": Color("7ce6be"),
        &"Effect": Color("ff8eaa"),
        &"Transform": Color("ffd978"),
    }.get(category, Color("91a9b8")) as Color


func _panel_style(color: Color, opacity: float, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(color, opacity)
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    return style


func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(7)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    return style
