class_name CombatAudio
extends Node

const MIX_RATE := 22050.0

var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0


func _ready() -> void:
    if DisplayServer.get_name() == "headless":
        return
    var generator := AudioStreamGenerator.new()
    generator.mix_rate = MIX_RATE
    generator.buffer_length = 0.35

    _audio_player = AudioStreamPlayer.new()
    _audio_player.stream = generator
    _audio_player.volume_db = -7.0
    add_child(_audio_player)
    _audio_player.play()
    _playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _exit_tree() -> void:
    if _audio_player != null:
        _audio_player.stop()
        _audio_player.stream = null
    _playback = null


func play_cast() -> void:
    _push_sweep(310.0, 720.0, 0.075, 0.17, 0.01)


func play_hit(critical: bool = false, explosive: bool = false) -> void:
    if explosive:
        _push_sweep(150.0, 58.0, 0.12, 0.24, 0.12)
    elif critical:
        _push_sweep(880.0, 330.0, 0.09, 0.23, 0.035)
    else:
        _push_sweep(260.0, 120.0, 0.055, 0.16, 0.065)


func play_dash() -> void:
    _push_sweep(180.0, 520.0, 0.08, 0.13, 0.045)


func _push_sweep(
        start_frequency: float,
        end_frequency: float,
        duration: float,
        volume: float,
        noise_amount: float
) -> void:
    if _playback == null:
        return
    var requested_frames := int(duration * MIX_RATE)
    var frame_count := mini(requested_frames, _playback.get_frames_available())
    if frame_count <= 0:
        return

    for frame_index: int in frame_count:
        var progress := float(frame_index) / float(frame_count)
        var frequency := lerpf(start_frequency, end_frequency, progress)
        _phase = fmod(_phase + TAU * frequency / MIX_RATE, TAU)
        var envelope := (1.0 - progress) * (1.0 - progress)
        var tonal := sin(_phase) * volume
        var noise := randf_range(-1.0, 1.0) * noise_amount
        var sample := clampf((tonal + noise) * envelope, -0.8, 0.8)
        _playback.push_frame(Vector2(sample, sample))
