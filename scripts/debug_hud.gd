extends CanvasLayer

@export var player_path: NodePath

@onready var panel: ColorRect = $Panel
@onready var debug_text: Label = $Panel/DebugText

var debug_enabled: bool = false
var _player: ModularPlayer


func _ready() -> void:
    _player = get_node_or_null(player_path) as ModularPlayer
    panel.visible = debug_enabled


func _process(_delta: float) -> void:
    if debug_enabled and _player != null:
        debug_text.text = _player.get_debug_summary()


func set_debug_enabled(enabled: bool) -> void:
    debug_enabled = enabled
    panel.visible = enabled
