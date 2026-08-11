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
const MIRROR_SOURCES := {
    "southwest": "southeast",
    "west": "east",
    "northwest": "northeast",
}
const ATTACK_STRIPS := {
    "south": "res://assets/characters/student_dualblade/body/attack_01_south.png",
    "southeast": "res://assets/characters/student_dualblade/body/attack_01_southeast.png",
    "east": "res://assets/characters/student_dualblade/body/attack_01_east.png",
    "northeast": "res://assets/characters/student_dualblade/body/attack_01_northeast.png",
    "north": "res://assets/characters/student_dualblade/body/attack_01_north.png",
}
const BODY_CELL := 64
const CONTACT_CELL := 112


func _initialize() -> void:
    call_deferred("_build_artifacts")


func _build_artifacts() -> void:
    var body_result := _build_eight_direction_body_sheet()
    if body_result != OK:
        push_error("Could not build eight-direction body sheet: %s" % error_string(body_result))
        quit(1)
        return

    var player_scene := load("res://scenes/Player.tscn") as PackedScene
    if player_scene == null:
        push_error("Could not load Player.tscn for attack QA")
        quit(1)
        return

    var viewport := SubViewport.new()
    viewport.size = Vector2i(CONTACT_CELL * 8, CONTACT_CELL * 8)
    viewport.transparent_bg = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
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
            player.position = cell_origin + Vector2(CONTACT_CELL * 0.5, CONTACT_CELL * 0.5)
            player.visual_rig.position = Vector2.ZERO
            player.visual_rig.scale = Vector2.ONE
            player._play_directional_animation("attack_01", DIRECTIONS[row])
            player.body.pause()
            player.body.frame = frame
            player._update_visual_pose()

            var label := Label.new()
            label.text = "%s %d" % [DIRECTION_LABELS[row], frame]
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
        "res://assets/characters/student_dualblade/run/64/qa/attack-composite-contact-sheet.png"
    )
    var save_result := output.save_png(output_path)
    if save_result != OK:
        push_error("Could not save attack contact sheet: %s" % error_string(save_result))
        quit(1)
        return
    print("CAPTURED: %s" % output_path)
    quit(0)


func _build_eight_direction_body_sheet() -> Error:
    var output := Image.create_empty(BODY_CELL * 8, BODY_CELL * 8, false, Image.FORMAT_RGBA8)
    output.fill(Color(0, 0, 0, 0))
    for row in range(DIRECTIONS.size()):
        var direction: String = DIRECTIONS[row]
        var source_direction: String = MIRROR_SOURCES.get(direction, direction)
        var source_path := ProjectSettings.globalize_path(ATTACK_STRIPS[source_direction])
        var strip := Image.load_from_file(source_path)
        if strip == null or strip.is_empty():
            push_error("Could not load body strip for QA: %s" % source_path)
            return ERR_FILE_CANT_READ
        strip.convert(Image.FORMAT_RGBA8)
        if MIRROR_SOURCES.has(direction):
            strip.flip_x()
        output.blit_rect(
            strip,
            Rect2i(0, 0, BODY_CELL * 8, BODY_CELL),
            Vector2i(0, row * BODY_CELL)
        )

    var output_path := ProjectSettings.globalize_path(
        "res://assets/characters/student_dualblade/run/64/final/body_attack_01-eight-directions.png"
    )
    return output.save_png(output_path)
