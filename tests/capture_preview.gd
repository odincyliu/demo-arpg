extends SceneTree


func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var packed_scene := load("res://scenes/CombatTest.tscn") as PackedScene
    var arena := packed_scene.instantiate() as CombatTest
    root.add_child(arena)
    await process_frame
    arena.call("_set_debug_enabled", true)
    arena.player.start_attack(Vector2.RIGHT)

    var frame_budget := 120
    while arena.player.body.frame < arena.player.attack_data.impact_frame and frame_budget > 0:
        await process_frame
        frame_budget -= 1
    await process_frame
    await process_frame

    var viewport_texture := root.get_texture()
    if viewport_texture == null:
        push_error("Viewport capture requires a rendering display driver")
        quit(1)
        return
    var image := viewport_texture.get_image()
    var output_path := ProjectSettings.globalize_path("res://artifacts/combat-test-preview.png")
    var result := image.save_png(output_path)
    if result != OK:
        push_error("Could not save capture: %s" % error_string(result))
        quit(1)
        return
    print("CAPTURED: %s" % output_path)

    await create_timer(0.8, true, false, true).timeout
    arena.player.facing_direction = "north"
    arena.player._play_directional_animation("idle", "north")
    await process_frame
    await process_frame
    viewport_texture = root.get_texture()
    if viewport_texture == null:
        push_error("Viewport capture requires a rendering display driver")
        quit(1)
        return
    var north_image := viewport_texture.get_image()
    var north_path := ProjectSettings.globalize_path("res://artifacts/north-rear-preview.png")
    result = north_image.save_png(north_path)
    if result != OK:
        push_error("Could not save north capture: %s" % error_string(result))
        quit(1)
        return
    print("CAPTURED: %s" % north_path)
    quit(0)
