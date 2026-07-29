class_name SoldierEnemy
extends EnemyBase

## Soldado AK: idle -> alert (persegue) -> attack -> flee com 1 HP.

var _spawn_position := Vector3.ZERO


func setup(p_definition: EnemyDefinition) -> void:
	super.setup(p_definition)
	_spawn_position = global_position


func _tick_state(delta: float) -> void:
	var distance := distance_to_player()

	if definition.flee_at_hp > 0 and health.hp <= definition.flee_at_hp and state != State.FLEE:
		state = State.FLEE

	match state:
		State.IDLE:
			velocity = Vector3.ZERO
			if distance <= definition.detection_range:
				state = State.ALERT

		State.ALERT:
			_move_toward_player(definition.move_speed, delta)
			if distance <= definition.attack_range and has_line_of_sight_to_player():
				state = State.ATTACK
			elif distance > definition.detection_range * 1.4:
				state = State.IDLE

		State.ATTACK:
			velocity = Vector3.ZERO
			_face_player(delta)
			if distance > definition.attack_range or not has_line_of_sight_to_player():
				state = State.ALERT
			else:
				start_burst()

		State.FLEE:
			_move_away_from_player(definition.flee_speed, delta)

	move_and_slide()


func _move_toward_player(speed: float, delta: float) -> void:
	if _player == null:
		return

	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		velocity = Vector3.ZERO
		return

	velocity = offset.normalized() * speed
	_face_player(delta)


func _move_away_from_player(speed: float, delta: float) -> void:
	if _player == null:
		return

	var offset := global_position - _player.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return

	velocity = offset.normalized() * speed
	_face_direction(offset, delta)


func _face_player(delta: float) -> void:
	if _player == null:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	_face_direction(offset, delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-9.0 * delta))


func _build_visual() -> void:
	super._build_visual()

	var helmet := MeshInstance3D.new()
	helmet.name = "Helmet"
	var mesh := SphereMesh.new()
	mesh.radius = definition.body_size.x * 0.42
	mesh.height = definition.body_size.x * 0.7
	mesh.radial_segments = 10
	mesh.rings = 5
	helmet.mesh = mesh
	helmet.position = Vector3(0.0, definition.body_size.y * 0.55, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = definition.body_color.darkened(0.35)
	material.roughness = 0.9
	helmet.material_override = material
	add_child(helmet)

	var rifle := MeshInstance3D.new()
	rifle.name = "Rifle"
	var rifle_mesh := BoxMesh.new()
	rifle_mesh.size = Vector3(0.1, 0.1, 1.1)
	rifle.mesh = rifle_mesh
	rifle.position = Vector3(definition.body_size.x * 0.45, definition.body_size.y * 0.1, -0.45)

	var rifle_material := StandardMaterial3D.new()
	rifle_material.albedo_color = Color(0.16, 0.15, 0.14)
	rifle_material.roughness = 0.7
	rifle.material_override = rifle_material
	add_child(rifle)
