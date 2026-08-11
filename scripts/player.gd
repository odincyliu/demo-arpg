class_name ModularPlayer
extends CharacterBody2D

signal attack_started(direction: String)
signal hit_confirmed(target: Node, damage: int)

const CHARACTER_METADATA_PATH := "res://assets/characters/student_dualblade/modular_character.json"
const WEAPON_METADATA_PATH := "res://assets/weapons/short_sword/weapon.json"
const BODY_CELL_SIZE := 64.0
const BODY_CELL_CENTER := Vector2(32.0, 32.0)
const MIRROR_SOURCES := {
    "southwest": "southeast",
    "west": "east",
    "northwest": "northeast",
}
const ANGLE_DIRECTIONS := [
    "east",
    "southeast",
    "south",
    "southwest",
    "west",
    "northwest",
    "north",
    "northeast",
]

@export var move_speed: float = 190.0
@export var attack_move_multiplier: float = 0.38
@export var arena_bounds := Rect2(-700.0, -390.0, 1400.0, 780.0)
@export var attack_data: PlayerAttackData

@onready var visual_rig: Node2D = $VisualRig
@onready var body: AnimatedSprite2D = $VisualRig/Body
@onready var weapon_left: Sprite2D = $VisualRig/WeaponLeft
@onready var weapon_right: Sprite2D = $VisualRig/WeaponRight
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Area2D = $AttackPivot/AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackPivot/AttackHitbox/CollisionShape2D

var facing_direction: String = "south"
var current_action: String = "idle"
var combat_state: String = "free"
var debug_visible: bool = false
var is_attacking: bool = false
var attack_direction := Vector2.DOWN
var _character_metadata: Dictionary = {}
var _weapon_grip := Vector2(16.0, 26.0)
var _hit_registry: Dictionary = {}
var _hitbox_active: bool = false
var _lunge_velocity := Vector2.ZERO
var _lunge_applied: bool = false


func _ready() -> void:
    add_to_group("player")
    _character_metadata = SpriteFramesBuilder.load_json(CHARACTER_METADATA_PATH)
    body.sprite_frames = SpriteFramesBuilder.build(CHARACTER_METADATA_PATH)
    body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    body.frame_changed.connect(_on_body_frame_changed)
    body.animation_finished.connect(_on_animation_finished)
    _configure_weapons()
    attack_hitbox.area_entered.connect(_on_attack_area_entered)
    _set_hitbox_active(false)
    _play_directional_animation("idle", facing_direction)


func _physics_process(delta: float) -> void:
    var input_vector := _read_movement_input()
    if not is_attacking and not input_vector.is_zero_approx():
        facing_direction = quantize_direction(input_vector)

    var movement_scale := attack_move_multiplier if is_attacking else 1.0
    var movement_velocity := input_vector * move_speed * movement_scale
    _lunge_velocity = _lunge_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
    velocity = movement_velocity + _lunge_velocity
    move_and_slide()
    global_position.x = clampf(global_position.x, arena_bounds.position.x, arena_bounds.end.x)
    global_position.y = clampf(global_position.y, arena_bounds.position.y, arena_bounds.end.y)

    if not is_attacking:
        var next_action := "walk" if not input_vector.is_zero_approx() else "idle"
        if next_action != current_action or not _is_playing_direction(facing_direction):
            _play_directional_animation(next_action, facing_direction)

    if _hitbox_active:
        for area: Area2D in attack_hitbox.get_overlapping_areas():
            _try_hit_area(area)

    if debug_visible:
        queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    var wants_attack := false
    if event is InputEventMouseButton:
        wants_attack = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
    elif event is InputEventKey:
        wants_attack = (
            event.pressed
            and not event.echo
            and (event.keycode == KEY_J or event.keycode == KEY_SPACE)
        )

    if wants_attack:
        var aim_vector := get_global_mouse_position() - global_position
        if aim_vector.length_squared() < 64.0:
            aim_vector = direction_to_vector(facing_direction)
        start_attack(aim_vector)


func start_attack(aim_vector: Vector2) -> bool:
    if is_attacking or attack_data == null:
        return false
    if aim_vector.is_zero_approx():
        aim_vector = direction_to_vector(facing_direction)

    attack_direction = aim_vector.normalized()
    facing_direction = quantize_direction(attack_direction)
    attack_pivot.rotation = attack_direction.angle()
    is_attacking = true
    combat_state = "startup"
    _hit_registry.clear()
    _lunge_applied = false
    _set_hitbox_active(false)
    _play_directional_animation("attack_01", facing_direction)
    attack_started.emit(facing_direction)
    queue_redraw()
    return true


func set_debug_visible(enabled: bool) -> void:
    debug_visible = enabled
    queue_redraw()


