extends Node3D

## Raiz do jogo: mapeia os controles, carrega a missao e conduz o fluxo
## briefing -> voo -> debriefing. O mundo em si e montado pelo MissionWorld a
## partir dos dados da missao, entao este arquivo nao conhece o mapa.

enum Phase {
	TITLE,
	BRIEFING,
	FLYING,
	DEBRIEFING,
}

var phase: int = Phase.TITLE

var _world: MissionWorld
var _hud: Hud
var _title: TitleScreen
var _briefing: BriefingScreen
var _debriefing: DebriefingScreen
var _player: PlayerHelicopter
var _mission_index := 0
var _mission_path := ""


func _ready() -> void:
	Engine.max_fps = 0
	Engine.time_scale = 1.0

	UiTheme.install(get_tree())
	_ensure_runtime_input_map()

	if not GameState.has_campaign():
		push_error("Campaign nao carregada. Encerrando.")
		return

	_mission_index = GameState.current_mission_index
	_mission_path = GameState.get_current_mission_path()

	if not MissionManager.load_mission(_mission_path):
		push_error("Nao foi possivel carregar a missao. Encerrando.")
		return

	MissionManager.mission_completed.connect(_on_mission_completed)
	MissionManager.mission_failed.connect(_on_mission_failed)
	MissionManager.mission_message.connect(_on_mission_message)

	## O titulo aparece uma vez por execucao. No restart por F5 ou no avanco de
	## campanha a cena recarrega, e cair de novo no menu quebraria o ritmo.
	if GameState.title_shown:
		_show_briefing()
	else:
		_show_title()


func _show_title() -> void:
	phase = Phase.TITLE

	_title = TitleScreen.new()
	_title.name = "TitleScreen"
	_title.mission_chosen.connect(_on_mission_chosen)
	add_child(_title)


func _on_mission_chosen(index: int) -> void:
	GameState.title_shown = true

	if _title != null:
		_title.queue_free()
		_title = null

	## Escolher outra missao troca o arquivo carregado antes do briefing.
	if index != _mission_index:
		GameState.set_current_mission_index(index)
		_restart()
		return

	_show_briefing()


func _process(_delta: float) -> void:
	if phase == Phase.FLYING:
		_update_waypoint()
		_refresh_objectives()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_restart"):
		_restart()


## ---------------------------------------------------------------- fluxo

func _show_briefing() -> void:
	phase = Phase.BRIEFING

	_briefing = BriefingScreen.new()
	_briefing.name = "BriefingScreen"
	_briefing.dismissed.connect(_on_briefing_dismissed)
	add_child(_briefing)


## Pula titulo e briefing e entra direto no voo. Usado pelas ferramentas de
## teste e de captura, que precisam do mundo montado sem interacao.
func skip_briefing() -> void:
	if phase == Phase.TITLE:
		GameState.title_shown = true
		if _title != null:
			_title.queue_free()
			_title = null
		_show_briefing()

	if phase != Phase.BRIEFING:
		return
	_on_briefing_dismissed()


## So dispensa o titulo, parando no briefing. Usado pela captura de tela.
func skip_title() -> void:
	if phase != Phase.TITLE:
		return
	GameState.title_shown = true
	if _title != null:
		_title.queue_free()
		_title = null
	_show_briefing()


func _on_briefing_dismissed() -> void:
	if _briefing != null:
		_briefing.queue_free()
		_briefing = null

	_start_flight()


func _start_flight() -> void:
	phase = Phase.FLYING
	GameState.reset_score()

	_world = MissionWorld.new()
	_world.name = "MissionWorld"
	add_child(_world)
	_world.build(MissionManager.get_world_data())

	_player = _world.player
	_player.destroyed.connect(_on_player_destroyed)

	_hud = Hud.new()
	_hud.name = "Hud"
	add_child(_hud)
	_hud.setup(_player)
	_hud.connect_base(_world.base)

	_world.base.passengers_delivered.connect(MissionManager.notify_rescued_delivered)
	MissionManager.objective_completed.connect(_on_objective_completed)

	AudioManager.attach_to_player(_player)
	AudioManager.start_music()

	MissionManager.start()
	_refresh_objectives()


func _on_player_destroyed(_reason: String) -> void:
	MissionManager.notify_player_lost()


func _on_objective_completed(objective_id: String) -> void:
	if _hud == null:
		return

	AudioManager.play_ui(AudioManager.Sfx.OBJECTIVE, -5.0)

	for objective in MissionManager.objectives:
		if objective["id"] == objective_id:
			_hud.show_message("OBJETIVO CONCLUIDO: %s" % objective["label"].to_upper(), 3.0, Hud.COLOR_GREEN)
			return


func _on_mission_message(text: String, color: Color) -> void:
	if _hud != null:
		_hud.show_message(text, 3.2, color)


func _on_mission_completed(stats: Dictionary) -> void:
	var progress := GameState.complete_mission(_mission_index, stats)
	_show_debriefing(
		stats,
		true,
		"",
		bool(progress.get("has_next", false)),
		str(progress.get("next_title", ""))
	)


func _on_mission_failed(reason: String) -> void:
	_show_debriefing(MissionManager.build_stats(), false, reason, false, "")


func _show_debriefing(stats: Dictionary, success: bool, reason: String, allow_continue: bool, next_title: String) -> void:
	if phase == Phase.DEBRIEFING:
		return

	phase = Phase.DEBRIEFING

	if _hud != null:
		_hud.visible = false

	AudioManager.stop_music()

	_debriefing = DebriefingScreen.new()
	_debriefing.name = "DebriefingScreen"
	add_child(_debriefing)
	_debriefing.setup(stats, success, reason, allow_continue, next_title)
	_debriefing.restart_requested.connect(_restart)
	_debriefing.continue_requested.connect(_continue_campaign)


