class_name PlayerAttackData
extends Resource

@export_category("Timing")
@export_range(0.0, 1.0, 0.001) var startup_time: float = 0.14
@export_range(0.0, 1.0, 0.001) var active_time: float = 0.14
@export_range(0.0, 1.0, 0.001) var recovery_time: float = 0.29
@export_range(0, 15, 1) var active_start_frame: int = 2
@export_range(0, 15, 1) var impact_frame: int = 3
@export_range(0, 15, 1) var active_end_frame: int = 4

@export_category("Impact")
@export_range(0, 1000, 1) var damage: int = 25
@export_range(0.0, 0.2, 0.001) var hit_stop: float = 0.055
@export_range(0.0, 1000.0, 1.0) var knockback: float = 280.0
@export_range(0.0, 300.0, 1.0) var lunge: float = 72.0
@export_range(0.0, 10.0, 0.1) var camera_impulse: float = 2.0