func get_debug_summary() -> String:
    var frame := body.frame if body != null else -1
    return "Facing: %s\nAnimation: %s (frame %d)\nCombat: %s\nHitbox: %s\nSwing hits: %d" % [
        facing_direction.to_upper(),
        current_action,
        frame,
        combat_state,
        "ACTIVE" if _hitbox_active else "off",
        _hit_registry.size(),
    ]


static func quantize_direction(input_vector: Vector2) -> String:
    if input_vector.is_zero_approx():
        return "south"
    var sector := int(round(input_vector.angle() / (PI / 4.0)))
    sector = posmod(sector, ANGLE_DIRECTIONS.size())
    return ANGLE_DIRECTIONS[sector]


static func direction_to_vector(direction: String) -> Vector2:
    match direction:
        "north":
            return Vector2.UP
        "northeast":
            return Vector2(1.0, -1.0).normalized()
        "east":
            return Vector2.RIGHT
        "southeast":
            return Vector2(1.0, 1.0).normalized()
        "south":
            return Vector2.DOWN
        "southwest":
            return Vector2(-1.0, 1.0).normalized()
        "west":
            return Vector2.LEFT
        "northwest":
            return Vector2(-1.0, -1.0).normalized()
    return Vector2.DOWN


func _read_movement_input() -> Vector2:
    var movement := Vector2.ZERO
    if Input.is_key_pressed(KEY_A):
        movement.x -= 1.0
    if Input.is_key_pressed(KEY_D):
        movement.x += 1.0
    if Input.is_key_pressed(KEY_W):
        movement.y -= 1.0
    if Input.is_key_pressed(KEY_S):
        movement.y += 1.0
    return movement.normalized()


func _configure_weapons() -> void:
    var weapon_metadata := SpriteFramesBuilder.load_json(WEAPON_METADATA_PATH)
    var weapon_texture := load(str(weapon_metadata.get("texture", ""))) as Texture2D
    var landmarks: Dictionary = weapon_metadata.get("landmarks", {})
    _weapon_grip = _as_vector2(landmarks.get("grip", []), _weapon_grip)
    var cell_size := float(weapon_metadata.get("cell_size", 32))
    var grip_offset := Vector2(cell_size * 0.5, cell_size * 0.5) - _weapon_grip
    for weapon: Sprite2D in [weapon_left, weapon_right]:
        weapon.texture = weapon_texture
        weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        weapon.centered = true
        weapon.offset = grip_offset


func _play_directional_animation(action: String, direction: String) -> void:
    var animation_name := "%s_%s" % [action, direction]
    if not body.sprite_frames.has_animation(animation_name):
        push_error("Missing player animation: %s" % animation_name)
        return
    facing_direction = direction
    body.flip_h = MIRROR_SOURCES.has(direction)
    current_action = action
    if body.animation != animation_name or not body.is_playing():
        body.play(animation_name)
    _update_visual_pose()


func _is_playing_direction(direction: String) -> bool:
    return body.animation == "%s_%s" % [current_action, direction]


func _on_body_frame_changed() -> void:
    _update_visual_pose()
    if not is_attacking:
        return
    var frame := body.frame
    var active := frame >= attack_data.active_start_frame and frame <= attack_data.active_end_frame
    _set_hitbox_active(active)
    if frame < attack_data.active_start_frame:
        combat_state = "startup"
    elif active:
        combat_state = "active"
    else:
        combat_state = "recovery"

    if frame == attack_data.impact_frame and not _lunge_applied:
        _lunge_applied = true
        _lunge_velocity += attack_direction * attack_data.lunge


func _update_visual_pose() -> void:
    if body == null or weapon_left == null or weapon_right == null:
        return
    body.position = _body_frame_offset(current_action, body.frame)
    var sockets := _get_direction_sockets(facing_direction)
    weapon_left.position = body.position + sockets.get("left", Vector2(19.0, 41.0)) - BODY_CELL_CENTER
    weapon_right.position = body.position + sockets.get("right", Vector2(44.0, 41.0)) - BODY_CELL_CENTER
    weapon_left.rotation_degrees = _weapon_pose_degrees("left", current_action, body.frame)
    weapon_right.rotation_degrees = _weapon_pose_degrees("right", current_action, body.frame)
    _update_weapon_layers(facing_direction)