func _restart() -> void:
	MissionManager.stop()
	GameState.set_current_mission_index(_mission_index)
	GameState.reset_score()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _continue_campaign() -> void:
	MissionManager.stop()
	GameState.reset_score()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


## ---------------------------------------------------------------- HUD

func _refresh_objectives() -> void:
	if _hud == null:
		return

	var lines: Array[String] = []
	for objective in MissionManager.get_visible_objectives():
		var mark := "x" if objective["done"] else " "
		var suffix := ""
		if objective["type"] == "rescue":
			suffix = "  %d/%d" % [objective["progress"], objective["target_count"]]
		elif objective["type"] == "destroy":
			var total: int = objective["pending"].size()
			if total > 0:
				suffix = "  faltam %d" % total
		lines.append("[%s] %s%s" % [mark, objective["label"], suffix])

	_hud.set_objectives(lines)


## Aponta para o proximo passo real da missao, nao apenas para o inimigo mais perto.
func _update_waypoint() -> void:
	if _hud == null or _player == null or not is_instance_valid(_player):
		return

	var carrying: bool = _player.winch != null and _player.winch.has_passengers()
	var full: bool = _player.winch != null and _player.winch.passengers >= _player.winch.tuning.passenger_capacity

	for objective in MissionManager.get_visible_objectives():
		if objective["done"]:
			continue

		match objective["type"]:
			"destroy":
				var structure := _find_structure(objective["pending"])
				if structure != null:
					_hud.set_waypoint(structure.global_position, objective["label"])
					return

			"rescue":
				var pows := get_tree().get_nodes_in_group("pow")
				if full or (pows.is_empty() and carrying):
					_hud.set_waypoint(_world.base.global_position, "entregar resgatados na base")
					return
				if not pows.is_empty():
					var nearest := _nearest(pows)
					if nearest != null:
						_hud.set_waypoint(nearest.global_position, objective["label"])
						return

			"collect":
				var item := _find_pickup(objective["pending"])
				if item != null:
					_hud.set_waypoint(item.global_position, objective["label"])
					return

	if carrying:
		_hud.set_waypoint(_world.base.global_position, "entregar resgatados na base")
		return

	_hud.set_waypoint(_world.base.global_position, "voltar para a base")


func _find_structure(pending: Array) -> Node3D:
	for node in get_tree().get_nodes_in_group("structure"):
		var structure := node as Structure
		if structure == null or not structure.is_alive():
			continue
		if pending.has(structure.structure_id):
			return structure
	return null


func _find_pickup(pending: Array) -> Node3D:
	for node in get_tree().get_nodes_in_group("pickup"):
		var pickup := node as Pickup
		if pickup != null and pending.has(pickup.item_id):
			return pickup
	return null


func _nearest(nodes: Array) -> Node3D:
	var best: Node3D = null
	var best_distance := INF

	for node in nodes:
		var candidate := node as Node3D
		if candidate == null or not is_instance_valid(candidate):
			continue
		var distance := candidate.global_position.distance_to(_player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate

	return best


## ---------------------------------------------------------------- input

func _ensure_runtime_input_map() -> void:
	_register_action("move_forward", [
		_make_key_event(KEY_W),
		_make_key_event(KEY_UP),
		_make_joy_axis_event(JOY_AXIS_LEFT_Y, -1.0)
	])
	_register_action("move_back", [
		_make_key_event(KEY_S),
		_make_key_event(KEY_DOWN),
		_make_joy_axis_event(JOY_AXIS_LEFT_Y, 1.0)
	])
	_register_action("move_left", [
		_make_key_event(KEY_A),
		_make_key_event(KEY_LEFT),
		_make_joy_axis_event(JOY_AXIS_LEFT_X, -1.0)
	])
	_register_action("move_right", [
		_make_key_event(KEY_D),
		_make_key_event(KEY_RIGHT),
		_make_joy_axis_event(JOY_AXIS_LEFT_X, 1.0)
	])
	_register_action("turn_left", [
		_make_key_event(KEY_Q),
		_make_joy_axis_event(JOY_AXIS_RIGHT_X, -1.0)
	])
	_register_action("turn_right", [
		_make_key_event(KEY_E),
		_make_joy_axis_event(JOY_AXIS_RIGHT_X, 1.0)
	])
	_register_action("fire_primary", [
		_make_key_event(KEY_SPACE),
		_make_mouse_event(MOUSE_BUTTON_LEFT),
		_make_joy_axis_event(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	])
	_register_action("fire_secondary", [
		_make_key_event(KEY_F),
		_make_mouse_event(MOUSE_BUTTON_RIGHT),
		_make_joy_axis_event(JOY_AXIS_TRIGGER_LEFT, 1.0)
	])
	_register_action("fire_special", [
		_make_key_event(KEY_R),
		_make_mouse_event(MOUSE_BUTTON_MIDDLE),
		_make_joy_button_event(JOY_BUTTON_Y)
	])
	_register_action("winch", [
		_make_key_event(KEY_G),
		_make_joy_button_event(JOY_BUTTON_A)
	])
	_register_action("debug_restart", [
		_make_key_event(KEY_F5)
	])


func _register_action(action_name: String, events: Array) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	InputMap.add_action(action_name, 0.2)

	for event in events:
		InputMap.action_add_event(action_name, event)


func _make_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _make_joy_axis_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


func _make_joy_button_event(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _make_mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
