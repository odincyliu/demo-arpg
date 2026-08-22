extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const PRIMARY_OUTPUT_PATH := "res://artifacts/chain_lightning_primary_preview.png"
const AFTERSHOCK_OUTPUT_PATH := "res://artifacts/chain_lightning_aftershock_preview.png"
const CHAIN_OUTPUT_PATH := "res://artifacts/chain_lightning_three_target_preview.png"


func _init() -> void:
    call_deferred("_capture")


func _capture() -> void:
    DisplayServer.window_set_size(Vector2i(1280, 720))
    var scene := _create_preview_scene()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await physics_frame

    var primary_from := Vector3(-3.1, 1.25, 0.0)
    var primary_to := Vector3(3.1, 1.25, 0.0)
    var primary_dummies: Array[Node3D] = [
        _add_dummy(scene, primary_from - Vector3.UP * 0.35),
        _add_dummy(scene, primary_to - Vector3.UP * 0.35),
    ]
    var sample := _spawn_frozen_link(scene, primary_from, primary_to, 4301)
    if sample == null:
        push_error("Could not create Chain Lightning preview sample")
        quit(1)
        return
    var primary_direction := primary_from.direction_to(primary_to)
    COMBAT_VFX._spawn_symbiote_tendrils(
        scene,
        primary_from,
        primary_direction,
        0.85,
        &"vfx_skill_identity"
    )
    COMBAT_VFX._spawn_symbiote_tendrils(
        scene,
        primary_to,
        -primary_direction,
        0.85,
        &"vfx_skill_identity"
    )
    _select_pulse(sample, 0)
    for _frame: int in 3:
        await process_frame

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
    if not _save_viewport(PRIMARY_OUTPUT_PATH):
        quit(1)
        return
    _select_pulse(sample, 1)
    await process_frame
    if not _save_viewport(AFTERSHOCK_OUTPUT_PATH):
        quit(1)
        return

    sample.hide()
    for dummy: Node3D in primary_dummies:
        dummy.hide()
    for tendril: Node in get_nodes_in_group(&"vfx_symbiote_tendrils"):
        if tendril is Node3D:
            (tendril as Node3D).hide()
    var chain_points: Array[Vector3] = [
        Vector3(-4.2, 1.25, 1.15),
        Vector3(-1.65, 1.2, -0.65),
        Vector3(1.25, 1.32, 0.75),
        Vector3(4.15, 1.2, -1.05),
    ]
    for point: Vector3 in chain_points:
        _add_dummy(scene, point - Vector3.UP * 0.35)
    for link_index: int in chain_points.size() - 1:
        var link := _spawn_frozen_link(
            scene,
            chain_points[link_index],
            chain_points[link_index + 1],
            9100 + link_index * 131
        )
        if link == null:
            push_error("Could not create three-target Chain Lightning preview")
            quit(1)
            return
        _select_pulse(link, 0)
    for _frame: int in 3:
        await process_frame
    if not _save_viewport(CHAIN_OUTPUT_PATH):
        quit(1)
        return

    scene.queue_free()
    await process_frame
    print("PASS: Chain Lightning fixed-camera previews captured at %s, %s, and %s" % [
        PRIMARY_OUTPUT_PATH,
        AFTERSHOCK_OUTPUT_PATH,
        CHAIN_OUTPUT_PATH,
    ])
    quit(0)


func _create_preview_scene() -> Node3D:
    var scene := Node3D.new()
    scene.name = "ChainLightningPreview"

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.48, 0.48, 0.48)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.88, 0.88, 0.88)
    environment.ambient_light_energy = 0.82
    environment_node.environment = environment
    scene.add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
    light.light_color = Color(0.92, 0.92, 0.92)
    light.light_energy = 1.25
    light.shadow_enabled = true
    scene.add_child(light)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(13.5, 8.5)
    floor.mesh = floor_mesh
    floor.material_override = _standard_material(Color(0.4, 0.4, 0.4))
    scene.add_child(floor)

    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 10.7
    camera.look_at_from_position(Vector3(7.8, 8.6, 10.2), Vector3(0.0, 0.9, 0.0), Vector3.UP)
    camera.current = true
    scene.add_child(camera)
    return scene


func _add_dummy(parent: Node3D, position: Vector3) -> Node3D:
    var dummy := Node3D.new()
    dummy.position = position
    parent.add_child(dummy)

    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.43
    body_mesh.height = 1.65
    body.mesh = body_mesh
    body.material_override = _standard_material(Color(0.105, 0.105, 0.105))
    dummy.add_child(body)

    var base := MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.56
    base_mesh.bottom_radius = 0.68
    base_mesh.height = 0.18
    base.mesh = base_mesh
    base.position.y = -0.84
    base.material_override = _standard_material(Color(0.24, 0.24, 0.24))
    dummy.add_child(base)
    return dummy


func _standard_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.86
    return material


func _spawn_frozen_link(
        parent: Node3D,
        from_position: Vector3,
        to_position: Vector3,
        visual_seed: int
) -> Node3D:
    COMBAT_VFX.spawn_chain_lightning(parent, from_position, to_position, Color.WHITE, visual_seed)
    for child_index: int in range(parent.get_child_count() - 1, -1, -1):
        var child := parent.get_child(child_index)
        if child is Node3D and child.is_in_group(&"vfx_chain_lightning"):
            var link := child as Node3D
            link.process_mode = Node.PROCESS_MODE_DISABLED
            return link
    return null


func _select_pulse(link: Node3D, pulse_index: int) -> void:
    for child: Node in link.get_children():
        if child is MeshInstance3D:
            child.visible = int(child.get_meta("pulse_index", -1)) == pulse_index
            var material := (child as MeshInstance3D).material_override as ShaderMaterial
            if material != null:
                material.set_shader_parameter("opacity", 1.0)


func _save_viewport(output_path: String) -> bool:
    var image := root.get_texture().get_image()
    if image == null:
        push_error("Could not read Chain Lightning preview viewport")
        return false
    var save_error := image.save_png(output_path)
    if save_error != OK:
        push_error("Could not save Chain Lightning preview: %s" % error_string(save_error))
        return false
    return true
