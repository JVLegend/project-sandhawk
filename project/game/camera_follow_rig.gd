class_name CameraFollowRig
extends Node3D

var tuning

var follow_target: Node3D
var smoothing_velocity := Vector3.ZERO
var trauma := 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	## Armas, explosoes e mortes chamam add_trauma via grupo, sem acoplar referencias.
	add_to_group("camera_rig")


func configure(target_node: Node3D, tuning_resource) -> void:
	follow_target = target_node
	tuning = tuning_resource
	global_position = target_node.global_position
	if camera != null and tuning != null:
		camera.size = tuning.camera_size_idle
		camera.position = tuning.camera_local_offset
		camera.look_at(global_position + Vector3.UP * tuning.camera_look_at_height, Vector3.UP)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if follow_target == null or tuning == null:
		return

	trauma = move_toward(trauma, 0.0, tuning.trauma_decay * delta)

	var lookahead := Vector3.ZERO
	if follow_target.has_method("get_planar_velocity"):
		var planar_velocity: Vector2 = follow_target.get_planar_velocity()
		if planar_velocity.length_squared() > 0.001:
			lookahead = Vector3(planar_velocity.x, 0.0, planar_velocity.y).normalized() * tuning.camera_lookahead

	var desired_position := follow_target.global_position + lookahead
	global_position = _smooth_damp(global_position, desired_position, delta, tuning.camera_smooth_time)

	var speed_ratio := 0.0
	if follow_target.has_method("get_speed_ratio"):
		speed_ratio = follow_target.get_speed_ratio()

	var target_size := lerpf(tuning.camera_size_idle, tuning.camera_size_max_speed, speed_ratio)
	camera.size = lerpf(camera.size, target_size, 1.0 - exp(-tuning.camera_zoom_lerp * delta))

	var shake_strength: float = trauma * trauma * float(tuning.trauma_translation)
	var shake_offset := Vector3.ZERO
	if shake_strength > 0.0:
		shake_offset = Vector3(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

	camera.position = tuning.camera_local_offset + shake_offset
	camera.look_at(global_position + Vector3.UP * tuning.camera_look_at_height, Vector3.UP)


func _smooth_damp(current: Vector3, target: Vector3, delta: float, smooth_time: float) -> Vector3:
	var clamped_time := maxf(0.001, smooth_time)
	var omega := 2.0 / clamped_time
	var x := omega * delta
	var exp_factor := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)

	var change := current - target
	var temp := (smoothing_velocity + omega * change) * delta
	smoothing_velocity = (smoothing_velocity - omega * temp) * exp_factor

	return target + (change + temp) * exp_factor
