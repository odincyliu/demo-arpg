class_name TrainingDummy
extends CharacterBody2D

const MONSTER_ASSET_ROOT := (
    "res://assets/third_party/kenney/monster_builder_pack/default/"
)
const MONSTER_COLORS := ["green", "blue", "red", "yellow", "dark", "white"]
const MONSTER_EYES := [
    "eye_angry_red.png",
    "eye_cute_light.png",
    "eye_yellow.png",
    "eye_red.png",
    "eye_blue.png",
    "eye_psycho_light.png",
]
const MONSTER_MOUTHS := [
    "mouth_closed_fangs.png",
    "mouth_closed_happy.png",
    "mouth_closed_sad.png",
    "mouth_closed_teeth.png",
    "mouthA.png",
    "mouthB.png",
]

@export_range(0, 5, 1) var monster_variant: int = 0
@export var max_hp: int = 100
@export var knockback_drag: float = 720.0

@onready var visual_root: Node2D = $Visual
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_collision: CollisionShape2D = $Hurtbox/CollisionShape2D

var current_hp: int
var debug_visible: bool = false
var is_dead: bool = false
var _knockback_velocity := Vector2.ZERO
var _flash_time: float = 0.0
var _idle_time: float = 0.0
var _arm_left: Sprite2D
var _arm_right: Sprite2D


func _ready() -> void:
    current_hp = max_hp
    add_to_group("training_dummy")
    _build_monster_visual()
    queue_redraw()


func _physics_process(delta: float) -> void:
    if is_dead:
        return
    _idle_time += delta
    var idle_wave := sin(_idle_time * 2.4 + monster_variant * 0.7)
    visual_root.position.y = -4.0 + idle_wave * 1.5
    if _arm_left != null and _arm_right != null:
        _arm_left.rotation_degrees = -8.0 + idle_wave * 3.5
        _arm_right.rotation_degrees = 8.0 - idle_wave * 3.5

    _knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_drag * delta)
    velocity = _knockback_velocity
    move_and_slide()
    if _flash_time > 0.0:
        _flash_time = maxf(0.0, _flash_time - delta)
        if is_zero_approx(_flash_time):
            visual_root.modulate = Color.WHITE
        queue_redraw()


func take_hit(damage: int, attack_origin: Vector2, knockback_force: float) -> bool:
    if is_dead:
        return false
    current_hp = maxi(0, current_hp - damage)
    var knockback_direction := global_position - attack_origin
    if knockback_direction.is_zero_approx():
        knockback_direction = Vector2.RIGHT
    _knockback_velocity += knockback_direction.normalized() * knockback_force
    _flash_time = 0.09
    visual_root.modulate = Color(1.0, 0.48, 0.48, 1.0)
    scale = Vector2(1.16, 0.84)
    create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(
        self,
        "scale",
        Vector2.ONE,
        0.14
    )
    queue_redraw()
    if current_hp <= 0:
        _die()
    return true


func set_debug_visible(enabled: bool) -> void:
    debug_visible = enabled
    queue_redraw()


func _build_monster_visual() -> void:
    var variant := posmod(monster_variant, MONSTER_COLORS.size())
    var color: String = MONSTER_COLORS[variant]
    _add_part(
        "LegLeft",
        "leg_%sA.png" % color,
        Vector2(-42, -78),
        false,
        -2
    )
    _add_part(
        "LegRight",
        "leg_%sA.png" % color,
        Vector2(42, -78),
        true,
        -2
    )
    _arm_left = _add_part(
        "ArmLeft",
        "arm_%sA.png" % color,
        Vector2(-112, -145),
        false,
        -1
    )
    _arm_right = _add_part(
        "ArmRight",
        "arm_%sA.png" % color,
        Vector2(112, -145),
        true,
        -1
    )
    _add_part(
        "Body",
        "body_%sA.png" % color,
        Vector2(0, -153),
        false,
        0
    )
    _add_part("Eye", MONSTER_EYES[variant], Vector2(0, -173), false, 1)
    _add_part("Mouth", MONSTER_MOUTHS[variant], Vector2(0, -123), false, 1)
    _add_part(
        "HornLeft",
        "detail_%s_horn_small.png" % color,
        Vector2(-49, -230),
        false,
        1
    )
    _add_part(
        "HornRight",
        "detail_%s_horn_small.png" % color,
        Vector2(49, -230),
        true,
        1
    )


func _add_part(
    part_name: String,
    file_name: String,
    part_position: Vector2,
    flip_h: bool,
    layer: int
) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = part_name
    sprite.texture = load(MONSTER_ASSET_ROOT + file_name) as Texture2D
    if sprite.texture == null:
        push_error("Missing Kenney monster part: %s" % file_name)
    sprite.position = part_position
    sprite.flip_h = flip_h
    sprite.z_index = layer
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    visual_root.add_child(sprite)
    return sprite


func _die() -> void:
    is_dead = true
    body_collision.set_deferred("disabled", true)
    hurtbox_collision.set_deferred("disabled", true)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "modulate:a", 0.0, 0.22)
    tween.tween_property(self, "scale", Vector2(1.25, 0.45), 0.22)
    tween.finished.connect(func() -> void: visible = false)


func _draw() -> void:
    var hp_ratio := float(current_hp) / float(max_hp)
    draw_rect(Rect2(-24, -69, 48, 6), Color(0.08, 0.06, 0.12, 0.9))
    draw_rect(Rect2(-23, -68, 46.0 * hp_ratio, 4), Color("f05b61"))
    if debug_visible:
        draw_circle(Vector2(0, -22), 21.0, Color(1.0, 0.15, 0.2, 0.13))
        draw_arc(Vector2(0, -22), 21.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.25), 1.5)
