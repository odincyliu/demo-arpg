extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const OUTPUT_PATH := "res://artifacts/vfx_showcase.png"

const SHOWCASE_SKILLS: Array[StringName] = [
    &"core_flame_orb",
    &"core_frost_nova",
    &"core_chain_lightning",
    &"core_returning_blade",
    &"core_summon",
    &"core_earthbreaker",
]
const SHOWCASE_POSITIONS: Array[Vector3] = [
    Vector3(-5.2, 0.0, 3.5),
    Vector3(0.0, 0.0, 3.5),
    Vector3(5.2, 0.0, 3.5),
    Vector3(-5.2, 0.0, -1.6),
    Vector3(0.0, 0.0, -1.6),
    Vector3(5.2, 0.0, -1.6),
]


func _init() -> void:
    call_deferred("_capture")


func _capture() -> void:
    DisplayServer.window_set_size(Vector2i(1280, 720))
    var packed_scene := load("res://main.tscn") as PackedScene
    var main_scene := packed_scene.instantiate()
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
    for target: Node in get_nodes_in_group("damageable"):
        if target is Node3D:
            (target as Node3D).visible = false

    for index: int in SHOWCASE_SKILLS.size():
        var definition := _compile_skill(SHOWCASE_SKILLS[index])
        if definition == null:
            push_error("Could not compile showcase skill %s" % SHOWCASE_SKILLS[index])
            quit(1)
            return
        var position := SHOWCASE_POSITIONS[index]
        COMBAT_VFX.spawn_cast_layers(main_scene, definition, position, Vector3.FORWARD)
        _add_label(main_scene, definition.display_name, position)
        if definition.core_behavior in [&"projectile", &"summon"]:
            _add_projectile_preview(main_scene, definition, position)

    for _frame: int in 4:
        await process_frame
    var thunder_definition := _compile_skill(&"core_chain_lightning")
    var thunder_position := SHOWCASE_POSITIONS[2]
    COMBAT_VFX.spawn_chain_lightning(
        main_scene,
        thunder_position + Vector3.UP * 0.9,
        thunder_position + Vector3(-3.2, 1.0, 0.0),
        thunder_definition.color,
        2
    )
    await process_frame
    var image := root.get_texture().get_image()
    if image == null:
        push_error("Rendering backend did not provide a VFX showcase image")
        quit(1)
        return
    var save_error := image.save_png(OUTPUT_PATH)
    if save_error != OK:
        push_error("Could not save VFX showcase: %s" % error_string(save_error))
        quit(1)
        return
    print("PASS: VFX showcase captured at %s" % OUTPUT_PATH)
    quit(0)


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


func _add_label(parent: Node, text: String, position: Vector3) -> void:
    var label := Label3D.new()
    label.text = text
    label.font_size = 28
    label.pixel_size = 0.018
    label.outline_size = 8
    label.modulate = Color("dcecff")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    parent.add_child(label)
    label.global_position = position + Vector3.UP * 2.4
