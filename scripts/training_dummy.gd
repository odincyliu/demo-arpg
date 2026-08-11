class_name TrainingDummy
extends CharacterBody2D

@export var max_hp: int = 100
@export var knockback_drag: float = 720.0

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_collision: CollisionShape2D = $Hurtbox/CollisionShape2D

var current_hp: int
var debug_visible: bool = false
var is_dead: bool = false
var _knockback_velocity := Vector2.ZERO
var _flash_time: float = 0.0


func _ready() -> void:
    current_hp = max_hp
    add_to_group("training_dummy")
    queue_redraw()


func _physics_process(delta: float) -> void:
    if is_dead:
        return
    _knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_drag * delta)
    velocity = _knockback_velocity
    move_and_slide()
    if _flash_time > 0.0:
        _flash_time = maxf(0.0, _flash_time - delta)
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
    var body_color := Color.WHITE if _flash_time > 0.0 else Color("6b4aa8")
    var belly_color := Color.WHITE if _flash_time > 0.0 else Color("a77be8")
    draw_circle(Vector2(0, -18), 18.0, body_color)
    draw_circle(Vector2(0, -12), 16.0, body_color)
    draw_circle(Vector2(-5, -16), 8.5, belly_color)
    draw_circle(Vector2(5, -16), 8.5, belly_color)
    draw_circle(Vector2(-6, -23), 2.5, Color("fff4d6"))
    draw_circle(Vector2(6, -23), 2.5, Color("fff4d6"))
    draw_circle(Vector2(-6, -23), 1.0, Color("251b35"))
    draw_circle(Vector2(6, -23), 1.0, Color("251b35"))
    draw_arc(Vector2(0, -18), 18.0, PI, TAU, 24, Color("302243"), 2.0)

    var hp_ratio := float(current_hp) / float(max_hp)
    draw_rect(Rect2(-20, -47, 40, 5), Color(0.08, 0.06, 0.12, 0.9))
    draw_rect(Rect2(-19, -46, 38.0 * hp_ratio, 3), Color("f05b61"))
    if debug_visible:
        draw_circle(Vector2(0, -18), 19.0, Color(1.0, 0.15, 0.2, 0.13))
        draw_arc(Vector2(0, -18), 19.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.25), 1.5)

