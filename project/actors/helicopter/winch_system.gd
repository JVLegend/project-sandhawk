class_name WinchSystem
extends Node3D

## Guincho de resgate: o momento icone do jogo. Descer o cabo prende o helicoptero
## no lugar por 4 segundos, o que o transforma em alvo facil. Toda a tensao vem dai.

signal state_changed(state: int)
signal passengers_changed(count: int, capacity: int)
signal rescue_started(pow_node: Node3D)
signal rescue_completed(pow_node: Node3D)
signal rescue_cancelled(reason: String)

enum State {
	IDLE,
	DESCENDING,
	LIFTING,
	ASCENDING,
}

var tuning: ResourceTuning
var state: int = State.IDLE
var passengers: int = 0

var _carrier: Node3D
var _target: Node3D
var _progress := 0.0
var _cable: MeshInstance3D
var _hook: MeshInstance3D


func setup(p_tuning: ResourceTuning, carrier: Node3D) -> void:
	tuning = p_tuning
	_carrier = carrier
	_build_cable()
	passengers_changed.emit(passengers, tuning.passenger_capacity)


func is_busy() -> bool:
	return state != State.IDLE


func has_passengers() -> bool:
	return passengers > 0


func deliver_all() -> int:
	var delivered := passengers
	passengers = 0
	if tuning != null:
		passengers_changed.emit(passengers, tuning.passenger_capacity)
	return delivered


## Alvo de resgate mais proximo dentro do raio, ainda nao resgatado.
func candidate_in_range() -> Node3D:
	if _carrier == null or tuning == null:
		return null

	var best: Node3D = null
	var best_distance := tuning.rescue_radius

	for node in get_tree().get_nodes_in_group("pow"):
		if not is_instance_valid(node):
			continue
		var candidate := node as Node3D
		if candidate == null or (candidate.has_method("is_available") and not candidate.is_available()):
			continue

		var offset := candidate.global_position - _carrier.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < best_distance:
			best_distance = distance
			best = candidate

	return best


func _process(delta: float) -> void:
	if tuning == null or _carrier == null:
		return

	match state:
		State.IDLE:
			_tick_idle()
		State.DESCENDING:
			_tick_descending(delta)
		State.LIFTING:
			_tick_lifting(delta)
		State.ASCENDING:
			_tick_ascending(delta)

	_update_cable_visual()


func _tick_idle() -> void:
	if not Input.is_action_pressed("winch"):
		return
	if passengers >= tuning.passenger_capacity:
		rescue_cancelled.emit("lotado")
		return
	if not _carrier_is_stable():
		return

	var candidate := candidate_in_range()
	if candidate == null:
		return

	_target = candidate
	if _target.has_method("begin_rescue"):
		_target.begin_rescue()

	_progress = 0.0
	_set_state(State.DESCENDING)
	rescue_started.emit(_target)


func _tick_descending(delta: float) -> void:
	if not _abort_if_invalid():
		return

	_progress += delta / maxf(0.01, tuning.winch_descend_seconds)
	if _progress >= 1.0:
		_progress = 0.0
		_set_state(State.LIFTING)


func _tick_lifting(_delta: float) -> void:
	if not _abort_if_invalid():
		return

	_progress = 0.0
	_set_state(State.ASCENDING)


func _tick_ascending(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_set_state(State.IDLE)
		return

	_progress += delta / maxf(0.01, tuning.winch_ascend_seconds)

	## Durante a subida o resgatado acompanha o cabo.
	var ground_y: float = _target.global_position.y
	var lifted := lerpf(ground_y, _carrier.global_position.y - 1.0, clampf(_progress, 0.0, 1.0))
	_target.global_position = Vector3(_carrier.global_position.x, lifted, _carrier.global_position.z)

	if _progress < 1.0:
		return

	passengers += 1
	passengers_changed.emit(passengers, tuning.passenger_capacity)
	GameState.add_score(tuning.rescue_score)

	var rescued := _target
	if rescued.has_method("complete_rescue"):
		rescued.complete_rescue()
	rescue_completed.emit(rescued)

	_target = null
	_set_state(State.IDLE)


## Cancela se o jogador se afastou, acelerou ou o alvo sumiu.
func _abort_if_invalid() -> bool:
	if _target == null or not is_instance_valid(_target):
		_cancel("alvo perdido")
		return false

	if not Input.is_action_pressed("winch"):
		_cancel("botao solto")
		return false

	if not _carrier_is_stable():
		_cancel("helicoptero instavel")
		return false

	var offset := _target.global_position - _carrier.global_position
	offset.y = 0.0
	if offset.length() > tuning.rescue_radius * 1.4:
		_cancel("fora de alcance")
		return false

	return true


func _cancel(reason: String) -> void:
	if _target != null and is_instance_valid(_target) and _target.has_method("cancel_rescue"):
		_target.cancel_rescue()

	_target = null
	_progress = 0.0
	_set_state(State.IDLE)
	rescue_cancelled.emit(reason)


func _carrier_is_stable() -> bool:
	if not _carrier.has_method("get_planar_speed"):
		return true
	return _carrier.get_planar_speed() <= tuning.winch_max_speed


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _update_cable_visual() -> void:
	if _cable == null or _carrier == null:
		return

	var active := state != State.IDLE
	_cable.visible = active
	_hook.visible = active
	if not active:
		return

	var drop := _carrier.global_position.y - 0.6
	if state == State.DESCENDING:
		drop = _carrier.global_position.y * clampf(_progress, 0.0, 1.0)
	elif state == State.ASCENDING:
		drop = _carrier.global_position.y * (1.0 - clampf(_progress, 0.0, 1.0))

	drop = maxf(0.2, drop)

	var cylinder := _cable.mesh as CylinderMesh
	cylinder.height = drop
	_cable.position = Vector3(0.0, -drop * 0.5, 0.0)
	_hook.position = Vector3(0.0, -drop, 0.0)


func _build_cable() -> void:
	_cable = MeshInstance3D.new()
	_cable.name = "Cable"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.045
	cylinder.bottom_radius = 0.045
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	_cable.mesh = cylinder

	var cable_material := StandardMaterial3D.new()
	cable_material.albedo_color = Color(0.14, 0.14, 0.15)
	cable_material.roughness = 0.8
	_cable.material_override = cable_material
	add_child(_cable)

	_hook = MeshInstance3D.new()
	_hook.name = "Hook"
	var hook_mesh := BoxMesh.new()
	hook_mesh.size = Vector3(0.34, 0.28, 0.34)
	_hook.mesh = hook_mesh

	var hook_material := StandardMaterial3D.new()
	hook_material.albedo_color = Color(0.62, 0.64, 0.66)
	hook_material.metallic = 0.6
	hook_material.roughness = 0.4
	_hook.material_override = hook_material
	add_child(_hook)

	_cable.visible = false
	_hook.visible = false
