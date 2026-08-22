extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const WARNING_OUTPUT_PATH := "res://artifacts/meteor_warning_preview.png"
const DESCENT_OUTPUT_PATH := "res://artifacts/meteor_descent_preview.png"
const IMPACT_OUTPUT_PATH := "res://artifacts/meteor_impact_preview.png"
const COLLAPSE_OUTPUT_PATH := "res://artifacts/meteor_collapse_preview.png"


func _init() -> void:
    call_deferred("_capture")


func _capture() -> void:
    DisplayServer.window_set_size(Vector2i(1280, 720))
    var scene := _create_preview_scene()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await physics_frame

    var target_position := Vector3.ZERO
    var dummy := _add_dummy(scene, target_position)
    var descent := COMBAT_VFX.spawn_meteor_descent(scene, target_position, 1.6, 3.2)
    if descent == null:
        push_error("Could not create Meteor descent preview")
        quit(1)
        return
    var telegraph := scene.find_child("MeteorConvergenceTelegraph", true, false) as Node3D
    if telegraph == null:
        push_error("Could not create Meteor warning preview")
        quit(1)
        return

    descent.process_mode = Node.PROCESS_MODE_DISABLED
    telegraph.process_mode = Node.PROCESS_MODE_DISABLED
    descent.global_position = target_position + Vector3(1.55, 4.45, 1.15)
    var aura := descent.find_child("MeteorCc0FireballAura", true, false) as AnimatedSprite3D
    if aura != null:
        aura.pause()
        aura.frame = 13
    var outer_ring := telegraph.find_child("MeteorOuterWarningRing", true, false) as MeshInstance3D
    var inner_ring := telegraph.find_child("MeteorInnerCollapseRing", true, false) as MeshInstance3D
    var fangs := telegraph.find_child("MeteorInwardFangs", true, false) as MeshInstance3D
    if outer_ring != null:
        outer_ring.scale = Vector3.ONE * 3.52
    if inner_ring != null:
        inner_ring.scale = Vector3.ONE * 1.46
    if fangs != null:
        fangs.scale = Vector3.ONE * 0.82

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
    descent.hide()
    for _frame: int in 3:
        await process_frame
    if not _save_viewport(WARNING_OUTPUT_PATH):
        quit(1)
        return

    descent.show()
    await process_frame
    if not _save_viewport(DESCENT_OUTPUT_PATH):
        quit(1)
        return

    descent.queue_free()
    telegraph.queue_free()
    dummy.hide()
    await process_frame
    COMBAT_VFX.spawn_meteor_impact(scene, target_position, 3.2)
    await create_timer(0.15).timeout
    if not _save_viewport(IMPACT_OUTPUT_PATH):
        quit(1)
        return
    await create_timer(0.2).timeout
    if not _save_viewport(COLLAPSE_OUTPUT_PATH):
        quit(1)
        return

    scene.queue_free()
    for _frame: int in 3:
        await process_frame
    print("PASS: Meteor fixed-camera previews captured at %s, %s, %s, and %s" % [
        WARNING_OUTPUT_PATH,
        DESCENT_OUTPUT_PATH,
        IMPACT_OUTPUT_PATH,
        COLLAPSE_OUTPUT_PATH,
    ])
    quit(0)


func _create_preview_scene() -> Node3D:
    var scene := Node3D.new()
    scene.name = "MeteorPreview"

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.47, 0.47, 0.47)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.88, 0.88, 0.88)
    environment.ambient_light_energy = 0.86
    environment_node.environment = environment
    scene.add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-54.0, -28.0, 0.0)
    light.light_color = Color(0.92, 0.92, 0.92)
    light.light_energy = 1.3
    light.shadow_enabled = true
    scene.add_child(light)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(14.0, 10.0)
    floor.mesh = floor_mesh
    floor.material_override = _standard_material(Color(0.38, 0.38, 0.38))
    scene.add_child(floor)

    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 10.8
    camera.look_at_from_position(Vector3(8.4, 7.8, 10.8), Vector3(0.0, 1.65, 0.0), Vector3.UP)
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
    body.position.y = 0.82
    body.material_override = _standard_material(Color(0.11, 0.11, 0.11))
    dummy.add_child(body)

    var base := MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.56
    base_mesh.bottom_radius = 0.68
    base_mesh.height = 0.18
    base.mesh = base_mesh
    base.position.y = 0.09
    base.material_override = _standard_material(Color(0.24, 0.24, 0.24))
    dummy.add_child(base)
    return dummy


func _standard_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.86
    return material


func _save_viewport(output_path: String) -> bool:
    var image := root.get_texture().get_image()
    if image == null:
        push_error("Could not read Meteor preview viewport")
        return false
    var save_error := image.save_png(output_path)
    if save_error != OK:
        push_error("Could not save Meteor preview: %s" % error_string(save_error))
        return false
    return true
