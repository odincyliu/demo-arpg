extends Node2D


func _ready() -> void:
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(-780, -440, 1560, 880), Color("18283a"))
    for x in range(-768, 769, 64):
        draw_line(Vector2(x, -420), Vector2(x, 420), Color(0.2, 0.38, 0.48, 0.16), 1.0)
    for y in range(-384, 385, 64):
        draw_line(Vector2(-750, y), Vector2(750, y), Color(0.2, 0.38, 0.48, 0.16), 1.0)
    draw_rect(Rect2(-700, -390, 1400, 780), Color(0.25, 0.72, 0.78, 0.52), false, 4.0)
    draw_circle(Vector2.ZERO, 155.0, Color(0.1, 0.25, 0.34, 0.45))
    draw_arc(Vector2.ZERO, 155.0, 0.0, TAU, 96, Color(0.3, 0.75, 0.8, 0.28), 2.0)
    draw_string(
        ThemeDB.fallback_font,
        Vector2(-88, 205),
        "GROUP HIT TEST ZONE",
        HORIZONTAL_ALIGNMENT_LEFT,
        -1,
        16,
        Color(0.58, 0.84, 0.86, 0.46)
    )

