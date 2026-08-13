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
    var hud := get_first_node_in_group("concept_builder_ui") as PrototypeHud
    var player := get_first_node_in_group("player") as PlayerController
    if hud == null:
        failures.append("HUD was not created")
    else:
        for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
            DisplayServer.window_set_size(viewport_size)
            await process_frame
            var buttons: Array = hud.get("_slot_buttons")
            if buttons.size() != SkillGraph.MAX_NODES:
                failures.append("HUD did not keep six collapsed slots at %s" % viewport_size)
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
                failures.append("Expanded editor clipped at %s" % viewport_size)
            hud.call("_close_editor")
            if editor.visible:
                failures.append("Expanded editor did not collapse at %s" % viewport_size)
        var active_before := player.current_graph
        hud.clear_node(0)
        await process_frame
        if hud.get_graph().is_valid():
            failures.append("Clearing the manual root should leave a marked invalid draft")
        if player.current_graph != active_before or not player.current_graph.is_valid():
            failures.append("Invalid draft replaced the last valid Runtime graph")
        hud.reset_build()
    main_scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS: collapsed strip and editor fit 1280x720 and 1920x1080")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)
