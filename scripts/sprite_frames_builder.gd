class_name SpriteFramesBuilder
extends RefCounted


static func build(metadata_path: String) -> SpriteFrames:
    var metadata := load_json(metadata_path)
    var texture_path := str(metadata.get("texture", ""))
    var atlas := load(texture_path) as Texture2D
    if atlas == null:
        push_error("Could not load character atlas: %s" % texture_path)
        return SpriteFrames.new()

    var cell_size := _as_vector2(metadata.get("cell_size", []), Vector2(128, 128))
    var animations: Dictionary = metadata.get("animations", {})
    var logical_directions: Array = metadata.get("logical_directions", [])
    var direction_rows: Dictionary = metadata.get("direction_rows", {})

    var sprite_frames := SpriteFrames.new()
    if sprite_frames.has_animation("default"):
        sprite_frames.remove_animation("default")

    for action_value: Variant in animations.keys():
        var action := str(action_value)
        var animation_data: Dictionary = animations[action]
        var columns: Array = animation_data.get("columns", [])
        for direction_value: Variant in logical_directions:
            var direction := str(direction_value)
            if not direction_rows.has(direction):
                push_error("Missing atlas row for direction: %s" % direction)
                continue
            var row := int(direction_rows[direction])

            var animation_name := "%s_%s" % [action, direction]
            sprite_frames.add_animation(animation_name)
            sprite_frames.set_animation_speed(animation_name, float(animation_data.get("fps", 8.0)))
            sprite_frames.set_animation_loop(animation_name, bool(animation_data.get("loop", true)))
            for column_value: Variant in columns:
                var column := int(column_value)
                var frame_texture := AtlasTexture.new()
                frame_texture.atlas = atlas
                frame_texture.region = Rect2(
                    column * cell_size.x,
                    row * cell_size.y,
                    cell_size.x,
                    cell_size.y
                )
                frame_texture.filter_clip = true
                sprite_frames.add_frame(animation_name, frame_texture)

    return sprite_frames


static func load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("JSON resource is missing: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("JSON resource is not an object: %s" % path)
        return {}
    return parsed


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
    if value is Array and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return fallback
