class_name PrototypeHud
extends CanvasLayer

signal graph_changed(graph: SkillGraph)
signal reset_requested

const CONCEPT_LIBRARY := preload("res://scripts/concept_library.gd")

var _graph: SkillGraph
var _runtime_graph: SkillGraph
var _slot_buttons: Array[Button] = []
var _selected_node_id: int = -1
var _editor_panel: PanelContainer
var _kind_selector: OptionButton
var _concept_selector: OptionButton
var _parent_selector: OptionButton
var _show_all_toggle: CheckButton
var _trigger_controls: HBoxContainer
var _every_n: SpinBox
var _chance: SpinBox
var _internal_cooldown: SpinBox
var _health_ratio: SpinBox
var _status_selector: OptionButton
var _info_label: Label
var _stats_label: Label
var _cooldown_bar: ProgressBar
var _cooldown_label: Label
var _health_label: Label
var _refreshing: bool = false


func _ready() -> void:
    add_to_group("concept_builder_ui")
    _graph = CONCEPT_LIBRARY.get_default_graph()
    _runtime_graph = _graph
    _build_interface()
    _refresh_slots()


func get_graph() -> SkillGraph:
    return _graph


func get_selected_nodes() -> Array[SkillGraphNode]:
    var result: Array[SkillGraphNode] = []
    for node: SkillGraphNode in _graph.nodes:
        result.append(node.copy_node())
    return result


func set_runtime_graph(graph: SkillGraph) -> void:
    if graph == null or not graph.is_valid():
        return
    _runtime_graph = graph
    var definition := graph.get_primary_skill()
    _stats_label.text = "DMG %.0f  CD %.2f  ×%d" % [
        definition.damage,
        definition.cooldown,
        definition.projectile_count,
    ]
    _stats_label.tooltip_text = "%s\n能力：%s" % [definition.get_stats_text(), definition.get_tags_text()]
    _stats_label.add_theme_color_override("font_color", definition.color.lightened(0.18))


func update_runtime_budget(executor: SkillGraphExecutor) -> void:
    if executor == null:
        return
    _stats_label.text = "%s  E%d Q%d P%d" % [
        _stats_label.text.split("  E")[0],
        int(executor.counters["events_rejected"]),
        executor.get_queue_size(),
        executor.get_active_projectile_count(),
    ]


func update_cooldown(remaining: float, duration: float) -> void:
    _cooldown_bar.max_value = maxf(duration, 0.01)
    _cooldown_bar.value = maxf(duration - remaining, 0.0)
    _cooldown_label.text = "READY" if remaining <= 0.0 else "%.2fs" % remaining


func update_player_health(current_health: float, max_health: float) -> void:
    _health_label.text = "HP %.0f/%.0f" % [current_health, max_health]


func log_event(_message: String, _event_color: Color = Color.WHITE) -> void:
    pass


func edit_node(
        node_id: int,
        concept_id: StringName,
        parent_node_id: int,
        trigger_config: TriggerConfig = null
) -> bool:
    var state := CONCEPT_LIBRARY.preview_edit(_graph, {
        "node_id": node_id,
        "concept_id": concept_id,
        "parent_node_id": parent_node_id,
        "trigger_config": trigger_config,
    })
    if not state.valid:
        return false
    _graph = state.result.graph
    _refresh_slots()
    graph_changed.emit(_graph)
    return true


func clear_node(node_id: int) -> void:
    edit_node(node_id, &"", SkillGraph.ROOT_PARENT)


func reset_build() -> void:
    _graph = CONCEPT_LIBRARY.get_default_graph()
    _runtime_graph = _graph
    _close_editor()
    _refresh_slots()
    graph_changed.emit(_graph)


