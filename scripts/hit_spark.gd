extends Node2D

const LIFETIME := 0.16

var _elapsed: float = 0.0


func _ready() -> void:
    rotation = randf_range(-0.35, 0.35)
    scale = Vector2(0.55, 0.55)
    queue_redraw()


func _process(delta: float) -> void:
    _elapsed += delta
    var progress := clampf(_elapsed / LIFETIME, 0.0, 1.0)
    scale = Vector2.ONE * lerpf(0.55, 1.35, progress)
    modulate.a = 1.0 - progress
    if _elapsed >= LIFETIME:
        queue_free()


func _draw() -> void:
    var gold := Color("ffd166")
    var cyan := Color("75f4f4")
    draw_line(Vector2(-18, 0), Vector2(18, 0), gold, 4.0)
    draw_line(Vector2(0, -16), Vector2(0, 16), Color.WHITE, 3.0)
    draw_line(Vector2(-12, -12), Vector2(12, 12), cyan, 3.0)
    draw_line(Vector2(-12, 12), Vector2(12, -12), gold, 3.0)
    draw_circle(Vector2.ZERO, 4.0, Color.WHITE)

