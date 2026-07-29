class_name FriendlyBase
extends Node3D

const SURFACE_FACTORY := preload("res://world/props/surface_factory.gd")

## Base amiga: pairar sobre o pad por alguns segundos entrega os resgatados e
## reabastece tudo devagar. A lentidao e proposital: reabastecer e uma escolha
## de risco, nao um botao.

signal hold_progress(ratio: float)
signal service_started
signal service_progress(ratio: float)
signal service_finished
signal passengers_delivered(count: int)

enum State {
	IDLE,
	HOLDING,
	SERVICING,
	DONE,
}

var tuning: ResourceTuning
var state: int = State.IDLE

var _player: Node3D
var _hold_timer := 0.0
var _service_ratio := 0.0
var _pad_ring: MeshInstance3D
var _pulse_time := 0.0


func setup(p_tuning: ResourceTuning) -> void:
	tuning = p_tuning


func _ready() -> void:
	add_to_group("friendly_base")
	_build_visual()


func _process(delta: float) -> void:
	_pulse_time += delta
	_update_pad_visual()

	if tuning == null:
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return

	var inside := _player_on_pad()

	match state:
		State.IDLE:
			if inside:
				state = State.HOLDING
				_hold_timer = 0.0

		State.HOLDING:
			if not inside:
				_reset()
				return
			_hold_timer += delta
			hold_progress.emit(clampf(_hold_timer / tuning.pad_hold_seconds, 0.0, 1.0))
			if _hold_timer >= tuning.pad_hold_seconds:
				_start_service()

		State.SERVICING:
			if not inside:
				_reset()
				return
			_tick_service(delta)

		State.DONE:
			if not inside:
				_reset()


func _player_on_pad() -> bool:
	if _player == null:
		return false
	if _player.has_method("is_alive") and not _player.is_alive():
		return false

	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > tuning.pad_radius:
		return false

	if _player.has_method("get_planar_speed"):
		return _player.get_planar_speed() <= tuning.pad_max_speed

	return true


func _start_service() -> void:
	state = State.SERVICING
	_service_ratio = 0.0
	service_started.emit()

	if _player.has_method("deliver_passengers"):
		var delivered: int = _player.deliver_passengers()
		if delivered > 0:
			GameState.add_score(tuning.delivery_score_bonus * delivered)
			passengers_delivered.emit(delivered)


func _tick_service(delta: float) -> void:
	var step := delta / maxf(0.1, tuning.refuel_seconds)
	_service_ratio = clampf(_service_ratio + step, 0.0, 1.0)

	if _player.has_method("receive_service"):
		_player.receive_service(step)

	service_progress.emit(_service_ratio)

	if _service_ratio >= 1.0:
		state = State.DONE
		service_finished.emit()


func _reset() -> void:
	state = State.IDLE
	_hold_timer = 0.0
	_service_ratio = 0.0
	hold_progress.emit(0.0)


func _update_pad_visual() -> void:
	if _pad_ring == null:
		return

	var material := _pad_ring.material_override as StandardMaterial3D
	if material == null:
		return

	var color := Color(0.35, 0.85, 0.95)
	var alpha := 0.35 + 0.2 * sin(_pulse_time * 2.0)

	if state == State.HOLDING:
		alpha = 0.55 + 0.35 * sin(_pulse_time * 8.0)
	elif state == State.SERVICING:
		color = Color(0.45, 0.95, 0.5)
		alpha = 0.6 + 0.3 * sin(_pulse_time * 12.0)
	elif state == State.DONE:
		color = Color(0.45, 0.95, 0.5)
		alpha = 0.4

	material.albedo_color = Color(color.r, color.g, color.b, alpha)


