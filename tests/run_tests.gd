extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _test_direction_quantization()
    _test_animation_metadata()
    _test_attack_frame_regions()

    var packed_scene := load("res://scenes/CombatTest.tscn") as PackedScene
    _expect(packed_scene != null, "CombatTest.tscn loads")
    if packed_scene == null:
        _finish()
        return

    var arena := packed_scene.instantiate() as CombatTest
    root.add_child(arena)
    await process_frame
    await physics_frame

    var player := arena.get_node("Player") as ModularPlayer
    _expect(player != null, "Player exists in CombatTest")
    _expect(player.body.sprite_frames.get_animation_names().size() == 24, "24 logical animations were built")
    _expect(player.body.sprite_frames.get_frame_count("attack_01_east") == 8, "Attack_01 has eight runtime frames")
    _expect(player.body.animation == "idle_south", "Player starts in south idle")
    _expect(player.weapon_left.texture != null and player.weapon_right.texture != null, "Two independent weapon sprites are equipped")
    _expect(player.weapon_left.get_parent() == player.visual_rig, "Left weapon is separate from the body sprite")
    _expect(player.weapon_right.get_parent() == player.visual_rig, "Right weapon is separate from the body sprite")
    player._play_directional_animation("idle", "east")
    _expect(player.body.animation == "idle_east" and not player.body.flip_h, "Right movement renders the east-facing animation")
    player._play_directional_animation("idle", "west")
    _expect(player.body.animation == "idle_west" and player.body.flip_h, "Left movement mirrors the east body while moving west")
    player._play_directional_animation("idle", "north")
    _expect(player.weapon_left.z_index < player.body.z_index, "North-facing weapons render behind the body")
    player._play_directional_animation("idle", "south")
    _expect(player.weapon_left.z_index > player.body.z_index, "South-facing weapons render in front of the body")

    var dummies := get_nodes_in_group("training_dummy")
    _expect(dummies.size() == 7, "CombatTest contains seven training dummies")
    if player == null or dummies.size() < 3:
        arena.queue_free()
        _finish()
        return

    var test_positions := [Vector2(54, -15), Vector2(62, 0), Vector2(58, 16)]
    for index in range(dummies.size()):
        var dummy := dummies[index] as TrainingDummy
        dummy.global_position = test_positions[index] if index < 3 else Vector2(400 + index * 30, 300)

    var attack_started := player.start_attack(Vector2.RIGHT)
    _expect(attack_started, "Player can start Attack_01")
    _expect(player.facing_direction == "east", "Mouse/right aim quantizes to east")
    _expect(is_zero_approx(player.attack_pivot.rotation), "East hitbox pivot points east")
    _expect_attack_pose_applied(player, "east", 0)

    var frame_budget := 60
    while player.body.frame < player.attack_data.impact_frame and frame_budget > 0:
        await process_frame
        frame_budget -= 1
    _expect(player.body.frame == 3, "Attack reaches metadata impact frame 3")
    _expect_attack_pose_applied(player, "east", 3)
    _expect(
        is_equal_approx(player.weapon_left.rotation_degrees, 45.0)
        and is_equal_approx(player.weapon_right.rotation_degrees, -45.0),
        "Impact pose forms the metadata-driven crossed blade angles"
    )

    await create_timer(1.0, true, false, true).timeout
    for index in range(3):
        var dummy := dummies[index] as TrainingDummy
        _expect(dummy.current_hp == 75, "Grouped dummy %d is damaged exactly once" % (index + 1))
        _expect(dummy.global_position.distance_to(test_positions[index]) > 1.0, "Grouped dummy %d receives knockback" % (index + 1))

    _expect(arena.combat_hit_count == 3, "One swing registers all three grouped hits")
    _expect(arena.hit_stop_count == 1, "Grouped hits aggregate to one hit stop")
    _expect(arena.last_aggregated_hit_count == 3, "Impact aggregation sees three simultaneous targets")
    _expect(arena.combat_camera.last_impulse <= 3.0, "Camera impulse respects the cap")
    _expect(not player.is_attacking, "Attack returns to the free state")

    arena.queue_free()
    await process_frame
    _finish()


