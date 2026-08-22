extends SceneTree

const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const SHADOW_STYLE := preload("res://scripts/shadow_vfx_style.gd")
const TEST_UTILS := preload("res://tests/six_link_test_utils.gd")


func _init() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var failures: PackedStringArray = []
    for raw_component: Variant in SkillCatalog.get_catalog().values():
        var component := raw_component as SkillComponent
        var result := _representative_result(component)
        if not result.valid:
            failures.append("%s has no VFX host: %s" % [component.component_id, "; ".join(result.errors)])
            continue
        var definition := result.compiled_build.triggered_core if component.is_trigger() else result.compiled_build.root_core
        var holder := Node3D.new()
        root.add_child(holder)
        COMBAT_VFX.spawn_cast_layers(holder, definition, Vector3.ZERO, Vector3.FORWARD)
        await process_frame
        if holder.get_child_count() == 0:
            failures.append("%s produced no cast VFX or generic fallback" % component.component_id)
        match component.category:
            &"Core":
                if _count_group_children(holder, &"vfx_skill_identity") == 0:
                    failures.append("Core %s has no identity VFX fallback" % component.component_id)
                COMBAT_VFX.spawn_hit_layers(holder, definition, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 1.0, 2.0), Vector3.FORWARD)
                if _count_group_children(holder, &"vfx_skill_identity") < 2:
                    failures.append("Core %s has no dedicated hit/lifecycle VFX" % component.component_id)
                _spawn_lifecycle_sample(holder, definition)
                if _count_group_descendants(holder, &"vfx_skill_identity") < 3:
                    failures.append("Core %s has no sustained/end VFX sample" % component.component_id)
            &"Trigger":
                if definition.trigger_type == &"" or _count_group_children(holder, &"vfx_trigger") == 0:
                    failures.append("Trigger %s has no identifiable cue" % component.component_id)
            &"Shape":
                if _count_group_children(holder, &"vfx_shape") == 0:
                    failures.append("Shape %s has no VFX" % component.component_id)
            &"Trajectory", &"Pattern", &"Transform":
                if _count_group_children(holder, &"vfx_modifier") == 0:
                    failures.append("%s %s has no operation VFX" % [component.category, component.component_id])
            &"Effect":
                COMBAT_VFX.spawn_hit_layers(holder, definition, Vector3(0.0, 1.0, -2.0), Vector3(0.0, 1.0, 2.0), Vector3.FORWARD)
                if _count_group_children(holder, &"vfx_effect") == 0:
                    failures.append("Effect %s has no hit VFX" % component.component_id)
        _verify_neutral_tree(holder, component.component_id, failures)
        holder.queue_free()
        await process_frame

    await _verify_projectile_fallback(failures)
    await _verify_chain_lightning(failures)
    await _verify_slash_layers(failures)
    await _verify_directional_orientation(failures)
    await _verify_repeated_slash_alignment(failures)
    await _verify_meteor_descent(failures)
    _verify_shadow_palette(failures)
    if failures.is_empty():
        print("PASS: all 49 Components expose neutral Core/Trigger/operation/status VFX with generic fallback")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _representative_result(component: SkillComponent) -> SkillCompileResult:
    if component.is_core():
        return TEST_UTILS.compile([component.component_id])
    if component.is_trigger():
        if component.component_id == &"trigger_channel":
            return TEST_UTILS.compile([&"core_void_beam", component.component_id, &"core_meteor"])
        if component.component_id == &"trigger_return":
            return TEST_UTILS.compile([&"core_arrow_shot", &"trajectory_return", component.component_id, &"core_ground_burst"])
        return TEST_UTILS.compile([&"core_slash", component.component_id, &"core_ground_burst"])
    var host := &"core_arrow_shot"
    match component.component_id:
        &"shape_nova":
            host = &"core_shockwave"
        &"effect_ignite":
            host = &"core_flame_orb"
        &"effect_freeze":
            host = &"core_frost_lance"
        &"effect_shock":
            host = &"core_chain_lightning"
        &"pattern_hold", &"pattern_remnant", &"shape_orbit":
            host = &"core_flame_orb"
    return TEST_UTILS.compile([host, component.component_id])


func _count_group_children(holder: Node, group: StringName) -> int:
    var count := 0
    for child: Node in holder.get_children():
        if child.is_in_group(group):
            count += 1
    return count