func get_available_candidates(
        node_id: int,
        kind: StringName,
        show_all: bool = false
) -> Array[Dictionary]:
    var candidates: Array[Dictionary] = []
    for concept: SkillConcept in CONCEPT_LIBRARY.get_concepts_by_kind(kind):
        var parent_choice := _find_parent_choice(node_id, concept.concept_id)
        var valid := bool(parent_choice.get("valid", false))
        if valid or show_all:
            candidates.append({
                "concept_id": concept.concept_id,
                "parent_node_id": int(parent_choice.get("parent", SkillGraph.ROOT_PARENT)),
                "valid": valid,
                "reason": String(parent_choice.get("reason", "")),
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
    panel.offset_left = -620.0
    panel.offset_top = 10.0
    panel.offset_right = 620.0
    panel.offset_bottom = 78.0
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
    strip.add_theme_constant_override("separation", 5)
    margin.add_child(strip)

    var title := Label.new()
    title.text = "SKILL\nGRAPH"
    title.custom_minimum_size.x = 58.0
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_color_override("font_color", Color("8bd8ff"))
    strip.add_child(title)
    for node_id: int in SkillGraph.MAX_NODES:
        if node_id > 0:
            var divider := Label.new()
            divider.text = "·"
            divider.add_theme_color_override("font_color", Color("56758d"))
            strip.add_child(divider)
        var button := Button.new()
        button.custom_minimum_size = Vector2(130.0, 50.0)
        button.clip_text = true
        button.add_theme_font_size_override("font_size", 12)
        button.pressed.connect(_open_editor.bind(node_id))
        strip.add_child(button)
        _slot_buttons.append(button)

    var status := VBoxContainer.new()
    status.custom_minimum_size.x = 190.0
    status.add_theme_constant_override("separation", 1)
    strip.add_child(status)
    _stats_label = Label.new()
    _stats_label.text = "DMG 32  CD .55  ×1"
    _stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _stats_label.add_theme_font_size_override("font_size", 11)
    status.add_child(_stats_label)
    var cooldown_row := HBoxContainer.new()
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
    hint.offset_left = 12.0
    hint.offset_top = -29.0
    hint.offset_right = 910.0
    hint.offset_bottom = -8.0
    hint.text = "左鍵/WASD 移動　右鍵攻擊　Shift+左鍵原地攻擊　Space Dash　Q 受傷　R 重置"
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9, 0.62))
    root.add_child(hint)


func _build_editor(root: Control) -> void:
    _editor_panel = PanelContainer.new()
    _editor_panel.anchor_left = 0.5
    _editor_panel.anchor_right = 0.5
    _editor_panel.offset_left = -550.0
    _editor_panel.offset_top = 84.0
    _editor_panel.offset_right = 550.0
    _editor_panel.offset_bottom = 218.0
    _editor_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.05, 0.075, 0.97)))
    _editor_panel.visible = false
    root.add_child(_editor_panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_top", 7)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_bottom", 7)
    _editor_panel.add_child(margin)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    margin.add_child(content)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 7)
    content.add_child(row)
    _kind_selector = OptionButton.new()
    _kind_selector.custom_minimum_size.x = 150.0
    for kind: StringName in CONCEPT_LIBRARY.KIND_ORDER:
        _kind_selector.add_item(CONCEPT_LIBRARY.get_kind_label(kind))
        _kind_selector.set_item_metadata(_kind_selector.item_count - 1, kind)
    _kind_selector.item_selected.connect(_on_kind_selected)
    row.add_child(_kind_selector)
    _concept_selector = OptionButton.new()
    _concept_selector.custom_minimum_size.x = 180.0
    _concept_selector.item_selected.connect(_on_concept_selected)
    row.add_child(_concept_selector)
    _parent_selector = OptionButton.new()
    _parent_selector.custom_minimum_size.x = 170.0
    _parent_selector.item_selected.connect(_on_parent_selected)
    row.add_child(_parent_selector)
    _show_all_toggle = CheckButton.new()
    _show_all_toggle.text = "顯示全部"
    _show_all_toggle.toggled.connect(_on_show_all_toggled)
    row.add_child(_show_all_toggle)
    var clear_button := Button.new()
    clear_button.text = "清空"
    clear_button.pressed.connect(_on_clear_pressed)
    row.add_child(clear_button)
    var close_button := Button.new()
    close_button.text = "收合"
    close_button.pressed.connect(_close_editor)
    row.add_child(close_button)

    _trigger_controls = HBoxContainer.new()
    _trigger_controls.add_theme_constant_override("separation", 5)
    content.add_child(_trigger_controls)
    _every_n = _add_spin_control(_trigger_controls, "每 N 次", 1.0, 20.0, 1.0, 1.0)
    _chance = _add_spin_control(_trigger_controls, "機率 %", 0.0, 100.0, 1.0, 100.0)
    _internal_cooldown = _add_spin_control(_trigger_controls, "內冷 s", 0.0, 5.0, 0.01, 0.08)
    _health_ratio = _add_spin_control(_trigger_controls, "血量 ≤%", 0.0, 100.0, 1.0, 100.0)
    var status_label := Label.new()
    status_label.text = "目標狀態"
    _trigger_controls.add_child(status_label)
    _status_selector = OptionButton.new()
    for item: Dictionary in [
        {"id": &"any", "name": "任意"}, {"id": &"burn", "name": "燃燒"},
        {"id": &"poison", "name": "中毒"}, {"id": &"frozen", "name": "凍結"},
    ]:
        _status_selector.add_item(String(item["name"]))
        _status_selector.set_item_metadata(_status_selector.item_count - 1, item["id"])
    _status_selector.item_selected.connect(_on_trigger_config_changed)
    _trigger_controls.add_child(_status_selector)
    _info_label = Label.new()
    _info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _info_label.add_theme_font_size_override("font_size", 11)
    _info_label.add_theme_color_override("font_color", Color("a9c2d4"))
    content.add_child(_info_label)


