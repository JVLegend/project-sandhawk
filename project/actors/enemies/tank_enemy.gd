class_name TankEnemy
extends EnemyBase

## Tanque: lento, blindado e de tiro pesado com dano em area. E o alvo que
## obriga a gastar missil em vez de metralhadora.
## Para de avancar quando entra no alcance: tanque parado atira melhor.

var _turret_pivot: Node3D
var _barrel: Node3D
var _muzzle: Node3D
var _warning: MeshInstance3D
var _blink := 0.0
var _recoil := 0.0


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.9


func _tick_state(delta: float) -> void:
	_blink += delta
	_recoil = maxf(0.0, _recoil - delta * 3.2)
	if _barrel != null:
		_barrel.position.z = -1.85 + _recoil * 0.55

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
			_advance(delta)
			_aim_turret(delta)
			if engaged:
				state = State.ATTACK
			elif distance > definition.detection_range * 1.5:
				state = State.IDLE

		State.ATTACK:
			VehicleParts.pulse_warning(_warning, true, _blink)
			## Parado para atirar. Se o jogador se afasta, volta a perseguir.
			velocity = velocity.move_toward(Vector3.ZERO, 9.0 * delta)
			_aim_turret(delta)
			if not engaged:
				state = State.ALERT
			else:
				start_burst()

	move_and_slide()


func _advance(delta: float) -> void:
	if _player == null:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return

	velocity = offset.normalized() * definition.move_speed
	var target_yaw := atan2(offset.x, offset.z)
	## Chassi gira devagar: e um tanque, nao um carrinho.
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-1.6 * delta))


func _aim_turret(delta: float) -> void:
	if _player == null or _turret_pivot == null:
		return

	var offset := _player.global_position - _turret_pivot.global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length_squared() > 0.01:
		var target_yaw := atan2(flat.x, flat.z) - rotation.y
		_turret_pivot.rotation.y = lerp_angle(_turret_pivot.rotation.y, target_yaw, 1.0 - exp(-2.6 * delta))

	if _barrel != null:
		var pitch := clampf(-atan2(offset.y, maxf(0.1, flat.length())), -deg_to_rad(62.0), deg_to_rad(4.0))
		_barrel.rotation.x = lerp_angle(_barrel.rotation.x, pitch, 1.0 - exp(-2.6 * delta))


func _shoot_once() -> void:
	super._shoot_once()
	_recoil = 1.0
	get_tree().call_group("camera_rig", "add_trauma", 0.05)
	if _muzzle != null:
		Vfx.spawn_muzzle_flash(_muzzle, Vector3.ZERO, Color(1.0, 0.78, 0.34), 0.75)


func _build_visual() -> void:
	var paint := VehicleParts.material(definition.body_color, 0.82, 0.2)
	var dark := VehicleParts.material(definition.body_color.darkened(0.4), 0.85, 0.25)
	var steel := VehicleParts.material(Color(0.24, 0.24, 0.23), 0.6, 0.45)

	## Casco em duas alturas, com frente inclinada sugerindo blindagem.
	_body_mesh = VehicleParts.add_box(self, "Hull", Vector3(3.1, 0.85, 5.4), Vector3(0.0, 0.25, 0.0), paint)
	var glacis := VehicleParts.add_box(self, "Glacis", Vector3(3.0, 0.16, 1.7), Vector3(0.0, 0.52, -2.1), paint)
	glacis.rotation_degrees = Vector3(-26.0, 0.0, 0.0)
	VehicleParts.add_box(self, "Fenders", Vector3(3.9, 0.14, 4.6), Vector3(0.0, 0.62, 0.1), dark)

	VehicleParts.add_track(self, "TrackLeft", 5.6, 0.95, Vector3(-1.62, 0.05, 0.0))
	VehicleParts.add_track(self, "TrackRight", 5.6, 0.95, Vector3(1.62, 0.05, 0.0))

	_turret_pivot = Node3D.new()
	_turret_pivot.name = "TurretPivot"
	_turret_pivot.position = Vector3(0.0, 0.82, 0.25)
	add_child(_turret_pivot)

	VehicleParts.add_box(_turret_pivot, "Turret", Vector3(2.3, 0.72, 2.6), Vector3(0.0, 0.3, 0.0), paint)
	var mantlet := VehicleParts.add_box(_turret_pivot, "Mantlet", Vector3(1.1, 0.6, 0.5), Vector3(0.0, 0.3, -1.3), dark)
	mantlet.rotation_degrees = Vector3.ZERO
	VehicleParts.add_box(_turret_pivot, "Bustle", Vector3(1.8, 0.5, 0.7), Vector3(0.0, 0.34, 1.45), dark)
	VehicleParts.add_cylinder(_turret_pivot, "Cupola", 0.42, 0.34, Vector3(-0.55, 0.72, 0.4), dark, 10)
	VehicleParts.add_box(_turret_pivot, "Antenna", Vector3(0.06, 1.5, 0.06), Vector3(0.85, 1.2, 0.9), steel)

	## Cano em pivo proprio para elevar sem girar a torre inteira.
	_barrel = Node3D.new()
	_barrel.name = "BarrelPivot"
	_barrel.position = Vector3(0.0, 0.3, -1.85)
	_turret_pivot.add_child(_barrel)
	VehicleParts.add_barrel(_barrel, "Barrel", 0.13, 3.1, Vector3(0.0, 0.0, -1.3), steel)

	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0.0, 0.0, -2.9)
	_barrel.add_child(_muzzle)

	_warning = VehicleParts.add_warning_light(_turret_pivot, Vector3(0.55, 0.72, 0.9), Color(1.0, 0.35, 0.2))
