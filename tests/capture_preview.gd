extends SceneTree

const OUTPUT_PATH := "res://artifacts/prototype_preview.png"
const WIDE_OUTPUT_PATH := "res://artifacts/prototype_preview_1920.png"


func _init() -> void:
    call_deferred("_capture")


func _capture() -> void:
    DisplayServer.window_set_size(Vector2i(1280, 720))
    var packed_scene := load("res://main.tscn") as PackedScene
    if packed_scene == null:
        push_error("Could not load main scene for preview")
        quit(1)
        return

    var main_scene := packed_scene.instantiate()
    root.add_child(main_scene)
    current_scene = main_scene
    await process_frame
    await physics_frame

    var builder := get_first_node_in_group("concept_builder_ui") as PrototypeHud
    var player := get_first_node_in_group("player") as PlayerController
    if builder != null and player != null:
        builder.call("_open_editor", 2)
        player.set("_facing_direction", Vector3(0.0, 0.0, -1.0))
        player.try_cast_skill()
    var dummies := get_nodes_in_group("damageable")
    var preview_dummy: TrainingDummy
    if not dummies.is_empty():
        preview_dummy = dummies.back() as TrainingDummy
    if preview_dummy != null:
        for hit_index: int in 6:
            preview_dummy.take_damage(
                12.0 + hit_index * 4.0,
                &"fire",
                hit_index == 5,
                Color("ff9b55")
            )

    for _frame: int in 13:
        await process_frame

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
    var save_error := _save_viewport(OUTPUT_PATH)
    if save_error != OK:
        push_error("Could not save preview: %s" % error_string(save_error))
        quit(1)
        return
    builder.call("_close_editor")
    DisplayServer.window_set_size(Vector2i(1920, 1080))
    for _frame: int in 6:
        await process_frame
    save_error = _save_viewport(WIDE_OUTPUT_PATH)
    if save_error != OK:
        push_error("Could not save wide preview: %s" % error_string(save_error))
        quit(1)
        return
    print("PASS: previews captured at %s and %s" % [OUTPUT_PATH, WIDE_OUTPUT_PATH])
    quit(0)


func _save_viewport(output_path: String) -> Error:
    var image := root.get_texture().get_image()
    if image == null:
        push_error("Rendering backend did not provide a viewport image")
        return ERR_CANT_CREATE
    return image.save_png(output_path)