func _add_spin_control(
        parent: HBoxContainer,
        label_text: String,
        minimum: float,
        maximum: float,
        step: float,
        initial: float
) -> SpinBox:
    var label := Label.new()
    label.text = label_text
    parent.add_child(label)
    var spin := SpinBox.new()
    spin.min_value = minimum
    spin.max_value = maximum
    spin.step = step
    spin.value = initial
    spin.custom_minimum_size.x = 78.0
    spin.value_changed.connect(_on_trigger_config_changed)
    parent.add_child(spin)
    return spin


func _open_editor(node_id: int) -> void:
    _selected_node_id = node_id
    _editor_panel.visible = true
    _refresh_editor()


func _close_editor() -> void:
    _selected_node_id = -1
    if _editor_panel != null:
        _editor_panel.visible = false


func _refresh_editor() -> void:
    if _selected_node_id < 0:
        return
    _refreshing = true
    var node := _graph.get_graph_node(_selected_node_id)
    var concept := CONCEPT_LIBRARY.get_concept(node.concept_id)
    var kind := concept.concept_kind if concept != null else &"Skill"
    _select_metadata(_kind_selector, kind)
    _populate_concepts(kind, node.concept_id)
    _populate_parents(node.concept_id, node.parent_node_id)
    _load_trigger_config(node.trigger_config)
    _trigger_controls.visible = concept != null and concept.concept_kind == &"Trigger"
    _refresh_editor_info()
    _refreshing = false


func _populate_concepts(kind: StringName, selected_concept_id: StringName = &"") -> void:
    _concept_selector.clear()
    var candidates := get_available_candidates(_selected_node_id, kind, _show_all_toggle.button_pressed)
    for candidate: Dictionary in candidates:
        var concept := CONCEPT_LIBRARY.get_concept(StringName(candidate["concept_id"]))
        _concept_selector.add_item(concept.display_name)
        var option_index := _concept_selector.item_count - 1
        _concept_selector.set_item_metadata(option_index, candidate)
        _concept_selector.set_item_disabled(option_index, not bool(candidate["valid"]))
        _concept_selector.get_popup().set_item_tooltip(option_index, String(candidate["reason"]))
        if concept.concept_id == selected_concept_id:
            _concept_selector.select(option_index)
    if _concept_selector.item_count == 0:
        _concept_selector.add_item("沒有相容選項")
        _concept_selector.set_item_disabled(0, true)


