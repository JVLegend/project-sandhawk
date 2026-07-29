class_name Hud
extends CanvasLayer

## HUD de combate e recursos. Leitura antes de beleza: o jogador precisa saber
## em um olhar quanto tem de combustivel, blindagem, municao e quantos resgatados
## estao a bordo, alem de para onde ir.

const WEAPON_KEYS := ["ESPACO", "F", "R"]
const EDGE_MARGIN := 64.0

const COLOR_TEXT := Color(0.88, 0.91, 0.94)
const COLOR_DIM := Color(0.58, 0.62, 0.66)
const COLOR_AMBER := Color(0.96, 0.74, 0.28)
const COLOR_GREEN := Color(0.42, 0.86, 0.52)
const COLOR_RED := Color(0.94, 0.34, 0.29)
const COLOR_CYAN := Color(0.42, 0.82, 0.94)

var _player: PlayerHelicopter

var _root: Control
var _fuel_bar: ProgressBar
var _fuel_label: Label
var _armor_bar: ProgressBar
var _armor_label: Label
var _weapon_labels: Array[Label] = []
var _passenger_pips: Array[Panel] = []
var _score_label: Label
var _objective_label: Label
var _objectives_box: VBoxContainer
var _objective_lines: Array[String] = []
var _message_label: Label
var _waypoint_marker: Control
var _waypoint_arrow: Label
var _waypoint_distance: Label

var _waypoint_position := Vector3.ZERO
var _waypoint_active := false
var _message_timer := 0.0
var _blink_time := 0.0
var _fuel_alarm := false


func setup(player: PlayerHelicopter) -> void:
	_player = player
	_build_ui()

	if _player == null:
		return

	_player.armor_changed.connect(_on_armor_changed)
	_player.destroyed.connect(_on_destroyed)

	if _player.fuel != null:
		_player.fuel.fuel_changed.connect(_on_fuel_changed)
		_player.fuel.warning_entered.connect(func() -> void:
			show_message("COMBUSTIVEL BAIXO", 2.5, COLOR_AMBER)
			AudioManager.play_ui(AudioManager.Sfx.ALARM, -8.0)
		)
		_player.fuel.critical_entered.connect(func() -> void:
			show_message("COMBUSTIVEL CRITICO", 3.0, COLOR_RED)
			AudioManager.play_ui(AudioManager.Sfx.ALARM, -3.0)
		)
		_on_fuel_changed(_player.fuel.fuel, _player.fuel.tuning.fuel_max)

	if _player.weapons != null:
		_player.weapons.ammo_changed.connect(_on_ammo_changed)
		for slot in _player.weapons.runtimes.size():
			var runtime := _player.weapons.get_runtime(slot)
			_on_ammo_changed(slot, runtime.ammo, runtime.definition.max_ammo)

	if _player.winch != null:
		_player.winch.passengers_changed.connect(_on_passengers_changed)
		_player.winch.rescue_completed.connect(func(_p: Node3D) -> void:
			show_message("RESGATADO A BORDO", 2.0, COLOR_GREEN)
			AudioManager.play_ui(AudioManager.Sfx.RESCUE, -6.0)
		)
		_player.winch.rescue_cancelled.connect(_on_rescue_cancelled)
		_on_passengers_changed(0, _player.winch.tuning.passenger_capacity)

	if _player.health != null:
		_on_armor_changed(_player.health.hp, _player.health.max_hp)

	GameState.score_changed.connect(_on_score_changed)
	_on_score_changed(GameState.score)


func connect_base(base: FriendlyBase) -> void:
	base.service_started.connect(func() -> void: show_message("REABASTECENDO", 2.0, COLOR_CYAN))
	base.service_finished.connect(func() -> void: show_message("PRONTO PARA DECOLAR", 2.0, COLOR_GREEN))
	base.passengers_delivered.connect(func(count: int) -> void:
		show_message("%d RESGATADO(S) ENTREGUE(S)" % count, 2.5, COLOR_GREEN)
	)


func set_waypoint(target_position: Vector3, label: String) -> void:
	_waypoint_position = target_position
	_waypoint_active = true
	if _objective_label != null:
		_objective_label.text = label.to_upper()


func clear_waypoint() -> void:
	_waypoint_active = false
	if _waypoint_marker != null:
		_waypoint_marker.visible = false


func set_objective_text(text: String) -> void:
	if _objective_label != null:
		_objective_label.text = text.to_upper()


func show_message(text: String, duration: float = 2.0, color: Color = COLOR_TEXT) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.modulate.a = 1.0
	_message_timer = duration


func _process(delta: float) -> void:
	_blink_time += delta
	_tick_message(delta)
	_tick_fuel_alarm()
	_update_waypoint()


