class_name CombatCamera
extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 9.0
@export var shake_decay: float = 18.0
@export var maximum_shake: float = 4.0

var last_impulse: float = 0.0
var _shake_strength: float = 0.0
var _target: Node2D
var _random := RandomNumberGenerator.new()


func _ready() -> void:
    _random.seed = 0xB1ADB1ADE
    _target = get_node_or_null(target_path) as Node2D
    if _target != null:
        global_position = _target.global_position
    make_current()


func _process(delta: float) -> void:
    if _target != null:
        global_position = global_position.lerp(
            _target.global_position,
            1.0 - exp(-follow_speed * delta)
        )
    _shake_strength = move_toward(_shake_strength, 0.0, shake_decay * delta)
    if _shake_strength > 0.01:
        offset = Vector2(
            _random.randf_range(-1.0, 1.0),
            _random.randf_range(-1.0, 1.0)
        ).normalized() * _shake_strength
    else:
        offset = Vector2.ZERO


func add_impulse(amount: float) -> void:
    last_impulse = clampf(amount, 0.0, maximum_shake)
    _shake_strength = minf(maximum_shake, _shake_strength + last_impulse)

