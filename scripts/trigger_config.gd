class_name TriggerConfig
extends Resource

@export_range(1, 20, 1) var every_n: int = 1
@export_range(0.0, 100.0, 0.1) var chance: float = 100.0
@export_range(0.0, 5.0, 0.01) var internal_cooldown: float = 0.08
@export_range(0.0, 1.0, 0.01) var max_player_health_ratio: float = 1.0
@export var required_target_status: StringName = &"any"
@export_range(0.01, 1.0, 0.01) var damage_threshold_ratio: float = 0.1
@export_range(0.05, 5.0, 0.05) var channel_interval: float = 0.5


func normalized_copy() -> TriggerConfig:
    var result := TriggerConfig.new()
    result.every_n = clampi(every_n, 1, 20)
    result.chance = clampf(chance, 0.0, 100.0)
    result.internal_cooldown = clampf(internal_cooldown, 0.0, 5.0)
    result.max_player_health_ratio = clampf(max_player_health_ratio, 0.0, 1.0)
    result.required_target_status = required_target_status
    result.damage_threshold_ratio = clampf(damage_threshold_ratio, 0.01, 1.0)
    result.channel_interval = clampf(channel_interval, 0.05, 5.0)
    return result


func to_dictionary() -> Dictionary:
    return {
        "every_n": every_n,
        "chance": chance,
        "internal_cooldown": internal_cooldown,
        "max_player_health_ratio": max_player_health_ratio,
        "required_target_status": required_target_status,
        "damage_threshold_ratio": damage_threshold_ratio,
        "channel_interval": channel_interval,
    }