func _tick_message(delta: float) -> void:
	if _message_timer <= 0.0:
		return

	_message_timer -= delta
	if _message_timer <= 0.0:
		_message_label.text = ""
		return

	if _message_timer < 0.6:
		_message_label.modulate.a = _message_timer / 0.6


func _tick_fuel_alarm() -> void:
	if not _fuel_alarm or _fuel_bar == null:
		return
	_fuel_bar.modulate.a = 0.45 + 0.55 * absf(sin(_blink_time * 6.0))


func _update_waypoint() -> void:
	if _waypoint_marker == null:
		return
	if not _waypoint_active or _player == null or not is_instance_valid(_player):
		_waypoint_marker.visible = false
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_waypoint_marker.visible = false
		return

	_waypoint_marker.visible = true

	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var projected := camera.unproject_position(_waypoint_position)
	var offset := projected - center
	if camera.is_position_behind(_waypoint_position):
		offset = -offset

	var bounds := viewport_size * 0.5 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var on_screen := absf(offset.x) < bounds.x and absf(offset.y) < bounds.y and not camera.is_position_behind(_waypoint_position)

	if not on_screen and offset.length() > 0.001:
		var scale_x := bounds.x / maxf(0.001, absf(offset.x))
		var scale_y := bounds.y / maxf(0.001, absf(offset.y))
		offset *= minf(scale_x, scale_y)

	_waypoint_marker.position = center + offset
	_waypoint_arrow.visible = not on_screen
	_waypoint_arrow.rotation = offset.angle() + PI * 0.5

	var distance := _player.global_position.distance_to(_waypoint_position)
	_waypoint_distance.text = "%dm" % int(distance)


func _on_fuel_changed(current: float, maximum: float) -> void:
	if _fuel_bar == null:
		return

	_fuel_bar.max_value = maximum
	_fuel_bar.value = current
	_fuel_label.text = "COMBUSTIVEL  %d%%" % int(round(current / maxf(1.0, maximum) * 100.0))

	var ratio := current / maxf(1.0, maximum)
	var color := COLOR_AMBER
	_fuel_alarm = false

	if ratio <= 0.1:
		color = COLOR_RED
		_fuel_alarm = true
	elif ratio <= 0.25:
		color = COLOR_RED.lerp(COLOR_AMBER, 0.4)
		_fuel_alarm = true

	if not _fuel_alarm:
		_fuel_bar.modulate.a = 1.0

	_apply_bar_color(_fuel_bar, color)
	_fuel_label.add_theme_color_override("font_color", color if _fuel_alarm else COLOR_TEXT)


func _on_armor_changed(current: int, maximum: int) -> void:
	if _armor_bar == null:
		return

	_armor_bar.max_value = maximum
	_armor_bar.value = current
	_armor_label.text = "BLINDAGEM  %d" % current

	var ratio := float(current) / maxf(1.0, float(maximum))
	var color := COLOR_GREEN
	if ratio < 0.25:
		color = COLOR_RED
	elif ratio < 0.55:
		color = COLOR_AMBER

	_apply_bar_color(_armor_bar, color)


func _on_ammo_changed(slot: int, ammo: int, max_ammo: int) -> void:
	if slot < 0 or slot >= _weapon_labels.size() or _player == null:
		return

	var runtime := _player.weapons.get_runtime(slot)
	if runtime == null:
		return

	var label := _weapon_labels[slot]
	label.text = "%-10s %5d" % [runtime.definition.display_name.to_upper(), ammo]

	var ratio := float(ammo) / maxf(1.0, float(max_ammo))
	var color := COLOR_TEXT
	if ammo == 0:
		color = COLOR_RED
	elif ratio < 0.2:
		color = COLOR_AMBER
	label.add_theme_color_override("font_color", color)


func _on_passengers_changed(count: int, capacity: int) -> void:
	for index in _passenger_pips.size():
		var pip := _passenger_pips[index]
		pip.visible = index < capacity
		var style := pip.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.bg_color = COLOR_GREEN if index < count else Color(0.2, 0.22, 0.24, 0.8)


func _on_score_changed(score: int) -> void:
	if _score_label != null:
		_score_label.text = "PONTOS  %d" % score


func _on_rescue_cancelled(reason: String) -> void:
	if reason == "botao solto" or reason == "alvo perdido":
		return
	show_message("RESGATE ABORTADO: %s" % reason.to_upper(), 1.8, COLOR_AMBER)


func _on_destroyed(reason: String) -> void:
	var text := "HELICOPTERO ABATIDO"
	if reason == "combustivel":
		text = "SEM COMBUSTIVEL"
	show_message(text, 2.4, COLOR_RED)


