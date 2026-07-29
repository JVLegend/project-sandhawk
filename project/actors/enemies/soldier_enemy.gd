class_name SoldierEnemy
extends EnemyBase

## Soldado de infantaria: idle -> alert (persegue) -> attack -> flee com 1 HP.
## O modelo e humanoide de verdade, com pernas que andam quando ele se move.

const WALK_SWING_DEGREES := 34.0

var _spawn_position := Vector3.ZERO
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _walk_phase := 0.0
var _muzzle: Node3D


func setup(p_definition: EnemyDefinition) -> void:
	super.setup(p_definition)
	_spawn_position = global_position


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.35


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
	_animate_walk(delta)


## Pernas e braco balancam com a velocidade real, entao parado ele para de andar.
func _animate_walk(delta: float) -> void:
	if _left_leg == null:
		return

	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := speed > 0.2

	if moving:
		_walk_phase += delta * (4.0 + speed * 1.4)
	else:
		_walk_phase = lerpf(_walk_phase, 0.0, 1.0 - exp(-9.0 * delta))

	var swing := sin(_walk_phase) * deg_to_rad(WALK_SWING_DEGREES) * (1.0 if moving else 0.0)
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	if _left_arm != null:
		_left_arm.rotation.x = -swing * 0.5


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


func _shoot_once() -> void:
	super._shoot_once()
	if _muzzle != null:
		Vfx.spawn_muzzle_flash(_muzzle, Vector3.ZERO, Color(1.0, 0.82, 0.4), 0.16)


## Silhueta humana em vez de caixa: cabeca, tronco, mochila, dois bracos e duas
## pernas articuladas. Continua low-poly, mas le como pessoa a distancia.
func _build_visual() -> void:
	var uniform := VehicleParts.material(definition.body_color, 0.92, 0.0)
	var webbing := VehicleParts.material(definition.body_color.darkened(0.42), 0.95, 0.0)
	var skin := VehicleParts.material(Color(0.66, 0.5, 0.37), 0.85, 0.0)
	var steel := VehicleParts.material(Color(0.14, 0.14, 0.14), 0.6, 0.3)

	## Tronco: o mesh que pisca ao levar dano.
	_body_mesh = VehicleParts.add_box(self, "Torso", Vector3(0.62, 0.72, 0.36), Vector3(0.0, 0.34, 0.0), uniform)

	VehicleParts.add_box(self, "Backpack", Vector3(0.46, 0.5, 0.22), Vector3(0.0, 0.36, 0.26), webbing)
	VehicleParts.add_box(self, "Belt", Vector3(0.66, 0.12, 0.4), Vector3(0.0, 0.02, 0.0), webbing)

	var neck := VehicleParts.add_cylinder(self, "Neck", 0.1, 0.12, Vector3(0.0, 0.76, 0.0), skin, 8)
	neck.rotation_degrees = Vector3.ZERO

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.34
	head_mesh.radial_segments = 10
	head_mesh.rings = 6
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.94, 0.0)
	head.material_override = skin
	add_child(head)

	## Capacete com aba, o detalhe que mais vende "soldado" de cima.
	var helmet := MeshInstance3D.new()
	helmet.name = "Helmet"
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.2
	helmet_mesh.height = 0.28
	helmet_mesh.radial_segments = 12
	helmet_mesh.rings = 6
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 1.0, 0.0)
	helmet.material_override = webbing
	add_child(helmet)
	VehicleParts.add_box(self, "HelmetBrim", Vector3(0.4, 0.05, 0.42), Vector3(0.0, 0.95, -0.04), webbing)

	## Pernas articuladas: pivo no quadril para o balanco parecer passada.
	_left_leg = _build_limb("LegLeft", Vector3(-0.16, 0.0, 0.0), Vector3(0.22, 0.52, 0.24), uniform, steel)
	_right_leg = _build_limb("LegRight", Vector3(0.16, 0.0, 0.0), Vector3(0.22, 0.52, 0.24), uniform, steel)

	## Braco esquerdo balanca; o direito fica firme segurando o fuzil.
	_left_arm = _build_limb("ArmLeft", Vector3(-0.4, 0.6, 0.0), Vector3(0.16, 0.46, 0.18), uniform, null)

	var right_arm := Node3D.new()
	right_arm.name = "ArmRight"
	right_arm.position = Vector3(0.36, 0.6, 0.0)
	add_child(right_arm)
	VehicleParts.add_box(right_arm, "Upper", Vector3(0.16, 0.44, 0.18), Vector3(0.0, -0.22, -0.06), uniform)

	VehicleParts.add_box(right_arm, "Rifle", Vector3(0.08, 0.09, 0.86), Vector3(0.02, -0.34, -0.44), steel)
	VehicleParts.add_box(right_arm, "Magazine", Vector3(0.06, 0.2, 0.1), Vector3(0.02, -0.44, -0.34), steel)

	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0.02, -0.34, -0.86)
	right_arm.add_child(_muzzle)


func _build_limb(limb_name: String, hip: Vector3, size: Vector3, cloth: Material, boot: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = limb_name
	pivot.position = hip
	add_child(pivot)

	VehicleParts.add_box(pivot, "Segment", size, Vector3(0.0, -size.y * 0.5, 0.0), cloth)
	if boot != null:
		VehicleParts.add_box(pivot, "Boot", Vector3(size.x * 1.1, 0.14, size.z * 1.5), Vector3(0.0, -size.y - 0.05, -0.04), boot)

	return pivot
