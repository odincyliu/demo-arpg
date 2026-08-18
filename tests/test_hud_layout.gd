extends SceneTree


func _init() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var failures: PackedStringArray = []
    var packed_scene := load("res://main.tscn") as PackedScene
    var main_scene := packed_scene.instantiate()
    root.add_child(main_scene)
    current_scene = main_scene
    await process_frame
    await physics_frame
    var hud := get_first_node_in_group("six_link_builder_ui") as PrototypeHud
    var player := get_first_node_in_group("player") as PlayerController
    if hud == null or player == null:
        failures.append("Six-Link HUD or Player was not created")
        await _finish(main_scene, failures)
        return

    var initial_slots := hud.get_selected_slots()
    if initial_slots.size() != SixLinkBuild.MAX_SLOTS:
        failures.append("HUD did not create exactly six draft slots")
    else:
        for slot: SkillSlot in initial_slots:
            if not slot.is_empty():
                failures.append("New HUD did not start with six empty slots")
                break
    if player.current_build != null:
        failures.append("Empty startup draft unexpectedly enabled a Runtime build")

    var buttons := hud.get("_slot_buttons") as Array
    if buttons.size() != SixLinkBuild.MAX_SLOTS:
        failures.append("HUD did not expose exactly six slot cards")
    elif (buttons[0] as Button).disabled or not (buttons[1] as Button).disabled:
        failures.append("Empty HUD did not guide selection from Slot 1")

    for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
        DisplayServer.window_set_size(viewport_size)
        await process_frame
        for button_index: int in buttons.size():
            var button := buttons[button_index] as Button
            var rect := button.get_global_rect()
            if rect.position.x < 0.0 or rect.end.x > float(viewport_size.x):
                failures.append("Slot %d clipped at %s" % [button_index + 1, viewport_size])
        hud.call("_open_editor", 0)
        await process_frame
        var editor := hud.get("_editor_panel") as PanelContainer
        var editor_rect := editor.get_global_rect()
        if not editor.visible or editor_rect.position.x < 0.0 or editor_rect.end.x > float(viewport_size.x):
            failures.append("Component picker clipped at %s" % viewport_size)
        if editor_rect.size.y > 240.0:
            failures.append("Non-Trigger picker was not compact at %s" % viewport_size)
        hud.call("_close_editor")

    hud.call("_open_editor", 0)
    var category_selector := hud.get("_category_selector") as OptionButton
    if category_selector.item_count != 1 or category_selector.get_item_metadata(0) != &"Core":
        failures.append("Slot 1 picker was not locked to the Core category")
    var component_selector := hud.get("_component_selector") as OptionButton
    if component_selector.item_count != 14:
        failures.append("Slot 1 Component dropdown did not list all 14 Cores")

    hud.call("_select_metadata", component_selector, &"core_frost_lance")
    hud.call("_on_apply_selection")
    await process_frame
    if hud.get_build().get_slot(0).component_id != &"core_frost_lance":
        failures.append("Clicking a Component card did not fill Slot 1")
    if int(hud.get("_selected_slot_index")) != 1:
        failures.append("Filling an empty slot did not advance to the next slot")
    category_selector = hud.get("_category_selector") as OptionButton
    if category_selector.item_count != SkillCatalog.CATEGORY_ORDER.size():
        failures.append("Slot 2 Category dropdown did not expose all document categories")
    else:
        for category_index: int in SkillCatalog.CATEGORY_ORDER.size():
            if category_selector.get_item_metadata(category_index) != SkillCatalog.CATEGORY_ORDER[category_index]:
                failures.append("Category dropdown order diverged from the V1 document")
                break
    if player.current_build == null or not player.current_build.is_valid():
        failures.append("First valid Core did not become the active Runtime build")
    if (buttons[1] as Button).disabled:
        failures.append("Slot 2 did not unlock after filling Slot 1")
    var trigger_candidates := hud.get_available_candidates(1, &"Trigger", true)
    var saw_pending_trigger := false
    for candidate: Dictionary in trigger_candidates:
        if candidate["component_id"] == &"trigger_hit" and bool(candidate["pending"]):
            saw_pending_trigger = true
    if not saw_pending_trigger:
        failures.append("Forward-completable Trigger was not presented as a next-Core draft")

    var active_before: SixLinkBuild = player.current_build
    hud.clear_slot(0)
    await process_frame
    if hud.get_build().is_valid():
        failures.append("Clearing Slot 1 did not preserve an invalid empty draft")
    if player.current_build != active_before or not player.current_build.is_valid():
        failures.append("Invalid empty draft replaced the last valid Runtime build")

    hud.load_default_preset()
    await process_frame
    var expected_preset: Array[StringName] = [
        &"core_frost_lance", &"pattern_multishot", &"pattern_hold",
        &"effect_freeze", &"trigger_freeze", &"core_shockwave",
    ]
    for slot_index: int in expected_preset.size():
        if hud.get_build().get_slot(slot_index).component_id != expected_preset[slot_index]:
            failures.append("Frost preset did not populate Slot %d" % (slot_index + 1))

    for slot_index: int in range(1, SixLinkBuild.MAX_SLOTS):
        hud.clear_slot(slot_index)
    hud.edit_slot(0, &"core_slash")
    hud.edit_slot(1, &"trigger_damage_taken", TriggerConfig.new())
    hud.edit_slot(2, &"core_summon")
    hud.call("_open_editor", 1)
    if not (hud.get("_trigger_controls") as VBoxContainer).visible:
        failures.append("Selecting a Trigger slot did not reveal advanced settings")
    if not (hud.get("_damage_threshold_row") as HBoxContainer).visible:
        failures.append("On Damage Taken did not reveal its accumulated-damage field")
    if (hud.get("_channel_interval_row") as HBoxContainer).visible:
        failures.append("On Damage Taken incorrectly displayed Channel interval")
    hud.call("_close_editor")

    hud.reset_build()
    hud.edit_slot(0, &"core_void_beam")
    hud.edit_slot(1, &"trigger_channel", TriggerConfig.new())
    hud.edit_slot(2, &"core_meteor")
    hud.call("_open_editor", 1)
    if not (hud.get("_channel_interval_row") as HBoxContainer).visible:
        failures.append("Channel Trigger did not reveal its interval field")
    if (hud.get("_damage_threshold_row") as HBoxContainer).visible:
        failures.append("Channel Trigger incorrectly displayed damage threshold")
    hud.call("_close_editor")

    var candidates := hud.get_available_candidates(1, &"Trajectory", true)
    var saw_invalid := false
    for candidate: Dictionary in candidates:
        if not bool(candidate["valid"]) and not String(candidate["reason"]).is_empty():
            saw_invalid = true
    if not saw_invalid:
        failures.append("Component cards supplied no grey-state reason")

    hud.reset_build()
    await _finish(main_scene, failures)


func _finish(main_scene: Node, failures: PackedStringArray) -> void:
    main_scene.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: empty six-slot HUD, compact classified dropdowns, preset, and Trigger controls")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)