func _test_direction_quantization() -> void:
    var samples := {
        Vector2.UP: "north",
        Vector2(1, -1): "northeast",
        Vector2.RIGHT: "east",
        Vector2(1, 1): "southeast",
        Vector2.DOWN: "south",
        Vector2(-1, 1): "southwest",
        Vector2.LEFT: "west",
        Vector2(-1, -1): "northwest",
    }
    for vector: Vector2 in samples:
        _expect(
            ModularPlayer.quantize_direction(vector) == samples[vector],
            "Direction quantization: %s" % samples[vector]
        )
    _expect(is_equal_approx(Vector2(1, 1).normalized().length(), 1.0), "Diagonal movement input normalizes")


func _test_animation_metadata() -> void:
    var path := "res://assets/characters/student_dualblade/modular_character.json"
    _expect(FileAccess.file_exists(path), "Modular character metadata exists")
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    _expect(parsed is Dictionary, "Animation metadata parses")
    if not parsed is Dictionary:
        return
    var animations: Dictionary = parsed.get("animations", {})
    _expect(parsed.get("schema_version", 0) == 3, "Modular metadata uses per-frame pose schema 3")
    _expect(animations.size() == 3, "Metadata describes idle, walk, and attack")
    var attack: Dictionary = animations.get("attack_01", {})
    _expect(attack.get("frames", 0) == 8, "Attack_01 has eight frames")
    _expect(attack.get("impact_frame", -1) == 3, "Attack_01 impact frame is machine-readable")
    _expect(parsed.get("body_cell_size", 0) == 64, "Modular body cell size is 64px")
    _expect(parsed.get("logical_directions", []).size() == 8, "Metadata exposes eight logical directions")
    var body_assets: Dictionary = parsed.get("body_assets", {})
    _expect(body_assets.size() == 5, "Five authored body directions are available")
    for direction: String in body_assets:
        _expect(FileAccess.file_exists(body_assets[direction]), "Body asset exists: %s" % direction)
    var mirrors: Dictionary = parsed.get("mirror_sources", {})
    _expect(mirrors.get("west", "") == "east", "West explicitly mirrors the east body source")

    var action_assets: Dictionary = parsed.get("action_assets", {})
    var attack_assets: Dictionary = action_assets.get("attack_01", {})
    _expect(attack_assets.size() == 5, "Five authored Attack_01 body strips are available")
    for direction: String in attack_assets:
        var strip_path := str(attack_assets[direction])
        _expect(FileAccess.file_exists(strip_path), "Attack strip exists: %s" % direction)
        var strip := load(strip_path) as Texture2D
        _expect(
            strip != null and strip.get_size() == Vector2(512, 64),
            "Attack strip is 512x64 with eight native cells: %s" % direction
        )

    var rig: Dictionary = parsed.get("rig", {})
    var attack_poses: Dictionary = rig.get("attack_poses", {})
    _expect(attack_poses.size() == 5, "Five authored directions expose per-frame attack poses")
    var required_pose_keys := [
        "hand_screen_left",
        "hand_screen_right",
        "weapon_left_degrees",
        "weapon_right_degrees",
        "weapon_left_z",
        "weapon_right_z",
    ]
    for direction: String in attack_poses:
        var poses: Array = attack_poses[direction]
        _expect(poses.size() == 8, "Attack pose count is eight: %s" % direction)
        for frame in range(poses.size()):
            var pose: Dictionary = poses[frame]
            for key: String in required_pose_keys:
                _expect(pose.has(key), "%s frame %d has %s" % [direction, frame, key])
            for socket_key: String in ["hand_screen_left", "hand_screen_right"]:
                var socket := _array_to_vector2(pose.get(socket_key, []))
                _expect(
                    socket.x >= 0.0 and socket.x <= 64.0
                    and socket.y >= 0.0 and socket.y <= 64.0,
                    "%s frame %d keeps %s inside the body cell" % [
                        direction,
                        frame,
                        socket_key,
                    ]
                )

    var east_impact: Dictionary = attack_poses.get("east", [])[3]
    var west_impact := ModularPlayer.mirror_attack_pose(east_impact)
    var east_left := _array_to_vector2(east_impact["hand_screen_left"])
    var east_right := _array_to_vector2(east_impact["hand_screen_right"])
    _expect(
        west_impact["hand_screen_left"] == Vector2(64.0 - east_right.x, east_right.y)
        and west_impact["hand_screen_right"] == Vector2(64.0 - east_left.x, east_left.y),
        "Mirrored attack swaps sockets and reflects their X coordinates"
    )
    _expect(
        is_equal_approx(
            float(west_impact["weapon_left_degrees"]),
            -float(east_impact["weapon_right_degrees"])
        )
        and is_equal_approx(
            float(west_impact["weapon_right_degrees"]),
            -float(east_impact["weapon_left_degrees"])
        ),
        "Mirrored attack swaps and negates weapon angles"
    )
    _expect(
        west_impact["weapon_left_z"] == east_impact["weapon_right_z"]
        and west_impact["weapon_right_z"] == east_impact["weapon_left_z"],
        "Mirrored attack swaps weapon layers"
    )

    var weapon_path := "res://assets/weapons/short_sword/weapon.json"
    _expect(FileAccess.file_exists(weapon_path), "Independent weapon metadata exists")
    var weapon_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(weapon_path))
    _expect(weapon_parsed is Dictionary, "Independent weapon metadata parses")
    if weapon_parsed is Dictionary:
        _expect(FileAccess.file_exists(weapon_parsed.get("texture", "")), "Independent weapon texture exists")


