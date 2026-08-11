extends SceneTree

const PROFILE_PATH := "res://assets/characters/super_clone_cyborg/character_profile.json"
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

var _failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _test_direction_quantization()
    _test_character_profile()
    _test_animation_regions()

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
    if player == null:
        arena.queue_free()
        _finish()
        return

    _expect(
        player.body.sprite_frames.get_animation_names().size() == 24,
        "Three actions expose eight independent directions"
    )
    _expect(
        player.body.sprite_frames.get_frame_count("walk_northwest") == 8,
        "Northwest walk uses all eight source run frames"
    )
    _expect(
        player.body.sprite_frames.get_frame_count("attack_01_east") == 8,
        "Attack_01 preserves the eight-frame combat timing contract"
    )
    _expect(player.body.animation == "idle_south", "Player starts in south idle")
    _expect(
        player.get_node_or_null("VisualRig/WeaponLeft") == null
        and player.get_node_or_null("VisualRig/WeaponRight") == null,
        "The licensed combat atlas keeps hands and weapon in one rendered frame"
    )

    for direction: String in DIRECTIONS:
        player._play_directional_animation("idle", direction)
        var frame_texture := player.body.sprite_frames.get_frame_texture(
            "idle_%s" % direction,
            0
        ) as AtlasTexture
        _expect(not player.body.flip_h, "%s does not use horizontal mirroring" % direction)
        _expect(
            frame_texture != null
            and frame_texture.region.position.y == player.get_direction_row(direction) * 128.0,
            "%s selects its own authored atlas row" % direction
        )

    player._play_directional_animation("idle", "southwest")
    var keyboard_attack := InputEventKey.new()
    keyboard_attack.keycode = KEY_J
    keyboard_attack.pressed = true
    player._unhandled_input(keyboard_attack)
    _expect(
        player.facing_direction == "southwest"
        and player.attack_direction.is_equal_approx(
            ModularPlayer.direction_to_vector("southwest")
        ),
        "J attack follows the current facing direction"
    )
    _expect(
        player.body.animation == "attack_01_southwest",
        "Southwest attack selects the southwest source row"
    )
    player._on_animation_finished()

    var dummies := get_nodes_in_group("training_dummy")
    _expect(dummies.size() == 7, "CombatTest contains seven Kenney monsters")
    for dummy_node: Node in dummies:
        var dummy := dummy_node as TrainingDummy
        _expect(
            dummy != null and dummy.visual_root.get_child_count() == 9,
            "Each enemy is assembled from nine Monster Builder layers"
        )
        if dummy != null:
            for part_node: Node in dummy.visual_root.get_children():
                var part := part_node as Sprite2D
                _expect(
                    part != null and part.texture != null,
                    "Monster layer %s has a licensed texture" % part_node.name
                )

    if dummies.size() < 3:
        arena.queue_free()
        _finish()
        return

    var test_positions := [Vector2(54, -15), Vector2(62, 0), Vector2(58, 16)]
    for index in range(dummies.size()):
        var dummy := dummies[index] as TrainingDummy
        dummy.global_position = (
            test_positions[index]
            if index < 3
            else Vector2(400 + index * 30, 300)
        )

    var attack_started := player.start_attack(Vector2.RIGHT)
    _expect(attack_started, "Player can start Attack_01")
    _expect(player.facing_direction == "east", "Explicit right aim quantizes to east")
    _expect(is_zero_approx(player.attack_pivot.rotation), "East hitbox pivot points east")

    var frame_budget := 60
    while player.body.frame < player.attack_data.impact_frame and frame_budget > 0:
        await process_frame
        frame_budget -= 1
    _expect(player.body.frame == 3, "Attack reaches impact frame 3")
    _expect(
        player.get_current_atlas_column() == 14,
        "Impact frame selects the integrated weapon contact pose"
    )
    var impact_texture := player.body.sprite_frames.get_frame_texture(
        "attack_01_east",
        3
    ) as AtlasTexture
    _expect(
        impact_texture != null
        and impact_texture.region == Rect2(14 * 128, 0, 128, 128),
        "East impact uses atlas column 14 and east row 0"
    )

    await create_timer(1.0, true, false, true).timeout
    for index in range(3):
        var dummy := dummies[index] as TrainingDummy
        _expect(
            dummy.current_hp == 75,
            "Grouped monster %d is damaged exactly once" % (index + 1)
        )
        _expect(
            dummy.global_position.distance_to(test_positions[index]) > 1.0,
            "Grouped monster %d receives knockback" % (index + 1)
        )

    _expect(arena.combat_hit_count == 3, "One swing registers all three grouped hits")
    _expect(arena.hit_stop_count == 1, "Grouped hits aggregate to one hit stop")
    _expect(
        arena.last_aggregated_hit_count == 3,
        "Impact aggregation sees three simultaneous targets"
    )
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
    _expect(
        is_equal_approx(Vector2(1, 1).normalized().length(), 1.0),
        "Diagonal movement input normalizes"
    )


