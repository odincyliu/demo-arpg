extends SceneTree

const DIRECTIONS := [
    "south",
    "southeast",
    "east",
    "northeast",
    "north",
    "northwest",
    "west",
    "southwest",
]
const DIRECTION_LABELS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const CONTACT_CELL := 160


func _initialize() -> void:
    call_deferred("_build_artifact")


func _build_artifact() -> void:
    var player_scene := load("res://scenes/Player.tscn") as PackedScene
    if player_scene == null:
        push_error("Could not load Player.tscn for attack QA")
        quit(1)
        return

    var viewport := SubViewport.new()
    viewport.size = Vector2i(CONTACT_CELL * 8, CONTACT_CELL * 8)
    viewport.transparent_bg = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)

    var canvas := Node2D.new()
    viewport.add_child(canvas)
    for row in range(DIRECTIONS.size()):
        for frame in range(8):
            var cell_origin := Vector2(frame * CONTACT_CELL, row * CONTACT_CELL)
            var background := ColorRect.new()
            background.position = cell_origin
            background.size = Vector2(CONTACT_CELL, CONTACT_CELL)
            background.color = (
                Color("202938")
                if (row + frame) % 2 == 0
                else Color("17202d")
            )
            background.z_index = -100
            canvas.add_child(background)

            var player := player_scene.instantiate() as ModularPlayer
            canvas.add_child(player)
            player.process_mode = Node.PROCESS_MODE_DISABLED
            player.position = cell_origin + Vector2(CONTACT_CELL * 0.5, CONTACT_CELL * 0.5 + 20)
            player.visual_rig.position = Vector2.ZERO
            player._play_directional_animation("attack_01", DIRECTIONS[row])
            player.body.pause()
            player.body.frame = frame

            var label := Label.new()
            label.text = "%s %d / src %d" % [
                DIRECTION_LABELS[row],
                frame,
                player.get_current_atlas_column(),
            ]
            label.position = cell_origin + Vector2(5, 3)
            label.add_theme_font_size_override("font_size", 12)
            label.add_theme_color_override("font_color", Color("d9f7ff"))
            label.add_theme_color_override("font_shadow_color", Color("071018"))
            label.add_theme_constant_override("shadow_offset_x", 1)
            label.add_theme_constant_override("shadow_offset_y", 1)
            label.z_index = 100
            canvas.add_child(label)

    await process_frame
    await process_frame
    await process_frame
    var viewport_texture := viewport.get_texture()
    if viewport_texture == null:
        push_error("Attack QA requires a rendering display driver")
        quit(1)
        return
    var output := viewport_texture.get_image()
    var output_path := ProjectSettings.globalize_path(
        "res://artifacts/cc0-eight-direction-attack.png"
    )
    var save_result := output.save_png(output_path)
    if save_result != OK:
        push_error("Could not save attack contact sheet: %s" % error_string(save_result))
        quit(1)
        return
    print("CAPTURED: %s" % output_path)
    quit(0)
