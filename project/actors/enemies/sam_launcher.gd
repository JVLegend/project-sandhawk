class_name SamLauncher
extends EnemyBase

## Lancador SAM: alcance longo, dano alto, mas missil lento e despistavel.
## A defesa correta e quebrar a linha de visada atras de um obstaculo, nao correr.

var _rack_pivot: Node3D
var _lock_progress := 0.0
var _warning_light: MeshInstance3D
var _blink_time := 0.0


func _tick_state(delta: float) -> void:
	_blink_time += delta
	var distance := distance_to_player()
	var can_engage := distance <= definition.detection_range and has_line_of_sight_to_player()

	match state:
		State.IDLE:
			_lock_progress = 0.0
			_set_warning(false)
			if can_engage:
				state = State.ALERT

		State.ALERT:
			_aim_at_player(delta)
			_set_warning(true)
			if not can_engage:
				state = State.IDLE
				return

			_lock_progress += delta
			if _lock_progress >= definition.lock_on_time:
				state = State.ATTACK

		State.ATTACK:
			_aim_at_player(delta)
			_set_warning(true)
			if not can_engage or distance > definition.attack_range:
				state = State.ALERT
				_lock_progress = 0.0
				return
			start_burst()


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * definition.body_size.y * 0.7


func _aim_at_player(delta: float) -> void:
	if _player == null or _rack_pivot == null:
		return

	var offset := _player.global_position - global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length_squared() > 0.01:
		var target_yaw := atan2(flat.x, flat.z)
		_rack_pivot.rotation.y = lerp_angle(_rack_pivot.rotation.y, target_yaw, 1.0 - exp(-3.2 * delta))

	## Rampa de lancamento sempre inclinada para cima, nunca apontando ao chao.
	var target_pitch := clampf(-atan2(offset.y, maxf(0.1, flat.length())), -deg_to_rad(70.0), -deg_to_rad(18.0))
	_rack_pivot.rotation.x = lerp_angle(_rack_pivot.rotation.x, target_pitch, 1.0 - exp(-3.2 * delta))


func _set_warning(active: bool) -> void:
	if _warning_light == null:
		return

	var material := _warning_light.material_override as StandardMaterial3D
	if material == null:
		return

	if not active:
		material.emission_energy_multiplier = 0.0
		return

	material.emission_energy_multiplier = 2.0 + 3.0 * absf(sin(_blink_time * 7.0))


func _build_visual() -> void:
	super._build_visual()

	var tracks_material := StandardMaterial3D.new()
	tracks_material.albedo_color = Color(0.16, 0.16, 0.15)
	tracks_material.roughness = 0.9

	for side in [-1.2, 1.2]:
		var track := MeshInstance3D.new()
		track.name = "Track%s" % ("L" if side < 0.0 else "R")
		var track_mesh := BoxMesh.new()
		track_mesh.size = Vector3(0.7, 0.8, 4.2)
		track.mesh = track_mesh
		track.position = Vector3(side, -definition.body_size.y * 0.45, 0.0)
		track.material_override = tracks_material
		add_child(track)

	_rack_pivot = Node3D.new()
	_rack_pivot.name = "RackPivot"
	_rack_pivot.position = Vector3(0.0, definition.body_size.y * 0.55, 0.0)
	add_child(_rack_pivot)

	var rack_material := StandardMaterial3D.new()
	rack_material.albedo_color = Color(0.3, 0.33, 0.28)
	rack_material.metallic = 0.3
	rack_material.roughness = 0.65

	var rack := MeshInstance3D.new()
	rack.name = "Rack"
	var rack_mesh := BoxMesh.new()
	rack_mesh.size = Vector3(2.2, 0.5, 1.2)
	rack.mesh = rack_mesh
	rack.material_override = rack_material
	_rack_pivot.add_child(rack)

	var missile_material := StandardMaterial3D.new()
	missile_material.albedo_color = Color(0.82, 0.8, 0.74)
	missile_material.roughness = 0.5

	for slot in [-0.7, 0.0, 0.7]:
		var missile := MeshInstance3D.new()
		var missile_mesh := CapsuleMesh.new()
		missile_mesh.radius = 0.2
		missile_mesh.height = 3.0
		missile_mesh.radial_segments = 8
		missile_mesh.rings = 2
		missile.mesh = missile_mesh
		missile.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		missile.position = Vector3(slot, 0.42, -0.4)
		missile.material_override = missile_material
		_rack_pivot.add_child(missile)

	_warning_light = MeshInstance3D.new()
	_warning_light.name = "WarningLight"
	var light_mesh := SphereMesh.new()
	light_mesh.radius = 0.24
	light_mesh.height = 0.48
	light_mesh.radial_segments = 8
	light_mesh.rings = 4
	_warning_light.mesh = light_mesh
	_warning_light.position = Vector3(0.0, definition.body_size.y * 0.9, 1.4)

	var light_material := StandardMaterial3D.new()
	light_material.albedo_color = Color(0.7, 0.12, 0.1)
	light_material.emission_enabled = true
	light_material.emission = Color(1.0, 0.2, 0.16)
	light_material.emission_energy_multiplier = 0.0
	_warning_light.material_override = light_material
	add_child(_warning_light)


func _shoot_once() -> void:
	super._shoot_once()
	if _rack_pivot != null:
		Vfx.spawn_explosion(_rack_pivot.global_position + Vector3.UP * 0.5, 0.45)
