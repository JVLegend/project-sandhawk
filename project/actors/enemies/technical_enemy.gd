class_name TechnicalEnemy
extends EnemyBase

## Picape armada. Rapida e fragil: o papel dela e forcar o jogador a se mover,
## nao a aguentar dano. Circula em vez de parar de frente, entao mira parada
## nao resolve.

const ORBIT_TOLERANCE := 6.0

var _turret_pivot: Node3D
var _muzzle: Node3D
var _warning: MeshInstance3D
var _wheels: Array[Node3D] = []
var _orbit_sign := 1.0
var _blink := 0.0


func setup(p_definition: EnemyDefinition) -> void:
	super.setup(p_definition)
	## Metade das picapes circula para cada lado, para nao virarem um trenzinho.
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.4


func _tick_state(delta: float) -> void:
	_blink += delta
	var distance := distance_to_player()
	var engaged := distance <= definition.attack_range and has_line_of_sight_to_player()

	match state:
		State.IDLE:
			velocity = Vector3.ZERO
			VehicleParts.pulse_warning(_warning, false, _blink)
			if distance <= definition.detection_range:
				state = State.ALERT

		State.ALERT:
			VehicleParts.pulse_warning(_warning, true, _blink)
			_drive_toward(definition.move_speed, delta)
			if engaged:
				state = State.ATTACK
			elif distance > definition.detection_range * 1.5:
				state = State.IDLE

		State.ATTACK:
			VehicleParts.pulse_warning(_warning, true, _blink)
			_orbit(delta)
			_aim_turret(delta)
			if not engaged:
				state = State.ALERT
			else:
				start_burst()

	move_and_slide()
	_spin_wheels(delta)


func _drive_toward(speed: float, delta: float) -> void:
	if _player == null:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return
	velocity = offset.normalized() * speed
	_steer(offset, delta)
	_aim_turret(delta)


## Mantem a distancia de tiro andando de lado, em vez de parar colado.
func _orbit(delta: float) -> void:
	if _player == null:
		return

	var offset := _player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.01:
		return

	var forward := offset.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x) * _orbit_sign
	var ideal := definition.attack_range * 0.65

	var approach := 0.0
	if distance > ideal + ORBIT_TOLERANCE:
		approach = 1.0
	elif distance < ideal - ORBIT_TOLERANCE:
		approach = -1.0

	var heading := (side + forward * approach).normalized()
	velocity = heading * definition.move_speed
	_steer(heading, delta)


func _steer(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-4.5 * delta))


func _aim_turret(delta: float) -> void:
	if _player == null or _turret_pivot == null:
		return

	var offset := _player.global_position - _turret_pivot.global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length_squared() > 0.01:
		## Angulo local: a torre gira sobre o chassi, que ja esta girado.
		var target_yaw := atan2(flat.x, flat.z) - rotation.y
		_turret_pivot.rotation.y = lerp_angle(_turret_pivot.rotation.y, target_yaw, 1.0 - exp(-7.0 * delta))

	var pitch := clampf(-atan2(offset.y, maxf(0.1, flat.length())), -deg_to_rad(75.0), deg_to_rad(6.0))
	_turret_pivot.rotation.x = lerp_angle(_turret_pivot.rotation.x, pitch, 1.0 - exp(-7.0 * delta))


func _spin_wheels(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.05:
		return
	for wheel in _wheels:
		wheel.rotate_x(delta * speed * 1.6)


func _shoot_once() -> void:
	super._shoot_once()
	if _muzzle != null:
		Vfx.spawn_muzzle_flash(_muzzle, Vector3.ZERO, Color(1.0, 0.8, 0.36), 0.3)


func _build_visual() -> void:
	var paint := VehicleParts.material(definition.body_color, 0.78, 0.15)
	var dark := VehicleParts.material(definition.body_color.darkened(0.45), 0.8, 0.2)
	var glass := VehicleParts.material(Color(0.12, 0.16, 0.18), 0.2, 0.5)
	var steel := VehicleParts.material(Color(0.22, 0.22, 0.21), 0.6, 0.45)

	_body_mesh = VehicleParts.add_box(self, "Chassis", Vector3(1.9, 0.5, 4.4), Vector3(0.0, 0.1, 0.0), paint)

	VehicleParts.add_box(self, "Hood", Vector3(1.8, 0.42, 1.4), Vector3(0.0, 0.42, -1.4), paint)
	VehicleParts.add_box(self, "Cab", Vector3(1.76, 0.78, 1.5), Vector3(0.0, 0.72, -0.15), paint)
	VehicleParts.add_box(self, "Windshield", Vector3(1.6, 0.5, 0.1), Vector3(0.0, 0.82, -0.88), glass)
	VehicleParts.add_box(self, "Roof", Vector3(1.8, 0.1, 1.5), Vector3(0.0, 1.13, -0.15), dark)

	## Cacamba com laterais: e onde a metralhadora fica montada.
	VehicleParts.add_box(self, "BedFloor", Vector3(1.8, 0.12, 2.1), Vector3(0.0, 0.4, 1.3), dark)
	for side in [-0.86, 0.86]:
		VehicleParts.add_box(self, "BedSide%s" % ("L" if side < 0.0 else "R"), Vector3(0.1, 0.44, 2.1), Vector3(side, 0.62, 1.3), dark)
	VehicleParts.add_box(self, "Tailgate", Vector3(1.8, 0.44, 0.1), Vector3(0.0, 0.62, 2.32), dark)

	VehicleParts.add_box(self, "BullBar", Vector3(1.7, 0.5, 0.14), Vector3(0.0, 0.35, -2.24), steel)

	for spot in [Vector3(-0.95, 0.0, -1.4), Vector3(0.95, 0.0, -1.4), Vector3(-0.95, 0.0, 1.5), Vector3(0.95, 0.0, 1.5)]:
		_wheels.append(VehicleParts.add_wheel(self, "Wheel", 0.44, 0.34, spot))

	_turret_pivot = Node3D.new()
	_turret_pivot.name = "TurretPivot"
	_turret_pivot.position = Vector3(0.0, 0.78, 1.25)
	add_child(_turret_pivot)

	VehicleParts.add_cylinder(_turret_pivot, "Mount", 0.24, 0.3, Vector3(0.0, -0.1, 0.0), steel, 10)
	VehicleParts.add_box(_turret_pivot, "Receiver", Vector3(0.24, 0.24, 0.8), Vector3(0.0, 0.16, -0.2), steel)
	VehicleParts.add_box(_turret_pivot, "AmmoBox", Vector3(0.3, 0.24, 0.32), Vector3(0.26, 0.1, 0.1), dark)
	VehicleParts.add_barrel(_turret_pivot, "Barrel", 0.06, 1.3, Vector3(0.0, 0.16, -1.1), steel)

	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0.0, 0.16, -1.78)
	_turret_pivot.add_child(_muzzle)

	_warning = VehicleParts.add_warning_light(self, Vector3(0.0, 1.24, -0.15), Color(1.0, 0.6, 0.15))
