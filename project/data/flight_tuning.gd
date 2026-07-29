class_name FlightTuning
extends Resource

@export_group("Flight")
@export var hover_altitude: float = 12.0
@export var max_speed: float = 14.0
@export var accel: float = 18.0
@export var decel_drag: float = 8.0
@export var turn_rate: float = 160.0
@export var strafe_ratio: float = 0.7

@export_group("Visual Feel")
@export var bank_max: float = 25.0
@export var pitch_max: float = 15.0
@export var bank_lerp: float = 8.0
@export var rotor_speed_degrees: float = 1500.0
@export var rotor_blur_threshold: float = 0.18
@export var rotor_blur_max_alpha: float = 0.72
@export var shadow_size: float = 7.0

@export_group("Camera")
@export var camera_smooth_time: float = 0.35
@export var camera_lookahead: float = 6.0
@export var camera_size_idle: float = 22.0
@export var camera_size_max_speed: float = 26.0
@export var camera_zoom_lerp: float = 2.5
@export var camera_local_offset: Vector3 = Vector3(22.0, 22.0, 22.0)
@export var camera_look_at_height: float = 0.0
@export var trauma_decay: float = 1.5
@export var trauma_translation: float = 0.45
