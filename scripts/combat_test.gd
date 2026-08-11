class_name CombatTest
extends Node2D

const HIT_SPARK_SCENE := preload("res://scenes/HitSpark.tscn")
const MAX_HIT_STOP := 0.065
const MAX_CAMERA_IMPULSE := 3.0
const HIT_STOP_TIME_SCALE := 0.06

@onready var player: ModularPlayer = $Player
@onready var combat_camera: CombatCamera = $CombatCamera
@onready var effects: Node2D = $Effects
@onready var debug_hud: CanvasLayer = $DebugHUD

var debug_enabled: bool = false
var combat_hit_count: int = 0
var hit_stop_count: int = 0
var last_aggregated_hit_count: int = 0
var _pending_hit_count: int = 0
var _pending_hit_stop: float = 0.0
var _pending_camera_impulse: float = 0.0
var _impact_flush_queued: bool = false
var _hit_stop_active: bool = false


func _ready() -> void:
    add_to_group("combat_arena")
    _set_debug_enabled(false)


func _exit_tree() -> void:
    Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
        _set_debug_enabled(not debug_enabled)
        get_viewport().set_input_as_handled()


func report_combat_hit(hit_position: Vector2, data: PlayerAttackData) -> void:
    combat_hit_count += 1
    _pending_hit_count += 1
    _pending_hit_stop = maxf(_pending_hit_stop, minf(data.hit_stop, MAX_HIT_STOP))
    _pending_camera_impulse = minf(
        MAX_CAMERA_IMPULSE,
        _pending_camera_impulse + data.camera_impulse * 0.45
    )

    var spark := HIT_SPARK_SCENE.instantiate() as Node2D
    effects.add_child(spark)
    spark.global_position = hit_position.lerp(player.global_position, 0.22)

    if not _impact_flush_queued:
        _impact_flush_queued = true
        call_deferred("_flush_impact_feedback")


func _set_debug_enabled(enabled: bool) -> void:
    debug_enabled = enabled
    player.set_debug_visible(enabled)
    for dummy: Node in get_tree().get_nodes_in_group("training_dummy"):
        if dummy.has_method("set_debug_visible"):
            dummy.set_debug_visible(enabled)
    debug_hud.set_debug_enabled(enabled)


func _flush_impact_feedback() -> void:
    _impact_flush_queued = false
    last_aggregated_hit_count = _pending_hit_count
    combat_camera.add_impulse(_pending_camera_impulse)
    if not _hit_stop_active and _pending_hit_stop > 0.0:
        _run_hit_stop(_pending_hit_stop)
    _pending_hit_count = 0
    _pending_hit_stop = 0.0
    _pending_camera_impulse = 0.0


func _run_hit_stop(duration: float) -> void:
    _hit_stop_active = true
    hit_stop_count += 1
    Engine.time_scale = HIT_STOP_TIME_SCALE
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0
    _hit_stop_active = false