func _get_direction_sockets(direction: String) -> Dictionary:
    var source_direction: String = MIRROR_SOURCES.get(direction, direction)
    var rig: Dictionary = _character_metadata.get("rig", {})
    var landmarks: Dictionary = rig.get("landmarks", {})
    var direction_landmarks: Dictionary = landmarks.get(source_direction, {})
    var left := _as_vector2(
        direction_landmarks.get("hand_screen_left", []),
        Vector2(19.0, 41.0)
    )
    var right := _as_vector2(
        direction_landmarks.get("hand_screen_right", []),
        Vector2(44.0, 41.0)
    )
    if MIRROR_SOURCES.has(direction):
        return {
            "left": Vector2(BODY_CELL_SIZE - right.x, right.y),
            "right": Vector2(BODY_CELL_SIZE - left.x, left.y),
        }
    return {"left": left, "right": right}


func _body_frame_offset(action: String, frame: int) -> Vector2:
    match action:
        "idle":
            var idle_y := [0.0, -1.0, 0.0, 0.0]
            return Vector2(0.0, idle_y[frame % idle_y.size()])
        "walk":
            var walk_y := [0.0, 1.0, 0.0, -1.0, 0.0, 1.0]
            return Vector2(0.0, walk_y[frame % walk_y.size()])
        "attack_01":
            var attack_y := [0.0, -1.0, -2.0, -2.0, -1.0, 0.0, 0.0, 0.0]
            return Vector2(0.0, attack_y[frame % attack_y.size()])
    return Vector2.ZERO


func _weapon_pose_degrees(side: String, action: String, frame: int) -> float:
    var sign := 1.0 if side == "left" else -1.0
    match action:
        "idle":
            var idle_delta := [0.0, 2.0, 0.0, -2.0]
            return sign * (135.0 + idle_delta[frame % idle_delta.size()])
        "walk":
            var walk_delta := [0.0, -8.0, 0.0, 8.0, 0.0, -4.0]
            return sign * (135.0 + walk_delta[frame % walk_delta.size()])
        "attack_01":
            var attack_swing := [65.0, 95.0, 140.0, 205.0, 240.0, 205.0, 165.0, 145.0]
            return sign * attack_swing[frame % attack_swing.size()]
    return sign * 135.0


func _update_weapon_layers(direction: String) -> void:
    if direction in ["north", "northeast", "northwest"]:
        weapon_left.z_index = -1
        weapon_right.z_index = -1
    elif direction == "east":
        weapon_left.z_index = -1
        weapon_right.z_index = 1
    elif direction == "west":
        weapon_left.z_index = 1
        weapon_right.z_index = -1
    else:
        weapon_left.z_index = 1
        weapon_right.z_index = 1


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
    if value is Array and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return fallback


func _on_animation_finished() -> void:
    if not is_attacking or current_action != "attack_01":
        return
    is_attacking = false
    combat_state = "free"
    _hit_registry.clear()
    _set_hitbox_active(false)
    _play_directional_animation("idle", facing_direction)


func _set_hitbox_active(active: bool) -> void:
    if _hitbox_active == active:
        return
    _hitbox_active = active
    attack_shape.set_deferred("disabled", not active)
    attack_hitbox.set_deferred("monitoring", active)
    queue_redraw()


func _on_attack_area_entered(area: Area2D) -> void:
    _try_hit_area(area)


func _try_hit_area(area: Area2D) -> void:
    if not _hitbox_active:
        return
    var target := area.get_parent()
    if target == null or not target.has_method("take_hit"):
        return
    var target_id := target.get_instance_id()
    if _hit_registry.has(target_id):
        return
    _hit_registry[target_id] = true
    var accepted: bool = target.take_hit(
        attack_data.damage,
        global_position,
        attack_data.knockback
    )
    if not accepted:
        return

    hit_confirmed.emit(target, attack_data.damage)
    var arena := get_tree().get_first_node_in_group("combat_arena")
    if arena != null and arena.has_method("report_combat_hit"):
        arena.report_combat_hit(target.global_position, attack_data)


func _draw() -> void:
    if not debug_visible:
        return
    draw_circle(Vector2.ZERO, 15.0, Color(0.2, 1.0, 0.35, 0.18))
    draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color(0.2, 1.0, 0.35), 1.5)
    draw_line(Vector2.ZERO, attack_direction * 78.0, Color(0.2, 0.8, 1.0), 2.0)

    var forward := attack_direction
    var side := Vector2(-forward.y, forward.x)
    var center := forward * 44.0
    var half_width := 30.0
    var half_height := 23.0
    var points := PackedVector2Array([
        center - forward * half_width - side * half_height,
        center + forward * half_width - side * half_height,
        center + forward * half_width + side * half_height,
        center - forward * half_width + side * half_height,
    ])
    var color := Color(1.0, 0.2, 0.1, 0.28) if _hitbox_active else Color(1.0, 0.65, 0.1, 0.12)
    draw_colored_polygon(points, color)
    points.append(points[0])
    draw_polyline(points, Color(1.0, 0.45, 0.15), 1.5)
