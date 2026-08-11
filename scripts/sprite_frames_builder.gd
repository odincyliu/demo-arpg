class_name SpriteFramesBuilder
extends RefCounted


static func build(metadata_path: String) -> SpriteFrames:
    var metadata := load_json(metadata_path)
    var body_assets: Dictionary = metadata.get("body_assets", {})
    var animations: Dictionary = metadata.get("animations", {})
    var logical_directions: Array = metadata.get("logical_directions", [])
    var mirror_sources: Dictionary = metadata.get("mirror_sources", {})
    var texture_cache: Dictionary = {}

    var sprite_frames := SpriteFrames.new()
    if sprite_frames.has_animation("default"):
        sprite_frames.remove_animation("default")

    for action_value: Variant in animations:
        var action := str(action_value)
        var animation_data: Dictionary = animations[action]
        for direction_value: Variant in logical_directions:
            var direction := str(direction_value)
            var source_direction := str(mirror_sources.get(direction, direction))
            var texture_path := str(body_assets.get(source_direction, ""))
            var body_texture := texture_cache.get(texture_path) as Texture2D
            if body_texture == null:
                body_texture = load(texture_path) as Texture2D
                if body_texture == null:
                    push_error("Could not load modular body texture: %s" % texture_path)
                    continue
                texture_cache[texture_path] = body_texture

            var animation_name := "%s_%s" % [action, direction]
            sprite_frames.add_animation(animation_name)
            sprite_frames.set_animation_speed(animation_name, float(animation_data.get("fps", 8.0)))
            sprite_frames.set_animation_loop(animation_name, bool(animation_data.get("loop", true)))
            for _frame_index in range(int(animation_data.get("frames", 1))):
                sprite_frames.add_frame(animation_name, body_texture)

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
