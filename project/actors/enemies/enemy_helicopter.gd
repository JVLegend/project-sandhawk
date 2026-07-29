class_name EnemyHelicopter
extends EnemyBase

## Helicoptero inimigo: o unico que persegue em tres dimensoes. Mantem distancia
## de tiro e desliza de lado, entao nao da para simplesmente recuar dele.
## Ao morrer cai girando em vez de sumir no ar.

const STANDOFF_TOLERANCE := 8.0
const CRASH_SECONDS := 1.5

var _body_pivot: Node3D
var _rotor_pivot: Node3D
var _tail_rotor: Node3D
var _rotor_blur: MeshInstance3D
var _muzzle: Node3D
var _warning: MeshInstance3D

var _cruise_altitude := 14.0
var _orbit_sign := 1.0
var _blink := 0.0
var _crashing := false
var _crash_timer := 0.0
var _visual_roll := 0.0


func setup(p_definition: EnemyDefinition) -> void:
	super.setup(p_definition)
	_cruise_altitude = maxf(6.0, p_definition.spawn_altitude)
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0


func get_aim_point() -> Vector3:
	return global_position


func _tick_state(delta: float) -> void:
	if _crashing:
		_tick_crash(delta)
		return

	_blink += delta
	var distance := distance_to_player()
	var engaged := distance <= definition.attack_range and has_line_of_sight_to_player()

	match state:
		State.IDLE:
			velocity = velocity.move_toward(Vector3.ZERO, 6.0 * delta)
			VehicleParts.pulse_warning(_warning, false, _blink)
			if distance <= definition.detection_range:
				state = State.ALERT

		State.ALERT, State.ATTACK:
			VehicleParts.pulse_warning(_warning, true, _blink)
			_maneuver(delta)
			if engaged:
				state = State.ATTACK
				start_burst()
			else:
				state = State.ALERT
			if distance > definition.detection_range * 1.6:
				state = State.IDLE

	move_and_slide()
	_animate(delta)


## Aproxima ate a distancia de tiro e depois orbita, mantendo a altitude.
func _maneuver(delta: float) -> void:
	if _player == null:
		return

	var offset := _player.global_position - global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	var distance := flat.length()
	if distance < 0.01:
		return

	var forward := flat.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x) * _orbit_sign
	var ideal := definition.attack_range * 0.6

	var approach := 0.0
	if distance > ideal + STANDOFF_TOLERANCE:
		approach = 1.0
	elif distance < ideal - STANDOFF_TOLERANCE:
		approach = -1.0

	var heading := (forward * approach + side * 0.85).normalized()
	var planar := heading * definition.move_speed

	## Altitude e servo separado: persegue a do jogador com folga.
	var target_altitude := maxf(_cruise_altitude, _player.global_position.y + 2.0)
	var climb := clampf((target_altitude - global_position.y) * 1.6, -5.0, 5.0)

	velocity = Vector3(planar.x, climb, planar.z)

	var target_yaw := atan2(forward.x, forward.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-4.0 * delta))


func _animate(delta: float) -> void:
	if _rotor_pivot != null:
		_rotor_pivot.rotate_y(delta * 26.0)
	if _tail_rotor != null:
		_tail_rotor.rotate_x(delta * 40.0)

	if _body_pivot == null:
		return

	## Inclina para o lado do deslocamento lateral, como o do jogador.
	var lateral := Vector3(velocity.x, 0.0, velocity.z).dot(global_transform.basis.x)
	var target_roll := deg_to_rad(-clampf(lateral / maxf(definition.move_speed, 0.1), -1.0, 1.0) * 20.0)
	_visual_roll = lerp_angle(_visual_roll, target_roll, 1.0 - exp(-6.0 * delta))
	_body_pivot.rotation.z = _visual_roll


## Queda: gira sem controle e explode ao tocar o chao.
func _tick_crash(delta: float) -> void:
	_crash_timer += delta
	velocity.y -= 22.0 * delta
	velocity.x *= 0.99
	velocity.z *= 0.99
	rotate_y(delta * 7.0)
	if _body_pivot != null:
		_body_pivot.rotation.z += delta * 2.2

	if _rotor_pivot != null:
		_rotor_pivot.rotate_y(delta * lerpf(26.0, 4.0, clampf(_crash_timer / CRASH_SECONDS, 0.0, 1.0)))

	move_and_slide()

	if global_position.y <= 1.2 or _crash_timer >= CRASH_SECONDS:
		Vfx.spawn_explosion(global_position, definition.explosion_scale)
		get_tree().call_group("camera_rig", "add_trauma", 0.35)
		queue_free()


func _shoot_once() -> void:
	super._shoot_once()
	if _muzzle != null:
		Vfx.spawn_muzzle_flash(_muzzle, Vector3.ZERO, Color(1.0, 0.72, 0.32), 0.4)


