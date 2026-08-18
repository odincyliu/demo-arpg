extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const OUTPUT_PATH := "res://artifacts/vfx_showcase.png"
const WIDE_OUTPUT_PATH := "res://artifacts/vfx_showcase_1920.png"

const SHOWCASE_SKILLS: Array[StringName] = [
    &"core_slash", &"core_whirlblade", &"core_dash_strike", &"core_shockwave", &"core_ground_burst",
    &"core_arrow_shot", &"core_frost_lance", &"core_flame_orb", &"core_frost_nova", &"core_chain_lightning",
    &"core_meteor", &"core_void_beam", &"core_void_rift", &"core_summon",
]


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
    if camera != null:
        camera.size = 19.0
        camera.global_position = Vector3(0.0, 18.0, 16.0)
        camera.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
    main_scene.set_process(false)

    var showcase := _populate_showcase(main_scene)
    if showcase == null:
        quit(1)
        return
    for _frame: int in 2:
        await process_frame
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
    var save_error := _save_viewport(OUTPUT_PATH)
    if save_error != OK:
        push_error("Could not save VFX showcase: %s" % error_string(save_error))
        quit(1)
        return
    showcase.queue_free()
    await process_frame
    await process_frame

    DisplayServer.window_set_size(Vector2i(1920, 1080))
    for _frame: int in 2:
        await process_frame
    showcase = _populate_showcase(main_scene)
    if showcase == null:
        quit(1)
        return
    for _frame: int in 2:
        await process_frame
    save_error = _save_viewport(WIDE_OUTPUT_PATH)
    if save_error != OK:
        push_error("Could not save wide VFX showcase: %s" % error_string(save_error))
        quit(1)
        return
    main_scene.queue_free()
    await process_frame
    await process_frame
    print("PASS: 14-Core VFX showcases captured at %s and %s" % [OUTPUT_PATH, WIDE_OUTPUT_PATH])
    quit(0)


func _populate_showcase(parent: Node3D) -> Node3D:
    var showcase := Node3D.new()
    parent.add_child(showcase)
    for index: int in SHOWCASE_SKILLS.size():
        var definition := _compile_skill(SHOWCASE_SKILLS[index])
        if definition == null:
            push_error("Could not compile showcase skill %s" % SHOWCASE_SKILLS[index])
            showcase.queue_free()
            return null
        var position := _showcase_position(index)
        COMBAT_VFX.spawn_cast_layers(showcase, definition, position, Vector3.FORWARD)
        COMBAT_VFX.spawn_hit_layers(showcase, definition, position + Vector3(0.0, 0.0, -0.75), position + Vector3.BACK, Vector3.FORWARD)
        _add_label(showcase, definition.display_name, position)
        if definition.core_behavior in [&"projectile", &"wave"]:
            _add_projectile_preview(showcase, definition, position)
        elif definition.core_behavior == &"persistent":
            COMBAT_VFX.spawn_persistent_field(showcase, definition, position, definition.area_radius * 0.55, 3.0)
        elif definition.core_behavior == &"summon":
            _add_minion_preview(showcase, definition, position)
        elif definition.core_behavior == &"dash":
            COMBAT_VFX.spawn_dash_sequence(showcase, position + Vector3.BACK, position + Vector3.FORWARD, 0.0)
        elif definition.core_behavior == &"channel":
            COMBAT_VFX.spawn_channel_end(showcase, definition, position, position + Vector3.FORWARD * 1.5)
    var thunder_definition := _compile_skill(&"core_chain_lightning")
    var thunder_position := _showcase_position(SHOWCASE_SKILLS.find(&"core_chain_lightning"))
    COMBAT_VFX.spawn_chain_lightning(
        showcase,
        thunder_position + Vector3.UP * 0.9,
        thunder_position + Vector3(-2.8, 1.0, 0.0),
        thunder_definition.color,
        2
    )
    return showcase


func _showcase_position(index: int) -> Vector3:
    var column := index % 5
    var row := index / 5
    return Vector3(-8.0 + float(column) * 4.0, 0.0, 4.5 - float(row) * 4.5)


func _compile_skill(component_id: StringName) -> SkillDefinition:
    var build := SixLinkBuild.new()
    build.set_slot(SkillSlot.new().configure(0, component_id))
    var result := SkillCompiler.compile_build(build)
    return result.build.get_root_core() if result.valid else null


func _add_projectile_preview(
        parent: Node,
        definition: SkillDefinition,
        position: Vector3
) -> void:
    var projectile := PROJECTILE_SCRIPT.new() as SkillProjectile
    parent.add_child(projectile)
    projectile.activate(
        definition,
        null,
        position + Vector3(0.0, 0.75, 1.15),
        Vector3.FORWARD,
        {},
        false,
        true
    )
    projectile.set_physics_process(false)


func _add_minion_preview(parent: Node3D, definition: SkillDefinition, position: Vector3) -> void:
    var minion := SkillMinion.new()
    parent.add_child(minion)
    minion.activate(definition, parent, position + Vector3.UP * 0.85, {}, 0.0)
    minion.set_physics_process(false)


func _add_label(parent: Node, text: String, position: Vector3) -> void:
    var label := Label3D.new()
    label.text = text
    label.font_size = 28
    label.pixel_size = 0.018
    label.outline_size = 8
    label.modulate = Color(0.82, 0.82, 0.82, 1.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    parent.add_child(label)
    label.global_position = position + Vector3.UP * 1.75


func _save_viewport(output_path: String) -> Error:
    var image := root.get_texture().get_image()
    if image == null:
        return ERR_CANT_CREATE
    return image.save_png(output_path)