func _test_character_profile() -> void:
    _expect(FileAccess.file_exists(PROFILE_PATH), "Character profile exists")
    var profile := SpriteFramesBuilder.load_json(PROFILE_PATH)
    _expect(profile.get("schema_version", 0) == 1, "Character profile uses schema 1")
    _expect(profile.get("license", "") == "CC0-1.0", "Player profile declares CC0")
    _expect(
        SpriteFramesBuilder._as_vector2(
            profile.get("cell_size", []),
            Vector2.ZERO
        ) == Vector2(128, 128),
        "Atlas cells are native 128px"
    )
    _expect(
        profile.get("logical_directions", []).size() == 8,
        "Profile exposes eight logical directions"
    )

    var direction_rows: Dictionary = profile.get("direction_rows", {})
    var unique_rows: Dictionary = {}
    for direction: String in DIRECTIONS:
        _expect(direction_rows.has(direction), "%s has an explicit atlas row" % direction)
        unique_rows[int(direction_rows.get(direction, -1))] = true
    _expect(unique_rows.size() == 8, "All eight directions use distinct source rows")

    var animations: Dictionary = profile.get("animations", {})
    _expect(animations.size() == 3, "Profile describes idle, walk, and attack")
    _expect(animations.get("idle", {}).get("columns", []).size() == 4, "Idle has four frames")
    _expect(animations.get("walk", {}).get("columns", []).size() == 8, "Walk has eight frames")
    var attack: Dictionary = animations.get("attack_01", {})
    _expect(attack.get("columns", []).size() == 8, "Attack timing has eight frames")
    _expect(attack.get("columns", [])[3] == 14, "Attack impact maps to source column 14")

    var atlas_path := str(profile.get("texture", ""))
    _expect(FileAccess.file_exists(atlas_path), "Licensed player atlas exists")
    var atlas := load(atlas_path) as Texture2D
    _expect(
        atlas != null and atlas.get_size() == Vector2(4096, 1024),
        "Player atlas is the complete 32 by 8 source sheet"
    )
    _expect(
        FileAccess.file_exists(str(profile.get("source_notice", ""))),
        "Player source and license notice exists"
    )
    _expect(
        FileAccess.file_exists(
            "res://assets/third_party/kenney/monster_builder_pack/LICENSE.txt"
        ),
        "Original Kenney CC0 license text exists"
    )


func _test_animation_regions() -> void:
    var profile := SpriteFramesBuilder.load_json(PROFILE_PATH)
    var direction_rows: Dictionary = profile.get("direction_rows", {})
    var animations: Dictionary = profile.get("animations", {})
    var frames := SpriteFramesBuilder.build(PROFILE_PATH)
    for action: String in animations:
        var columns: Array = animations[action].get("columns", [])
        for direction: String in DIRECTIONS:
            var animation_name := "%s_%s" % [action, direction]
            _expect(
                frames.get_frame_count(animation_name) == columns.size(),
                "%s exposes every configured frame" % animation_name
            )
            for frame_index in range(columns.size()):
                var texture := frames.get_frame_texture(animation_name, frame_index)
                _expect(
                    texture is AtlasTexture,
                    "%s frame %d is an AtlasTexture" % [animation_name, frame_index]
                )
                if texture is AtlasTexture:
                    var region := (texture as AtlasTexture).region
                    _expect(
                        region == Rect2(
                            int(columns[frame_index]) * 128,
                            int(direction_rows[direction]) * 128,
                            128,
                            128
                        ),
                        "%s frame %d selects its authored cell" % [
                            animation_name,
                            frame_index,
                        ]
                    )


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