func _populate_parents(concept_id: StringName, selected_parent_id: int) -> void:
    _parent_selector.clear()
    if concept_id == &"":
        return
    var parents := CONCEPT_LIBRARY.get_parent_candidates(_graph, _selected_node_id, concept_id)
    for parent: Dictionary in parents:
        _parent_selector.add_item(String(parent["name"]))
        _parent_selector.set_item_metadata(_parent_selector.item_count - 1, int(parent["id"]))
        if int(parent["id"]) == selected_parent_id:
            _parent_selector.select(_parent_selector.item_count - 1)


func _find_parent_choice(node_id: int, concept_id: StringName) -> Dictionary:
    var current := _graph.get_graph_node(node_id)
    var parents := CONCEPT_LIBRARY.get_parent_candidates(_graph, node_id, concept_id)
    parents.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int(left["id"]) == current.parent_node_id and int(right["id"]) != current.parent_node_id
    )
    var reasons: PackedStringArray = []
    for parent: Dictionary in parents:
        var state := CONCEPT_LIBRARY.get_candidate_state(
            _graph,
            node_id,
            concept_id,
            int(parent["id"]),
            current.trigger_config
        )
        if state.valid:
            return {"valid": true, "parent": int(parent["id"]), "reason": state.reason}
        reasons.append(state.reason)
    return {
        "valid": false,
        "parent": int(parents[0]["id"]) if not parents.is_empty() else SkillGraph.ROOT_PARENT,
        "reason": reasons[0] if not reasons.is_empty() else "目前沒有可連接的父節點",
    }


func _on_kind_selected(_index: int) -> void:
    if _refreshing:
        return
    _refreshing = true
    var kind := _kind_selector.get_item_metadata(_kind_selector.selected) as StringName
    _populate_concepts(kind)
    _refreshing = false


func _on_concept_selected(index: int) -> void:
    if _refreshing or index < 0:
        return
    var metadata: Variant = _concept_selector.get_item_metadata(index)
    if not metadata is Dictionary:
        return
    var candidate := metadata as Dictionary
    var concept_id := StringName(candidate["concept_id"])
    _refreshing = true
    _populate_parents(concept_id, int(candidate["parent_node_id"]))
    _refreshing = false
    _commit_editor(concept_id)


func _on_parent_selected(_index: int) -> void:
    if _refreshing:
        return
    _commit_editor(_selected_concept_id())


func _on_show_all_toggled(_pressed: bool) -> void:
    if _refreshing:
        return
    var kind := _kind_selector.get_item_metadata(_kind_selector.selected) as StringName
    _refreshing = true
    _populate_concepts(kind, _selected_concept_id())
    _refreshing = false


func _on_trigger_config_changed(_value: Variant = null) -> void:
    if _refreshing:
        return
    var concept := CONCEPT_LIBRARY.get_concept(_selected_concept_id())
    if concept != null and concept.concept_kind == &"Trigger":
        _commit_editor(concept.concept_id)


func _on_clear_pressed() -> void:
    if _selected_node_id >= 0:
        clear_node(_selected_node_id)
        _refresh_editor()


func _commit_editor(concept_id: StringName) -> void:
    if concept_id == &"" or _parent_selector.item_count == 0:
        return
    var parent_id := int(_parent_selector.get_item_metadata(_parent_selector.selected))
    var concept := CONCEPT_LIBRARY.get_concept(concept_id)
    var config := _read_trigger_config() if concept != null and concept.concept_kind == &"Trigger" else null
    var state := CONCEPT_LIBRARY.preview_edit(_graph, {
        "node_id": _selected_node_id,
        "concept_id": concept_id,
        "parent_node_id": parent_id,
        "trigger_config": config,
    })
    if not state.valid:
        _info_label.text = state.reason.replace("\n", "　")
        _info_label.add_theme_color_override("font_color", Color("ff7b87"))
        return
    _graph = state.result.graph
    _refresh_slots()
    _refresh_editor_info()
    graph_changed.emit(_graph)


func _selected_concept_id() -> StringName:
    if _concept_selector.item_count == 0 or _concept_selector.selected < 0:
        return &""
    var metadata: Variant = _concept_selector.get_item_metadata(_concept_selector.selected)
    if metadata is Dictionary:
        return StringName((metadata as Dictionary).get("concept_id", &""))
    return &""


