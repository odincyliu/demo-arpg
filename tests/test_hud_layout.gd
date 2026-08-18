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

    for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
        DisplayServer.window_set_size(viewport_size)
        await process_frame
        var buttons := hud.get("_slot_buttons") as Array
        if buttons.size() != SixLinkBuild.MAX_SLOTS:
            failures.append("HUD did not keep six slots at %s" % viewport_size)
            continue
        for button_index: int in buttons.size():
            var button := buttons[button_index] as Button
            var rect := button.get_global_rect()
            if rect.position.x < 0.0 or rect.end.x > float(viewport_size.x):
                failures.append("Slot %d clipped at %s" % [button_index + 1, viewport_size])
        hud.call("_open_editor", 2)
        await process_frame
        var editor := hud.get("_editor_panel") as PanelContainer
        var editor_rect := editor.get_global_rect()
        if not editor.visible or editor_rect.position.x < 0.0 or editor_rect.end.x > float(viewport_size.x):
            failures.append("Editor clipped at %s" % viewport_size)
        hud.call("_close_editor")
        if editor.visible:
            failures.append("Editor did not collapse at %s" % viewport_size)

    hud.call("_open_editor", 0)
    var category_selector := hud.get("_category_selector") as OptionButton
    if category_selector.item_count != 1 or category_selector.get_item_metadata(0) != &"Core":
        failures.append("Slot 1 category was not locked to Core")
    hud.call("_close_editor")

    var active_before: SixLinkBuild = player.current_build
    hud.clear_slot(0)
    await process_frame
    if hud.get_build().is_valid():
        failures.append("Clearing Slot 1 did not preserve an invalid draft")
    if player.current_build != active_before or not player.current_build.is_valid():
        failures.append("Invalid draft replaced the last valid Runtime build")
    hud.reset_build()
    await process_frame

    for slot_index: int in range(1, SixLinkBuild.MAX_SLOTS):
        hud.clear_slot(slot_index)
    hud.edit_slot(1, &"trigger_damage_taken", TriggerConfig.new())
    hud.edit_slot(2, &"core_summon")
    hud.call("_open_editor", 1)
    if not (hud.get("_damage_threshold_row") as HBoxContainer).visible:
        failures.append("On Damage Taken did not reveal its accumulated-damage field")
    if (hud.get("_channel_interval_row") as HBoxContainer).visible:
        failures.append("On Damage Taken incorrectly displayed Channel interval")
    hud.call("_close_editor")

    hud.edit_slot(0, &"core_void_beam")
    hud.edit_slot(1, &"trigger_channel", TriggerConfig.new())
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
        failures.append("Candidate preview supplied no grey-state reason")

    hud.reset_build()
    await _finish(main_scene, failures)


func _finish(main_scene: Node, failures: PackedStringArray) -> void:
    main_scene.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: six-slot HUD, responsive editor, invalid drafts, candidate reasons, and Trigger-specific controls")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)
