class_name ModularPlayer
extends CharacterBody2D

signal attack_started(direction: String)
signal hit_confirmed(target: Node, damage: int)

const DEFAULT_CHARACTER_PROFILE := (
    "res://assets/characters/super_clone_cyborg/character_profile.json"
)
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

@export_file("*.json") var character_profile_path: String = DEFAULT_CHARACTER_PROFILE
@export var move_speed: float = 190.0
@export var attack_move_multiplier: float = 0.38
@export var arena_bounds := Rect2(-700.0, -390.0, 1400.0, 780.0)
@export var attack_data: PlayerAttackData

@onready var visual_rig: Node2D = $VisualRig
@onready var body: AnimatedSprite2D = $VisualRig/Body
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Area2D = $AttackPivot/AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackPivot/AttackHitbox/CollisionShape2D

var facing_direction: String = "south"
var current_action: String = "idle"
var combat_state: String = "free"
var debug_visible: bool = false
var is_attacking: bool = false
var attack_direction := Vector2.DOWN
var character_profile: Dictionary = {}
var _hit_registry: Dictionary = {}
var _hitbox_active: bool = false
var _lunge_velocity := Vector2.ZERO
var _lunge_applied: bool = false


func _ready() -> void:
    add_to_group("player")
    character_profile = SpriteFramesBuilder.load_json(character_profile_path)
    body.sprite_frames = SpriteFramesBuilder.build(character_profile_path)
    body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    body.frame_changed.connect(_on_body_frame_changed)
    body.animation_finished.connect(_on_animation_finished)
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
    if event is InputEventMouseButton:
        if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
            return
        var mouse_aim := get_global_mouse_position() - global_position
        if mouse_aim.length_squared() < 64.0:
            mouse_aim = direction_to_vector(facing_direction)
        start_attack(mouse_aim)
    elif event is InputEventKey:
        if (
            event.pressed
            and not event.echo
            and (event.keycode == KEY_J or event.keycode == KEY_SPACE)
        ):
            start_attack(direction_to_vector(facing_direction))


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
    return "Facing: %s\nAnimation: %s (frame %d / atlas %d)\nCombat: %s\nHitbox: %s\nSwing hits: %d" % [
        facing_direction.to_upper(),
        current_action,
        frame,
        get_current_atlas_column(),
        combat_state,
        "ACTIVE" if _hitbox_active else "off",
        _hit_registry.size(),
    ]


func get_current_atlas_column() -> int:
    var animations: Dictionary = character_profile.get("animations", {})
    var animation_data: Dictionary = animations.get(current_action, {})
    var columns: Array = animation_data.get("columns", [])
    if columns.is_empty():
        return -1
    return int(columns[posmod(body.frame, columns.size())])


func get_direction_row(direction: String) -> int:
    var rows: Dictionary = character_profile.get("direction_rows", {})
    return int(rows.get(direction, -1))


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


func _play_directional_animation(action: String, direction: String) -> void:
    var animation_name := "%s_%s" % [action, direction]
    if not body.sprite_frames.has_animation(animation_name):
        push_error("Missing player animation: %s" % animation_name)
        return
    facing_direction = direction
    body.flip_h = false
    current_action = action
    if body.animation != animation_name or not body.is_playing():
        body.play(animation_name)


func _is_playing_direction(direction: String) -> bool:
    return body.animation == "%s_%s" % [current_action, direction]


func _on_body_frame_changed() -> void:
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
    draw_line(Vector2.ZERO, attack_direction * 82.0, Color(0.2, 0.8, 1.0), 2.0)

    var forward := attack_direction
    var side := Vector2(-forward.y, forward.x)
    var center := forward * 46.0
    var half_width := 34.0
    var half_height := 27.0
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
