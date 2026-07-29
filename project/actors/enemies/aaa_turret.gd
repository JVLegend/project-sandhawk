class_name AAATurret
extends EnemyBase

## Canhao antiaereo: dorme -> trava a mira com linha de visada -> dispara em rajadas.
## Nao se move; a tensao vem do alcance longo e do dano alto.

var _turret_pivot: Node3D
var _lock_progress := 0.0


func _tick_state(delta: float) -> void:
	var distance := distance_to_player()
	var can_engage := distance <= definition.detection_range and has_line_of_sight_to_player()

	match state:
		State.IDLE:
			_lock_progress = 0.0
			if can_engage:
				state = State.ALERT

		State.ALERT:
			_aim_at_player(delta)
			if not can_engage:
				state = State.IDLE
				return

			_lock_progress += delta
			if _lock_progress >= definition.lock_on_time:
				state = State.ATTACK

		State.ATTACK:
			_aim_at_player(delta)
			if not can_engage or distance > definition.attack_range:
				state = State.ALERT
				_lock_progress = 0.0
				return
			start_burst()


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * definition.body_size.y * 0.6


func _aim_at_player(delta: float) -> void:
	if _player == null or _turret_pivot == null:
		return

	var offset := _player.global_position - global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length_squared() > 0.01:
		var target_yaw := atan2(flat.x, flat.z)
		_turret_pivot.rotation.y = lerp_angle(_turret_pivot.rotation.y, target_yaw, 1.0 - exp(-5.0 * delta))

	var target_pitch := -atan2(offset.y, maxf(0.1, flat.length()))
	_turret_pivot.rotation.x = lerp_angle(_turret_pivot.rotation.x, target_pitch, 1.0 - exp(-5.0 * delta))


func _build_visual() -> void:
	super._build_visual()

	var sandbags := MeshInstance3D.new()
	sandbags.name = "Sandbags"
	var ring := TorusMesh.new()
	ring.inner_radius = definition.body_size.x * 0.62
	ring.outer_radius = definition.body_size.x * 0.92
	ring.rings = 8
	ring.ring_segments = 16
	sandbags.mesh = ring
	sandbags.position = Vector3(0.0, -definition.body_size.y * 0.35, 0.0)

	var sandbag_material := StandardMaterial3D.new()
	sandbag_material.albedo_color = Color(0.62, 0.55, 0.38)
	sandbag_material.roughness = 0.95
	sandbags.material_override = sandbag_material
	add_child(sandbags)

	_turret_pivot = Node3D.new()
	_turret_pivot.name = "TurretPivot"
	_turret_pivot.position = Vector3(0.0, definition.body_size.y * 0.5, 0.0)
	add_child(_turret_pivot)

	var housing := MeshInstance3D.new()
	housing.name = "Housing"
	var housing_mesh := BoxMesh.new()
	housing_mesh.size = Vector3(1.2, 0.8, 1.4)
	housing.mesh = housing_mesh

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.29, 0.31, 0.27)
	metal.roughness = 0.65
	metal.metallic = 0.35
	housing.material_override = metal
	_turret_pivot.add_child(housing)

	for side in [-0.28, 0.28]:
		var barrel := MeshInstance3D.new()
		barrel.name = "Barrel%s" % ("L" if side < 0.0 else "R")
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.09
		barrel_mesh.bottom_radius = 0.09
		barrel_mesh.height = 2.4
		barrel_mesh.radial_segments = 8
		barrel.mesh = barrel_mesh
		barrel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		barrel.position = Vector3(side, 0.18, -1.1)
		barrel.material_override = metal
		_turret_pivot.add_child(barrel)


func _shoot_once() -> void:
	super._shoot_once()
	if _turret_pivot != null:
		Vfx.spawn_muzzle_flash(_turret_pivot, Vector3(0.0, 0.18, -2.2), Color(1.0, 0.72, 0.32), 0.55)