func _test_attack_frame_regions() -> void:
    var frames := SpriteFramesBuilder.build(
        "res://assets/characters/student_dualblade/modular_character.json"
    )
    for direction: String in [
        "south",
        "southeast",
        "east",
        "northeast",
        "north",
        "northwest",
        "west",
        "southwest",
    ]:
        var animation_name := "attack_01_%s" % direction
        _expect(frames.get_frame_count(animation_name) == 8, "%s has eight regions" % animation_name)
        for frame in range(8):
            var texture := frames.get_frame_texture(animation_name, frame)
            _expect(texture is AtlasTexture, "%s frame %d is an AtlasTexture" % [animation_name, frame])
            if texture is AtlasTexture:
                var atlas_texture := texture as AtlasTexture
                _expect(
                    atlas_texture.region == Rect2(frame * 64.0, 0.0, 64.0, 64.0),
                    "%s frame %d selects its independent body region" % [
                        animation_name,
                        frame,
                    ]
                )


func _expect_attack_pose_applied(player: ModularPlayer, direction: String, frame: int) -> void:
    var pose := player._get_attack_pose(direction, frame)
    var left_socket := _array_to_vector2(pose.get("hand_screen_left", []))
    var right_socket := _array_to_vector2(pose.get("hand_screen_right", []))
    _expect(
        player.weapon_left.position + ModularPlayer.BODY_CELL_CENTER == left_socket,
        "%s frame %d left weapon grip is exactly on the hand socket" % [direction, frame]
    )
    _expect(
        player.weapon_right.position + ModularPlayer.BODY_CELL_CENTER == right_socket,
        "%s frame %d right weapon grip is exactly on the hand socket" % [direction, frame]
    )
    _expect(
        player.weapon_left.z_index == int(pose.get("weapon_left_z", 0))
        and player.weapon_right.z_index == int(pose.get("weapon_right_z", 0)),
        "%s frame %d applies per-frame weapon layers" % [direction, frame]
    )


func _array_to_vector2(value: Variant) -> Vector2:
    if value is Vector2:
        return value
    if value is Array and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures.append(message)
        push_error("FAIL: %s" % message)


func _finish() -> void:
    Engine.time_scale = 1.0
    if _failures.is_empty():
        print("\nALL COMBAT SLICE TESTS PASSED")
        quit(0)
    else:
        print("\n%d TEST(S) FAILED" % _failures.size())
        for failure in _failures:
            print(" - %s" % failure)
        quit(1)