func _read_trigger_config() -> TriggerConfig:
    var config := TriggerConfig.new()
    config.every_n = int(_every_n.value)
    config.chance = float(_chance.value)
    config.internal_cooldown = float(_internal_cooldown.value)
    config.max_player_health_ratio = float(_health_ratio.value) / 100.0
    config.required_target_status = _status_selector.get_item_metadata(_status_selector.selected) as StringName
    return config


func _load_trigger_config(config: TriggerConfig) -> void:
    var value := config if config != null else TriggerConfig.new()
    _every_n.value = value.every_n
    _chance.value = value.chance
    _internal_cooldown.value = value.internal_cooldown
    _health_ratio.value = value.max_player_health_ratio * 100.0
    _select_metadata(_status_selector, value.required_target_status)


func _refresh_editor_info() -> void:
    if _selected_node_id < 0:
        return
    var node := _graph.get_graph_node(_selected_node_id)
    if node.is_empty():
        _info_label.text = "選擇 Concept 後會先預覽編譯；只有有效圖會更新戰鬥。"
        return
    var definition := _graph.get_compiled_skill(node.node_id)
    if definition == null and node.parent_node_id >= 0:
        var parent := _graph.get_graph_node(node.parent_node_id)
        if parent != null:
            definition = _graph.get_compiled_skill(parent.node_id)
    var detail := "路徑：%s" % CONCEPT_LIBRARY.describe_path(_graph, node.node_id)
    if definition != null:
        detail += "　能力：%s　%s" % [definition.get_tags_text(), definition.get_stats_text().replace("\n", " ")]
    if not _graph.validation_errors.is_empty():
        detail += "　錯誤：%s" % "；".join(_graph.validation_errors)
    _info_label.text = detail
    _info_label.add_theme_color_override(
        "font_color",
        Color("ff7b87") if not _graph.validation_errors.is_empty() else Color("a9c2d4")
    )


func _refresh_slots() -> void:
    if _slot_buttons.size() != SkillGraph.MAX_NODES:
        return
    for node_id: int in SkillGraph.MAX_NODES:
        var node := _graph.get_graph_node(node_id)
        var button := _slot_buttons[node_id]
        if node.is_empty():
            button.text = "%d  ＋ 空白" % (node_id + 1)
            button.tooltip_text = "點擊加入節點"
            button.modulate = Color(0.72, 0.78, 0.84)
            continue
        var concept := CONCEPT_LIBRARY.get_concept(node.concept_id)
        var parent_text := "ROOT" if node.parent_node_id == SkillGraph.ROOT_PARENT else (
            "PLAYER" if node.parent_node_id == SkillGraph.PLAYER_EVENT_PARENT else "↳%d" % (node.parent_node_id + 1)
        )
        button.text = "%d  %s\n%s" % [node_id + 1, concept.display_name, parent_text]
        button.tooltip_text = "%s\n%s" % [CONCEPT_LIBRARY.get_kind_label(concept.concept_kind), CONCEPT_LIBRARY.describe_path(_graph, node_id)]
        button.modulate = Color("ff7888") if _node_has_error(node_id) else Color.WHITE
    if _runtime_graph != null and _runtime_graph.is_valid():
        set_runtime_graph(_runtime_graph)


func _node_has_error(node_id: int) -> bool:
    var marker := "第 %d 格" % (node_id + 1)
    for error: String in _graph.validation_errors:
        if error.contains(marker):
            return true
    return false


func _select_metadata(selector: OptionButton, metadata: Variant) -> void:
    for index: int in selector.item_count:
        if selector.get_item_metadata(index) == metadata:
            selector.select(index)
            return


func _panel_style(background: Color = Color(0.025, 0.038, 0.058, 0.92)) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = Color("27445d")
    style.set_border_width_all(1)
    style.corner_radius_top_left = 7
    style.corner_radius_top_right = 7
    style.corner_radius_bottom_left = 7
    style.corner_radius_bottom_right = 7
    return style