func _spawn_lifecycle_sample(holder: Node3D, definition: SkillDefinition) -> void:
    match definition.core_behavior:
        &"projectile", &"wave":
            COMBAT_VFX.spawn_core_projectile_trail(holder, definition, Vector3.ZERO, Vector3.FORWARD)
            COMBAT_VFX.spawn_core_end(holder, definition, Vector3.FORWARD, Vector3.FORWARD)
        &"channel":
            COMBAT_VFX.spawn_channel_sustain(holder, definition)
            COMBAT_VFX.spawn_channel_end(holder, definition, Vector3.ZERO, Vector3.FORWARD * 3.0)
        &"persistent":
            COMBAT_VFX.spawn_persistent_field(holder, definition, Vector3.ZERO, definition.area_radius, 0.25)
        &"summon":
            COMBAT_VFX.spawn_minion_dissolve(holder, Vector3.ZERO)
        &"dash":
            COMBAT_VFX.spawn_dash_sequence(holder, Vector3.ZERO, Vector3.FORWARD * definition.target_range, 0.0)
        _:
            COMBAT_VFX.spawn_core_end(holder, definition, Vector3.FORWARD, Vector3.FORWARD)


func _verify_projectile_fallback(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var manager := ProjectileManager.new()
    holder.add_child(manager)
    await process_frame
    for core_id: StringName in [&"core_arrow_shot", &"core_frost_lance", &"core_flame_orb", &"core_shockwave"]:
        var result := TEST_UTILS.compile([core_id])
        var projectile := manager.request_projectile(
            holder,
            result.build.get_root_core(),
            holder,
            Vector3.ZERO,
            Vector3.FORWARD,
            {"build_revision": 1},
            true
        )
        if projectile == null or not projectile.visible:
            failures.append("%s had no shadow flight visual" % core_id)
        elif core_id == &"core_frost_lance":
            var lance_mesh := projectile.get("_mesh_instance") as MeshInstance3D
            if lance_mesh == null or absf(lance_mesh.rotation.x) > 0.001:
                failures.append("Frost Lance mesh was vertical instead of aligned with its travel direction")
        COMBAT_VFX.spawn_core_projectile_trail(
            holder,
            result.build.get_root_core(),
            Vector3.ZERO,
            Vector3.FORWARD
        )
        await physics_frame
    if _count_group_descendants(holder, &"vfx_projectile_trail") == 0:
        failures.append("Projectile and wave Cores produced no lifecycle trails")
    _verify_neutral_tree(holder, &"projectile_flight", failures)
    manager.clear_active()
    holder.queue_free()
    await process_frame


func _verify_shadow_palette(failures: PackedStringArray) -> void:
    for color: Color in [SHADOW_STYLE.BODY, SHADOW_STYLE.SHADOW, SHADOW_STYLE.ASH, SHADOW_STYLE.RIM, SHADOW_STYLE.FLASH]:
        if not SHADOW_STYLE.is_neutral(color):
            failures.append("ShadowVfxStyle contains a non-neutral swatch")
    if SHADOW_STYLE.RIM.get_luminance() - SHADOW_STYLE.BODY.get_luminance() < 0.5:
        failures.append("Shadow body and gray-white rim lack measurable luminance contrast")
    for component: SkillComponent in SkillCatalog.get_components_by_category(&"Core"):
        var definition := TEST_UTILS.compile([component.component_id]).build.get_root_core()
        if not SHADOW_STYLE.is_neutral(definition.color):
            failures.append("Core %s retains a chromatic VFX color" % component.component_id)


func _verify_neutral_tree(node: Node, label: StringName, failures: PackedStringArray) -> void:
    if node is GeometryInstance3D:
        var material := (node as GeometryInstance3D).material_override
        if material is StandardMaterial3D:
            var standard := material as StandardMaterial3D
            _expect_neutral_color(standard.albedo_color, label, "albedo", failures)
            if standard.emission_enabled:
                _expect_neutral_color(standard.emission, label, "emission", failures)
        elif material is ShaderMaterial:
            var shader_material := material as ShaderMaterial
            for parameter: StringName in [
                &"body_color",
                &"ash_color",
                &"rim_color",
                &"edge_color",
                &"gloss_color",
            ]:
                var value: Variant = shader_material.get_shader_parameter(parameter)
                if value is Color:
                    _expect_neutral_color(value as Color, label, String(parameter), failures)
    if node is SpriteBase3D:
        _expect_neutral_color((node as SpriteBase3D).modulate, label, "sprite modulate", failures)
    if node is Light3D:
        _expect_neutral_color((node as Light3D).light_color, label, "light", failures)
    for child: Node in node.get_children():
        _verify_neutral_tree(child, label, failures)


func _expect_neutral_color(
        color: Color,
        label: StringName,
        channel: String,
        failures: PackedStringArray
) -> void:
    if not SHADOW_STYLE.is_neutral(color):
        failures.append("%s uses chromatic %s color %s" % [label, channel, color])


func _verify_chain_lightning(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var from_position := Vector3(0.0, 1.1, 0.0)
    var to_position := Vector3(5.0, 1.0, -1.0)
    COMBAT_VFX.spawn_chain_lightning(holder, from_position, to_position, Color("8fdcff"), 17)
    COMBAT_VFX.spawn_chain_lightning(holder, from_position, to_position, Color("ff8844"), 17)
    COMBAT_VFX.spawn_chain_lightning(holder, from_position, to_position, Color("55ff99"), 18)
    COMBAT_VFX.spawn_chain_lightning(holder, from_position, Vector3(8.0, 1.25, -0.5), Color.WHITE, 21)
    var chain_roots := _group_descendants(holder, &"vfx_chain_lightning")
    var chain_root := chain_roots[0] as Node3D if not chain_roots.is_empty() else null
    if chain_root == null:
        failures.append("Shared Chain operation created no lightning VFX")
    else:
        if int(chain_root.get_meta("pulse_count", 0)) != 2:
            failures.append("Chain lightning did not prebuild two independent pulses")
        if int(chain_root.get_meta("filaments_per_pulse", 0)) != 2:
            failures.append("Chain lightning lost its converging companion filament")
        if float(chain_root.get_meta("exaggeration_scale", 0.0)) < 1.15:
            failures.append("Chain lightning lost its amplified presentation scale")
        if chain_root.get_meta("mesh_mode", &"") != &"camera_facing_array_mesh_ribbon":
            failures.append("Chain lightning did not declare camera-facing ArrayMesh ribbons")
        var point_counts := chain_root.get_meta("main_point_counts") as PackedInt32Array
        var branch_counts := chain_root.get_meta("branch_counts") as PackedInt32Array
        var signatures := chain_root.get_meta("path_signatures") as PackedInt64Array
        if point_counts.size() != 2 or point_counts[0] != 17 or point_counts[1] != 17:
            failures.append("Short Chain lightning pulses did not use 17 main points")
        for branch_count: int in branch_counts:
            if branch_count < 2 or branch_count > 4:
                failures.append("Chain lightning pulse escaped the 2-4 branch range")
        if signatures.size() != 2 or signatures[0] == signatures[1]:
            failures.append("Chain primary and aftershock pulses reused the same path")

        var pulses: Array[MeshInstance3D] = []
        for child: Node in chain_root.get_children():
            if child is MeshInstance3D:
                pulses.append(child as MeshInstance3D)
        if pulses.size() != 2:
            failures.append("Chain lightning did not create exactly two pulse ribbons")
        for pulse: MeshInstance3D in pulses:
            var mesh := pulse.mesh as ArrayMesh
            if mesh == null or mesh.get_surface_count() != 1:
                failures.append("Chain pulse did not combine trunk and branches into one ArrayMesh surface")
            var material := pulse.material_override as ShaderMaterial
            if material == null or material.shader != SHADOW_STYLE.SHADOW_CHAIN_LIGHTNING_SHADER:
                failures.append("Chain pulse did not use the dedicated black-lightning shader")
            else:
                var shader_code := material.shader.code
                if not shader_code.contains("octave < 5"):
                    failures.append("Chain lightning shader no longer uses five-octave FBM")
                if not shader_code.contains("EMISSION = vec3(0.0)"):
                    failures.append("Chain lightning shader introduced nonzero emission")
                var body_color := material.get_shader_parameter("body_color") as Color
                var edge_color := material.get_shader_parameter("edge_color") as Color
                var gloss_color := material.get_shader_parameter("gloss_color") as Color
                _expect_neutral_color(body_color, &"chain_lightning", "body_color", failures)
                _expect_neutral_color(edge_color, &"chain_lightning", "edge_color", failures)
                _expect_neutral_color(gloss_color, &"chain_lightning", "gloss_color", failures)
                if body_color.get_luminance() > 0.02 or edge_color.get_luminance() > 0.26:
                    failures.append("Chain lightning exceeded its pure-black and dark-gray palette")
                if gloss_color.get_luminance() > 0.4:
                    failures.append("Chain lightning wet gloss became too bright")
            var main_points := pulse.get_meta("main_points") as PackedVector3Array
            var companion_points := pulse.get_meta("companion_points") as PackedVector3Array
            var width_profile := pulse.get_meta("main_width_profile") as PackedFloat32Array
            if (
                main_points.is_empty()
                or not main_points[0].is_equal_approx(from_position)
                or not main_points[main_points.size() - 1].is_equal_approx(to_position)
            ):
                failures.append("Chain lightning no longer pins both runtime endpoints")
            if (
                companion_points.size() != main_points.size()
                or not companion_points[0].is_equal_approx(from_position)
                or not companion_points[companion_points.size() - 1].is_equal_approx(to_position)
            ):
                failures.append("Chain companion filament no longer converges at both endpoints")
            elif companion_points[floori(float(companion_points.size()) * 0.5)].distance_to(
                main_points[floori(float(main_points.size()) * 0.5)]
            ) < 0.08:
                failures.append("Chain companion filament no longer separates visibly from the trunk")
            if width_profile.size() != main_points.size():
                failures.append("Chain lightning width profile no longer follows every main point")
            elif _chain_lightning_width_ratio(width_profile) < 1.3:
                failures.append("Chain lightning main ribbon lacks visible thickness variation")
            var branch_paths := pulse.get_meta("branch_paths") as Array
            var main_length := from_position.distance_to(to_position)
            var main_forward := from_position.direction_to(to_position)
            for raw_branch: Variant in branch_paths:
                var branch := raw_branch as PackedVector3Array
                var branch_delta := branch[branch.size() - 1] - branch[0]
                if branch_delta.length() > main_length * 0.18 + 0.001:
                    failures.append("Chain lightning branch became too long and tree-like")
                if branch_delta.normalized().dot(main_forward) < 0.15:
                    failures.append("Chain lightning branch no longer arcs forward with the discharge")
        if _contains_cylinder_mesh(chain_root):
            failures.append("Chain lightning still contains CylinderMesh geometry")

    if chain_roots.size() == 4:
        var repeated_signatures := chain_roots[1].get_meta("path_signatures") as PackedInt64Array
        var varied_signatures := chain_roots[2].get_meta("path_signatures") as PackedInt64Array
        var repeated_widths := chain_roots[1].get_meta("main_widths") as PackedFloat32Array
        var varied_widths := chain_roots[2].get_meta("main_widths") as PackedFloat32Array
        var width_signatures := chain_root.get_meta("width_profile_signatures") as PackedInt64Array
        var repeated_width_signatures := chain_roots[1].get_meta("width_profile_signatures") as PackedInt64Array
        var varied_width_signatures := chain_roots[2].get_meta("width_profile_signatures") as PackedInt64Array
        if repeated_signatures != chain_root.get_meta("path_signatures"):
            failures.append("Identical Chain seed and endpoints did not reproduce the same paths")
        if varied_signatures == chain_root.get_meta("path_signatures"):
            failures.append("Different Chain cast seeds did not vary the paths")
        if repeated_widths != chain_root.get_meta("main_widths"):
            failures.append("Identical Chain seed did not reproduce the same widths")
        if varied_widths == chain_root.get_meta("main_widths"):
            failures.append("Different Chain cast seeds did not vary the widths")
        if repeated_width_signatures != width_signatures:
            failures.append("Identical Chain seed did not reproduce its thickness rhythm")
        if varied_width_signatures == width_signatures:
            failures.append("Different Chain cast seeds did not vary their thickness rhythm")
        var long_counts := chain_roots[3].get_meta("main_point_counts") as PackedInt32Array
        if long_counts.size() != 2 or long_counts[0] != 33 or long_counts[1] != 33:
            failures.append("Long Chain lightning pulses did not use 33 main points")
    elif chain_root != null:
        failures.append("Chain lightning deterministic test did not create all sample roots")

    await process_frame
    for _frame: int in 16:
        await physics_frame
    if _count_group_descendants(holder, &"vfx_chain_lightning") > 0:
        failures.append("Chain VFX remained beyond its 0.23-second lifetime")
    holder.queue_free()
    await process_frame


func _contains_cylinder_mesh(node: Node) -> bool:
    if node is MeshInstance3D and (node as MeshInstance3D).mesh is CylinderMesh:
        return true
    for child: Node in node.get_children():
        if _contains_cylinder_mesh(child):
            return true
    return false


func _chain_lightning_width_ratio(width_profile: PackedFloat32Array) -> float:
    var minimum_width := INF
    var maximum_width := 0.0
    for point_index: int in range(1, width_profile.size() - 1):
        minimum_width = minf(minimum_width, width_profile[point_index])
        maximum_width = maxf(maximum_width, width_profile[point_index])
    return maximum_width / maxf(minimum_width, 0.00001)


func _verify_slash_layers(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var slash := TEST_UTILS.compile([&"core_slash"]).build.get_root_core()
    COMBAT_VFX.spawn_cast_layers(holder, slash, Vector3.ZERO, Vector3.FORWARD)
    var cast_roots := _group_descendants(holder, &"vfx_slash_cast")
    if cast_roots.size() != 1:
        failures.append("Slash did not create one authored cast root")
    else:
        var cast_root := cast_roots[0]
        if int(cast_root.get_meta("presentation_layers", 0)) != 2:
            failures.append("Slash should contain only sword-wave and shadow-smoke presentation layers")
        if float(cast_root.get_meta("exaggeration_scale", 0.0)) < 1.2:
            failures.append("Slash lost its amplified presentation scale")
        if int(cast_root.get_meta("impact_line_count", 0)) != 12:
            failures.append("Slash lost its centered impact-line burst")
        if not is_equal_approx(float(cast_root.get_meta("attack_radius", 0.0)), slash.area_radius):
            failures.append("Slash sword-wave did not inherit the compiled area radius")
    if _count_group_descendants(holder, &"vfx_slash_wave") != 1:
        failures.append("Slash did not create exactly one sword-wave")
    var slash_wave_roots := _group_descendants(holder, &"vfx_slash_wave")
    var slash_ribbon := _find_mesh_instance_3d(slash_wave_roots[0]) if not slash_wave_roots.is_empty() else null
    if slash_ribbon == null:
        failures.append("Slash sword-wave created no cyclic slash plane")
    else:
        var slash_material := slash_ribbon.material_override as ShaderMaterial
        if slash_material == null or slash_material.shader != SHADOW_STYLE.SHADOW_CYCLIC_SLASH_SHADER:
            failures.append("Slash sword-wave did not use its procedural cyclic shader")
        elif float(slash_material.get_shader_parameter("emission_strength")) > 0.2:
            failures.append("Slash cyclic plane escaped the restrained shadow emission range")
        else:
            var erosion_texture := slash_material.get_shader_parameter("base_noise") as NoiseTexture2D
            var erosion_noise := erosion_texture.noise if erosion_texture != null else null
            if (
                erosion_noise == null
                or erosion_noise.fractal_type != FastNoiseLite.FRACTAL_FBM
                or erosion_noise.fractal_octaves != 5
                or not is_equal_approx(erosion_noise.fractal_gain, 0.75)
            ):
                failures.append("Slash did not use the circular five-octave FBM erosion source")
        if not (slash_ribbon.mesh is QuadMesh):
            failures.append("Slash cyclic shader was not applied to a QuadMesh")
        elif (slash_ribbon.mesh as QuadMesh).size.x < 4.4:
            failures.append("Slash cyclic plane is no longer exaggerated beyond its base size")
    if not cast_roots.is_empty() and cast_roots[0].get_meta("swing_type", &"") != &"horizontal":
        failures.append("Slash did not declare a horizontal swing")
    if not cast_roots.is_empty():
        var cast_root := cast_roots[0]
        var sweep_direction := float(cast_root.get_meta("sweep_direction", 0.0))
        var width_variation := float(cast_root.get_meta("width_variation", 0.0))
        var depth_variation := float(cast_root.get_meta("depth_variation", 0.0))
        var bow_variation := float(cast_root.get_meta("bow_variation", 0.0))
        var tilt_degrees := float(cast_root.get_meta("tilt_degrees", 0.0))
        var wave_root := slash_ribbon.get_parent() if slash_ribbon != null else null
        if not is_equal_approx(sweep_direction, 1.0):
            failures.append("Slash changed sweep direction between casts")
        if not is_equal_approx(width_variation, 1.0):
            failures.append("Slash changed width between casts")
        if not is_equal_approx(depth_variation, 1.0):
            failures.append("Slash changed depth between casts")
        if not is_equal_approx(bow_variation, 1.0):
            failures.append("Slash changed bow shape between casts")
        if (
            absf(tilt_degrees) < 4.0
            or absf(tilt_degrees) > 12.0
            or not bool(cast_root.get_meta("tilt_randomized", false))
        ):
            failures.append("Slash tilt escaped its controlled random angle")
        if wave_root != null and wave_root.get_meta("visual_mode", &"") != &"procedural_cyclic":
            failures.append("Slash wave did not declare its procedural cyclic presentation")
        if wave_root != null and wave_root.get_meta("erosion_mode", &"") != &"material_maker_circular_fbm":
            failures.append("Slash wave did not declare its Material Maker erosion presentation")
        if wave_root != null:
            var echo_ribbon := wave_root.find_child("SlashEchoRibbon", false, false) as MeshInstance3D
            if int(wave_root.get_meta("ribbon_count", 0)) != 2 or echo_ribbon == null:
                failures.append("Slash lost its delayed echo ribbon")
            else:
                var echo_quad := echo_ribbon.mesh as QuadMesh
                var main_quad := slash_ribbon.mesh as QuadMesh
                var echo_material := echo_ribbon.material_override as ShaderMaterial
                if echo_quad == null or main_quad == null or echo_quad.size.x <= main_quad.size.x:
                    failures.append("Slash echo ribbon no longer frames the main blade")
                if (
                    echo_material == null
                    or echo_material.shader != SHADOW_STYLE.SHADOW_CYCLIC_SLASH_SHADER
                    or float(echo_material.get_shader_parameter("opacity")) > 0.55
                ):
                    failures.append("Slash echo ribbon lost its restrained procedural material")
    var smoke_roots := _group_descendants(holder, &"vfx_slash_smoke")
    if smoke_roots.size() != 1:
        failures.append("Slash sword-wave did not create one combined smoke field")
    else:
        var smoke_root := smoke_roots[0]
        var blade_wisp_count := int(smoke_root.get_meta("blade_wisp_count", 0))
        var character_wisp_count := int(smoke_root.get_meta("character_wisp_count", 0))
        var blade_smoke := smoke_root.find_child("BladeSlashSmoke", true, false)
        var character_smoke := smoke_root.find_child("CharacterSlashSmoke", true, false)
        if (
            blade_wisp_count < 22
            or blade_wisp_count > 27
            or character_wisp_count < 11
            or character_wisp_count > 15
            or int(smoke_root.get_meta("wisp_count", 0)) != blade_wisp_count + character_wisp_count
        ):
            failures.append("Slash smoke density escaped its controlled random ranges")
        if (
            smoke_root.get_meta("smoke_mode", &"") != &"blade_and_character_wake"
            or not bool(smoke_root.get_meta("smoke_randomized", false))
            or blade_smoke == null
            or blade_smoke.get_meta("smoke_zone", &"") != &"blade"
            or character_smoke == null
            or character_smoke.get_meta("smoke_zone", &"") != &"character"
        ):
            failures.append("Slash smoke did not cover both blade and character zones")
    var tendril_roots := _group_descendants(holder, &"vfx_symbiote_tendrils")
    if tendril_roots.size() != 1:
        failures.append("Slash did not create one living-black tendril field")
    else:
        var tendril_root := tendril_roots[0]
        var tendril_mesh := _find_mesh_instance_3d(tendril_root)
        var tendril_count := int(tendril_root.get_meta("tendril_count", 0))
        if tendril_count < 5 or tendril_count > 7:
            failures.append("Slash symbiote tendrils escaped their controlled density")
        if (
            tendril_mesh == null
            or not (tendril_mesh.mesh is ArrayMesh)
            or (tendril_mesh.mesh as ArrayMesh).get_surface_count() != 1
        ):
            failures.append("Slash symbiote tendrils were not combined into one ribbon surface")
    if _count_group_descendants(holder, &"vfx_core") != 1:
        failures.append("Slash retained generic Core guide lines")
    if _count_group_descendants(holder, &"vfx_shape") != 1:
        failures.append("Slash retained generic cone guide lines")
    if slash_ribbon != null:
        var motion_root := slash_ribbon.get_parent() as Node3D
        var motion_start := motion_root.global_position
        for _frame: int in 4:
            await physics_frame
        if (
            not is_instance_valid(motion_root)
            or motion_root.global_position.distance_to(motion_start) > 0.01
        ):
            failures.append("Slash weapon trail moved away from its original swing path")

    COMBAT_VFX.spawn_hit_layers(
        holder,
        slash,
        Vector3(0.0, 1.0, -2.0),
        Vector3(0.0, 1.0, 2.0),
        Vector3.FORWARD
    )
    var impact_roots := _group_descendants(holder, &"vfx_slash_impact")
    if impact_roots.size() != 1 or not bool(impact_roots[0].get_meta("smoke_only", false)):
        failures.append("Slash hit should resolve with shadow smoke and no second slash")
    _verify_neutral_tree(holder, &"slash", failures)
    for _frame: int in 40:
        await physics_frame
    if (
        _count_group_descendants(holder, &"vfx_slash_cast") > 0
        or _count_group_descendants(holder, &"vfx_slash_impact") > 0
        or _count_group_descendants(holder, &"vfx_slash_smoke") > 0
    ):
        failures.append("Slash sword-wave or shadow smoke remained after its lifetime")
    holder.queue_free()
    await process_frame


func _verify_directional_orientation(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 18.0
    camera.position = Vector3(10.5, 14.0, 10.5)
    camera.current = true
    holder.add_child(camera)
    camera.look_at(Vector3.ZERO, Vector3.UP)
    await process_frame
    var slash := TEST_UTILS.compile([&"core_slash"]).build.get_root_core()
    var directions: Array[Vector3] = [
        Vector3.FORWARD,
        Vector3.RIGHT,
        Vector3.BACK,
        Vector3.LEFT,
        Vector3(1.0, 0.0, -1.0).normalized(),
    ]
    for direction: Vector3 in directions:
        var sample := Node3D.new()
        holder.add_child(sample)
        COMBAT_VFX.spawn_cast_layers(sample, slash, Vector3.ZERO, direction)
        var oriented_sprite: Node3D
        for candidate: Node in _group_descendants(sample, &"vfx_skill_identity"):
            if candidate is Node3D and candidate.has_meta("screen_angle"):
                oriented_sprite = candidate as Node3D
                break
        if oriented_sprite == null:
            failures.append("Slash produced no direction-aware VFX for %s" % direction)
        else:
            var screen_origin := camera.unproject_position(oriented_sprite.global_position)
            var screen_target := camera.unproject_position(oriented_sprite.global_position + direction)
            var screen_direction := screen_target - screen_origin
            var expected_angle := atan2(screen_direction.y, screen_direction.x)
            var actual_angle := float(oriented_sprite.get_meta("screen_angle"))
            if absf(wrapf(actual_angle - expected_angle, -PI, PI)) > 0.01:
                failures.append("Slash arc misaligned under the fixed camera for %s" % direction)
        var ribbon := _find_mesh_instance_3d(sample)
        if ribbon == null or not _is_wide_cyclic_plane(ribbon):
            failures.append("Slash cyclic plane was not wider across the horizontal swing for %s" % direction)
        elif oriented_sprite != null:
            var material := ribbon.material_override as ShaderMaterial
            var tilt_degrees := float(oriented_sprite.get_meta("tilt_degrees", 0.0))
            var expected_rotation := (
                285.0
                + rad_to_deg(float(oriented_sprite.get_meta("screen_angle")))
                + tilt_degrees
            )
            var actual_rotation := float(material.get_shader_parameter("rotate_all"))
            if absf(wrapf(actual_rotation - expected_rotation, -180.0, 180.0)) > 0.1:
                failures.append("Slash cyclic mask did not rotate with attack direction %s" % direction)
        sample.queue_free()
        await process_frame
    holder.queue_free()
    await process_frame


func _verify_repeated_slash_alignment(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 18.0
    camera.position = Vector3(10.5, 14.0, 10.5)
    camera.current = true
    holder.add_child(camera)
    camera.look_at(Vector3.ZERO, Vector3.UP)
    await process_frame

    var slash := TEST_UTILS.compile([&"core_slash"]).build.get_root_core()
    var direction := Vector3(1.0, 0.0, -1.0).normalized()
    var side := Vector3(-direction.z, 0.0, direction.x)
    var reference_angle := 0.0
    var reference_size := Vector2.ZERO
    var reference_phase := 0.0
    var reference_offset := Vector3.ZERO
    var reference_tilt := 0.0
    var saw_tilt_variation := false

    for cast_index: int in 6:
        var sample := Node3D.new()
        holder.add_child(sample)
        COMBAT_VFX.spawn_cast_layers(sample, slash, Vector3.ZERO, direction * (1.0 + cast_index * 0.2))
        var cast_roots := _group_descendants(sample, &"vfx_slash_cast")
        var ribbon := _find_mesh_instance_3d(sample)
        if cast_roots.size() != 1 or ribbon == null or not (ribbon.mesh is QuadMesh):
            failures.append("Repeated Slash sample %d did not produce a comparable blade" % cast_index)
        else:
            var cast_root := cast_roots[0] as Node3D
            var wave_root := ribbon.get_parent() as Node3D
            var quad := ribbon.mesh as QuadMesh
            var material := ribbon.material_override as ShaderMaterial
            var angle := float(cast_root.get_meta("screen_angle"))
            var rotation := float(material.get_shader_parameter("rotate_all"))
            var phase := float(material.get_shader_parameter("phase"))
            var tilt_degrees := float(cast_root.get_meta("tilt_degrees", 0.0))
            var wave_offset := wave_root.global_position
            if absf(wave_offset.dot(side)) > 0.01:
                failures.append("Repeated Slash sample %d drifted sideways from its attack path" % cast_index)
            if wave_offset.dot(direction) < 0.0 or wave_offset.dot(direction) > slash.area_radius:
                failures.append("Repeated Slash sample %d appeared outside its compiled attack range" % cast_index)
            if absf(tilt_degrees) < 4.0 or absf(tilt_degrees) > 12.0:
                failures.append("Repeated Slash sample %d escaped its tilt range" % cast_index)
            var expected_rotation := 285.0 + rad_to_deg(angle) + tilt_degrees
            if absf(wrapf(rotation - expected_rotation, -180.0, 180.0)) > 0.01:
                failures.append("Repeated Slash sample %d did not rotate around its center" % cast_index)
            if not is_equal_approx(float(wave_root.get_meta("tilt_degrees", 0.0)), tilt_degrees):
                failures.append("Repeated Slash sample %d lost its shared blade tilt" % cast_index)
            if cast_index == 0:
                reference_angle = angle
                reference_size = quad.size
                reference_phase = phase
                reference_offset = wave_offset
                reference_tilt = tilt_degrees
            elif (
                absf(wrapf(angle - reference_angle, -PI, PI)) > 0.001
                or not quad.size.is_equal_approx(reference_size)
                or not is_equal_approx(phase, reference_phase)
                or not wave_offset.is_equal_approx(reference_offset)
            ):
                failures.append("Same-direction Slash sample %d changed direction, size, phase, or position" % cast_index)
            elif absf(tilt_degrees - reference_tilt) > 0.1:
                saw_tilt_variation = true
        sample.queue_free()
        await process_frame
    if not saw_tilt_variation:
        failures.append("Repeated same-direction Slash casts did not vary their centered tilt")
    holder.queue_free()
    await process_frame


func _verify_meteor_descent(failures: PackedStringArray) -> void:
    var holder := Node3D.new()
    root.add_child(holder)
    var descent := COMBAT_VFX.spawn_meteor_descent(holder, Vector3.ZERO, 0.4, 3.2)
    if descent == null:
        failures.append("Meteor produced no descending black body")
    else:
        var start_position := descent.get_meta("start_position") as Vector3
        var end_position := descent.get_meta("end_position") as Vector3
        if start_position.y - end_position.y < 8.0:
            failures.append("Meteor descent did not begin high above its impact point")
        if descent.get_meta("vfx_profile", &"") != &"living_black_meteor":
            failures.append("Meteor descent did not use the living-black authored profile")
        if descent.get_meta("cc0_source", &"") != &"cethiel_fireball":
            failures.append("Meteor descent did not declare its Cethiel CC0 fireball source")
        if int(descent.get_meta("tail_count", 0)) != 5:
            failures.append("Meteor descent did not produce five organic contrails")
        if descent.get_meta("mesh_mode", &"") != &"procedural_ribbon_contrails":
            failures.append("Meteor descent did not use procedural ribbon contrails")
        if descent.find_child("MeteorCc0FireballAura", true, false) == null:
            failures.append("Meteor descent did not integrate the CC0 animated fireball aura")
        if _contains_cylinder_mesh(descent):
            failures.append("Meteor descent still used rigid CylinderMesh contrails")
    var telegraph := holder.find_child("MeteorConvergenceTelegraph", true, false)
    if telegraph == null:
        failures.append("Meteor produced no inward-converging ground telegraph")
    elif int(telegraph.get_meta("layer_count", 0)) < 3:
        failures.append("Meteor telegraph did not expose all three warning layers")
    COMBAT_VFX.spawn_meteor_impact(holder, Vector3.ZERO, 3.2)
    if _count_group_descendants(holder, &"vfx_meteor_impact") == 0:
        failures.append("Meteor produced no dedicated ground impact VFX")
    var impact := holder.find_child("MeteorImpactVfx", true, false)
    if impact == null:
        failures.append("Meteor produced no authored impact root")
    else:
        if int(impact.get_meta("impact_stages", 0)) != 2:
            failures.append("Meteor impact did not include burst and inward-collapse stages")
        if int(impact.get_meta("crown_spike_count", 0)) != 14:
            failures.append("Meteor impact crown did not expose fourteen tapered spikes")
        if impact.find_child("MeteorCrownRibbonMesh", true, false) == null:
            failures.append("Meteor impact produced no procedural ribbon crown")
        if impact.find_child("MeteorUmbraPillar", true, false) == null:
            failures.append("Meteor impact produced no vertical umbra pillar")
    _verify_neutral_tree(holder, &"meteor", failures)
    holder.queue_free()
    await process_frame


func _count_group_descendants(parent: Node, group: StringName) -> int:
    return _group_descendants(parent, group).size()


func _find_mesh_instance_3d(parent: Node) -> MeshInstance3D:
    for child: Node in parent.get_children():
        if child is MeshInstance3D:
            return child as MeshInstance3D
        var match := _find_mesh_instance_3d(child)
        if match != null:
            return match
    return null


func _is_wide_cyclic_plane(ribbon: MeshInstance3D) -> bool:
    var quad := ribbon.mesh as QuadMesh
    return quad != null and quad.size.x > quad.size.y * 1.45


func _group_descendants(parent: Node, group: StringName) -> Array[Node]:
    var matches: Array[Node] = []
    for child: Node in parent.get_children():
        if child.is_in_group(group):
            matches.append(child)
        matches.append_array(_group_descendants(child, group))
    return matches