func _build_visual() -> void:
	var radius := 9.0 if tuning == null else tuning.pad_radius

	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = radius
	pad_mesh.bottom_radius = radius
	pad_mesh.height = 0.3
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.position = Vector3(0.0, 0.15, 0.0)

	var pad_material := SURFACE_FACTORY.make_concrete_material(Color(0.24, 0.25, 0.26), 4101, Vector3(3.0, 3.0, 3.0))
	pad.material_override = pad_material
	add_child(pad)

	_pad_ring = MeshInstance3D.new()
	_pad_ring.name = "PadRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.82
	ring_mesh.outer_radius = radius * 0.92
	ring_mesh.rings = 6
	ring_mesh.ring_segments = 32
	_pad_ring.mesh = ring_mesh
	_pad_ring.position = Vector3(0.0, 0.34, 0.0)

	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.albedo_color = Color(0.35, 0.85, 0.95, 0.4)
	_pad_ring.material_override = ring_material
	add_child(_pad_ring)

	_add_pad_marking(Vector3(-1.6, 0.32, 0.0), Vector3(0.5, 0.05, 4.0))
	_add_pad_marking(Vector3(1.6, 0.32, 0.0), Vector3(0.5, 0.05, 4.0))
	_add_pad_marking(Vector3(0.0, 0.32, 0.0), Vector3(3.2, 0.05, 0.5))

	_add_building(Vector3(radius + 5.0, 0.0, -3.0), Vector3(6.0, 3.4, 8.0), Color(0.36, 0.37, 0.32))
	_add_building(Vector3(-radius - 4.5, 0.0, 4.0), Vector3(5.0, 2.6, 5.0), Color(0.31, 0.33, 0.28))
	_add_fuel_tank(Vector3(-radius - 4.0, 0.0, -6.0))
	_add_fuel_tank(Vector3(-radius - 6.6, 0.0, -6.0))
	_add_antenna(Vector3(radius + 8.0, 0.0, 2.8))


func _add_pad_marking(marking_position: Vector3, size: Vector3) -> void:
	var marking := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	marking.mesh = mesh
	marking.position = marking_position

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.87, 0.84)
	material.roughness = 0.9
	marking.material_override = material
	add_child(marking)


func _add_building(building_position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = building_position + Vector3(0.0, size.y * 0.5, 0.0)
	body.collision_layer = CombatLayers.WORLD
	body.collision_mask = 0
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh

	var material := SURFACE_FACTORY.make_concrete_material(color, int(size.x * 83.0 + size.z * 59.0), Vector3(2.8, 2.8, 2.8))
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(size.x + 0.5, 0.26, size.z + 0.5)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, size.y * 0.5 + 0.24, 0.0)
	roof.material_override = SURFACE_FACTORY.make_roof_material(color.lightened(0.08), int(size.y * 211.0), Vector3(3.2, 3.2, 3.2))
	body.add_child(roof)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _add_fuel_tank(tank_position: Vector3) -> void:
	var tank := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.2
	mesh.bottom_radius = 1.2
	mesh.height = 3.0
	mesh.radial_segments = 14
	tank.mesh = mesh
	tank.position = tank_position + Vector3(0.0, 1.5, 0.0)

	var material := SURFACE_FACTORY.make_metal_material(Color(0.5, 0.47, 0.35), int(tank_position.x * 31.0 + tank_position.z * 29.0), Vector3(2.8, 2.8, 2.8), 0.3, 0.6)
	tank.material_override = material
	add_child(tank)


func _add_antenna(antenna_position: Vector3) -> void:
	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.1
	mast_mesh.bottom_radius = 0.14
	mast_mesh.height = 6.8
	mast_mesh.radial_segments = 8
	mast.mesh = mast_mesh
	mast.position = antenna_position + Vector3(0.0, 3.4, 0.0)
	mast.material_override = SURFACE_FACTORY.make_metal_material(Color(0.42, 0.42, 0.4), 9021, Vector3(4.0, 4.0, 4.0), 0.42, 0.5)
	add_child(mast)

	for offset in [1.6, 3.2, 4.8]:
		var cross := MeshInstance3D.new()
		var cross_mesh := BoxMesh.new()
		cross_mesh.size = Vector3(1.8, 0.08, 0.08)
		cross.mesh = cross_mesh
		cross.position = antenna_position + Vector3(0.0, offset, 0.0)
		cross.material_override = mast.material_override
		add_child(cross)