## Em vez de sumir no ar, entra em queda. A explosao vem no impacto.
func _on_died(_event: DamageEvent) -> void:
	if _crashing:
		return

	_crashing = true
	state = State.DEAD
	remove_from_group("enemy")
	collision_layer = 0

	GameState.add_score(definition.score_value)
	GameState.hitstop()
	Vfx.spawn_explosion(global_position, definition.explosion_scale * 0.4)
	killed.emit(self)


func _build_visual() -> void:
	var paint := VehicleParts.material(definition.body_color, 0.68, 0.2)
	var dark := VehicleParts.material(definition.body_color.darkened(0.45), 0.7, 0.25)
	var glass := VehicleParts.material(Color(0.1, 0.14, 0.16), 0.15, 0.5)
	var steel := VehicleParts.material(Color(0.2, 0.2, 0.19), 0.6, 0.4)

	_body_pivot = Node3D.new()
	_body_pivot.name = "BodyPivot"
	add_child(_body_pivot)

	_body_mesh = VehicleParts.add_box(_body_pivot, "Fuselage", Vector3(1.9, 1.3, 3.4), Vector3(0.0, 0.0, 0.2), paint)
	VehicleParts.add_box(_body_pivot, "Nose", Vector3(1.5, 0.95, 1.5), Vector3(0.0, -0.14, -1.7), paint)
	var canopy := VehicleParts.add_box(_body_pivot, "Canopy", Vector3(1.4, 0.7, 1.6), Vector3(0.0, 0.55, -1.0), glass)
	canopy.rotation_degrees = Vector3(-14.0, 0.0, 0.0)

	VehicleParts.add_box(_body_pivot, "TailBoom", Vector3(0.5, 0.5, 3.4), Vector3(0.0, 0.32, 2.6), paint)
	var fin := VehicleParts.add_box(_body_pivot, "TailFin", Vector3(0.2, 1.4, 0.9), Vector3(0.0, 0.95, 4.1), dark)
	fin.rotation_degrees = Vector3(12.0, 0.0, 0.0)
	VehicleParts.add_box(_body_pivot, "Stabilizer", Vector3(1.9, 0.12, 0.6), Vector3(0.0, 0.4, 3.9), dark)

	## Cabides curtos com foguetes, para ler como helicoptero de ataque.
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		VehicleParts.add_box(_body_pivot, "Stub%s" % tag, Vector3(1.3, 0.16, 0.8), Vector3(side * 1.4, -0.15, 0.1), dark)
		var pod := VehicleParts.add_cylinder(_body_pivot, "Pod%s" % tag, 0.26, 1.2, Vector3(side * 1.85, -0.35, 0.0), steel, 10)
		pod.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	for side in [-0.85, 0.85]:
		var skid := VehicleParts.add_cylinder(_body_pivot, "Skid", 0.08, 3.0, Vector3(side, -0.95, 0.2), steel, 8)
		skid.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	_rotor_pivot = Node3D.new()
	_rotor_pivot.name = "RotorPivot"
	_rotor_pivot.position = Vector3(0.0, 1.1, 0.1)
	_body_pivot.add_child(_rotor_pivot)

	VehicleParts.add_cylinder(_rotor_pivot, "Hub", 0.3, 0.28, Vector3.ZERO, steel, 10)
	for index in 4:
		var blade := VehicleParts.add_box(_rotor_pivot, "Blade%d" % index, Vector3(0.22, 0.05, 4.8), Vector3.ZERO, steel)
		blade.rotation_degrees = Vector3(0.0, 45.0 * float(index), 0.0)
		blade.position = Vector3(sin(deg_to_rad(45.0 * index)) * 2.4, 0.04, cos(deg_to_rad(45.0 * index)) * 2.4)

	_rotor_blur = MeshInstance3D.new()
	_rotor_blur.name = "RotorBlur"
	var disc := CylinderMesh.new()
	disc.top_radius = 4.9
	disc.bottom_radius = 4.9
	disc.height = 0.02
	disc.radial_segments = 28
	_rotor_blur.mesh = disc

	var blur := StandardMaterial3D.new()
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.albedo_color = Color(0.78, 0.8, 0.84, 0.3)
	blur.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rotor_blur.material_override = blur
	_rotor_pivot.add_child(_rotor_blur)

	_tail_rotor = Node3D.new()
	_tail_rotor.name = "TailRotor"
	_tail_rotor.position = Vector3(0.28, 1.0, 4.2)
	_body_pivot.add_child(_tail_rotor)
	for angle in [0.0, 90.0]:
		var blade := VehicleParts.add_box(_tail_rotor, "TailBlade%d" % int(angle), Vector3(0.06, 1.4, 0.1), Vector3.ZERO, steel)
		blade.rotation_degrees = Vector3(angle, 0.0, 0.0)

	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0.0, -0.35, -2.2)
	_body_pivot.add_child(_muzzle)

	_warning = VehicleParts.add_warning_light(_body_pivot, Vector3(0.0, 0.85, 1.6), Color(1.0, 0.28, 0.2))