func _apply_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 1
	fill.corner_radius_top_right = 1
	fill.corner_radius_bottom_left = 1
	fill.corner_radius_bottom_right = 1
	bar.add_theme_stylebox_override("fill", fill)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_resource_panel()
	_build_weapon_panel()
	_build_top_bar()
	_build_message_label()
	_build_waypoint_marker()


func _build_resource_panel() -> void:
	var panel := _make_panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20.0, -128.0)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	_fuel_label = _make_label("COMBUSTIVEL  100%")
	box.add_child(_fuel_label)
	_fuel_bar = _make_bar()
	box.add_child(_fuel_bar)

	_armor_label = _make_label("BLINDAGEM  600")
	box.add_child(_armor_label)
	_armor_bar = _make_bar()
	box.add_child(_armor_bar)

	var pip_row := HBoxContainer.new()
	pip_row.add_theme_constant_override("separation", 5)
	box.add_child(pip_row)

	var pip_caption := _make_label("RESGATADOS", 11, COLOR_DIM)
	pip_row.add_child(pip_caption)

	for _index in 6:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14.0, 14.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.22, 0.24, 0.8)
		style.corner_radius_top_left = 7
		style.corner_radius_top_right = 7
		style.corner_radius_bottom_left = 7
		style.corner_radius_bottom_right = 7
		pip.add_theme_stylebox_override("panel", style)
		pip_row.add_child(pip)
		_passenger_pips.append(pip)


func _build_weapon_panel() -> void:
	var panel := _make_panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.position = Vector2(-232.0, -104.0)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	for index in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)

		var key := _make_label("[%s]" % WEAPON_KEYS[index], 11, COLOR_DIM)
		key.custom_minimum_size = Vector2(58.0, 0.0)
		row.add_child(key)

		var label := _make_label("")
		row.add_child(label)
		_weapon_labels.append(label)

	box.add_child(_make_label("G  guincho de resgate", 11, COLOR_DIM))


func _build_top_bar() -> void:
	var panel := _make_panel()
	panel.position = Vector2(20.0, 18.0)
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	_objective_label = _make_label("EM ROTA", 14, COLOR_CYAN)
	box.add_child(_objective_label)

	_score_label = _make_label("PONTOS  0", 12, COLOR_DIM)
	box.add_child(_score_label)

	_objectives_box = VBoxContainer.new()
	_objectives_box.add_theme_constant_override("separation", 2)
	box.add_child(_objectives_box)


## Lista de objetivos da missao, ja formatada pelo raiz do jogo.
func set_objectives(lines: Array[String]) -> void:
	if _objectives_box == null or lines == _objective_lines:
		return

	_objective_lines = lines.duplicate()

	for child in _objectives_box.get_children():
		child.queue_free()

	for line in lines:
		var done := line.begins_with("[x]")
		_objectives_box.add_child(_make_label(line, 12, COLOR_DIM if done else COLOR_TEXT))


func _build_message_label() -> void:
	_message_label = _make_label("", 20, COLOR_TEXT)
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.position = Vector2(-260.0, 92.0)
	_message_label.custom_minimum_size = Vector2(520.0, 0.0)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_message_label)


func _build_waypoint_marker() -> void:
	_waypoint_marker = Control.new()
	_waypoint_marker.name = "Waypoint"
	_waypoint_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waypoint_marker.visible = false
	_root.add_child(_waypoint_marker)

	_waypoint_arrow = _make_label("▲", 22, COLOR_CYAN)
	_waypoint_arrow.position = Vector2(-11.0, -16.0)
	_waypoint_arrow.custom_minimum_size = Vector2(22.0, 0.0)
	_waypoint_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waypoint_arrow.pivot_offset = Vector2(11.0, 16.0)
	_waypoint_marker.add_child(_waypoint_arrow)

	_waypoint_distance = _make_label("", 12, COLOR_CYAN)
	_waypoint_distance.position = Vector2(-30.0, 14.0)
	_waypoint_distance.custom_minimum_size = Vector2(60.0, 0.0)
	_waypoint_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waypoint_marker.add_child(_waypoint_distance)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.66)
	style.border_color = Color(0.45, 0.5, 0.54, 0.5)
	style.border_width_left = 2
	style.content_margin_left = 12.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	panel.add_theme_stylebox_override("panel", style)

	return panel


func _make_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(216.0, 9.0)
	bar.show_percentage = false

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.11, 0.12, 0.13, 0.92)
	bar.add_theme_stylebox_override("background", background)

	return bar


func _make_label(text: String, font_size: int = 13, color: Color = COLOR_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
