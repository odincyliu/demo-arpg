extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const OUTPUT_PATH := "res://artifacts/slash_vfx_preview.png"
const SWEEP_OUTPUT_PATH := "res://artifacts/slash_vfx_sweep_preview.png"
const CONTEXT_OUTPUT_PATH := "res://artifacts/slash_vfx_context_preview.png"
const DISSOLVE_OUTPUT_PATH := "res://artifacts/slash_vfx_dissolve_preview.png"


func _init() -> void:
    call_deferred("_capture")


func _capture() -> void:
    DisplayServer.window_set_size(Vector2i(1280, 720))
    var packed_scene := load("res://main.tscn") as PackedScene
    var main_scene := packed_scene.instantiate() as Node3D
    root.add_child(main_scene)
    current_scene = main_scene
    await process_frame
    await physics_frame

    var hud := get_first_node_in_group("six_link_builder_ui") as PrototypeHud
    if hud != null:
        hud.visible = false
    var player := get_first_node_in_group("player") as PlayerController
    if player != null:
        player.visible = false
        player.set_process(false)
        player.set_physics_process(false)
    var reticle := main_scene.get("_aim_reticle") as Node3D
    if reticle != null:
        reticle.visible = false
    for target: Node in get_nodes_in_group("damageable"):
        if target is Node3D:
            (target as Node3D).visible = false

    var camera := main_scene.get("_camera") as Camera3D
    if camera == null:
        push_error("Slash preview has no fixed camera")
        quit(1)
        return
    var cast_position := player.global_position if player != null else Vector3.ZERO
    camera.size = 9.0
    camera.global_position = cast_position + Vector3(6.4, 8.5, 6.4)
    camera.look_at(cast_position + Vector3.UP * 0.75, Vector3.UP)
    main_scene.set_process(false)

    var build := SixLinkBuild.new()
    build.set_slot(SkillSlot.new().configure(0, &"core_slash"))
    var result := SkillCompiler.compile_build(build)
    if not result.valid:
        push_error("Could not compile Slash preview: %s" % "; ".join(result.errors))
        quit(1)
        return
    COMBAT_VFX.spawn_cast_layers(
        main_scene,
        result.build.get_root_core(),
        cast_position,
        Vector3.FORWARD
    )
    var slash_ribbon := main_scene.find_child("SlashRibbon", true, false) as MeshInstance3D
    if slash_ribbon == null:
        push_error("Could not find horizontal Slash ribbon for preview")
        quit(1)
        return
    var slash_wave := slash_ribbon.get_parent() as Node3D
    slash_wave.process_mode = Node.PROCESS_MODE_DISABLED
    var slash_material := slash_ribbon.material_override as ShaderMaterial
    var echo_ribbon := slash_wave.find_child("SlashEchoRibbon", false, false) as MeshInstance3D
    var echo_material: ShaderMaterial
    if echo_ribbon != null:
        echo_material = echo_ribbon.material_override as ShaderMaterial
    slash_material.set_shader_parameter("progress", 0.38)
    slash_material.set_shader_parameter("dissolve_progress", 0.0)
    if echo_material != null:
        echo_material.set_shader_parameter("progress", 0.29)
        echo_material.set_shader_parameter("dissolve_progress", 0.0)
    for _frame: int in 3:
        await process_frame

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
    if not _save_viewport(SWEEP_OUTPUT_PATH):
        quit(1)
        return
    slash_material.set_shader_parameter("progress", 0.52)
    if echo_material != null:
        echo_material.set_shader_parameter("progress", 0.44)
    await process_frame
    if not _save_viewport(OUTPUT_PATH):
        quit(1)
        return
    if player != null:
        player.visible = true
        await process_frame
        if not _save_viewport(CONTEXT_OUTPUT_PATH):
            quit(1)
            return
        player.visible = false
        await process_frame
    slash_material.set_shader_parameter("progress", 0.67)
    slash_material.set_shader_parameter("dissolve_progress", 0.55)
    if echo_material != null:
        echo_material.set_shader_parameter("progress", 0.6)
        echo_material.set_shader_parameter("dissolve_progress", 0.68)
    await process_frame
    if not _save_viewport(DISSOLVE_OUTPUT_PATH):
        quit(1)
        return

    main_scene.queue_free()
    await process_frame
    print("PASS: Slash fixed-camera previews captured at %s, %s, %s, and %s" % [
        SWEEP_OUTPUT_PATH,
        OUTPUT_PATH,
        CONTEXT_OUTPUT_PATH,
        DISSOLVE_OUTPUT_PATH,
    ])
    quit(0)


func _save_viewport(output_path: String) -> bool:
    var image := root.get_texture().get_image()
    if image == null:
        push_error("Could not read Slash preview viewport")
        return false
    var save_error := image.save_png(output_path)
    if save_error != OK:
        push_error("Could not save Slash preview: %s" % error_string(save_error))
        return false
    return true
