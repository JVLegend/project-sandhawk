class_name TitleScreen
extends CanvasLayer

## Tela de titulo com selecao de missao. E a porta de entrada do jogo: antes
## dela o boot caia direto no briefing, o que funcionava para testar mas nao
## apresentava o jogo nem deixava rejogar missao antiga da campanha.
##
## A lista vem do GameState: missoes destravadas sao selecionaveis e mostram o
## melhor score/tempo salvos; as demais aparecem bloqueadas.

signal mission_chosen(index: int)

const COLOR_BG := Color(0.045, 0.05, 0.055, 1.0)
const COLOR_TEXT := Color(0.86, 0.88, 0.9)
const COLOR_DIM := Color(0.5, 0.53, 0.56)
const COLOR_AMBER := Color(0.96, 0.74, 0.28)
const COLOR_CYAN := Color(0.42, 0.82, 0.94)
const COLOR_LOCKED := Color(0.36, 0.38, 0.4)

var _selected := 0
var _rows: Array[PanelContainer] = []
var _prompt: Label
var _blink := 0.0
var _stripe_time := 0.0
var _stripes: Control


## Fundo decorativo: faixas diagonais lentas, como areia varrida pelo vento.
class StripeBackdrop extends Control:
	var time := 0.0

	func _draw() -> void:
		var spacing := 90.0
		var offset := fmod(time * 12.0, spacing)
		for index in range(-4, int(size.x / spacing) + 6):
			var x := float(index) * spacing + offset
			var points := PackedVector2Array([
				Vector2(x, 0.0),
				Vector2(x + 34.0, 0.0),
				Vector2(x - size.y * 0.35 + 34.0, size.y),
				Vector2(x - size.y * 0.35, size.y),
			])
			draw_colored_polygon(points, Color(1.0, 0.92, 0.75, 0.018))


func _ready() -> void:
	layer = 10
	_build()
	_refresh_rows()


func _process(delta: float) -> void:
	_blink += delta
	if _prompt != null:
		_prompt.modulate.a = 0.45 + 0.55 * absf(sin(_blink * 2.6))

	if _stripes != null:
		_stripe_time += delta
		(_stripes as StripeBackdrop).time = _stripe_time
		_stripes.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_move_selection(1)
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_move_selection(-1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui_click()
		mission_chosen.emit(_selected)


func _move_selection(direction: int) -> void:
	var unlocked := GameState.unlocked_mission_count
	var target := clampi(_selected + direction, 0, unlocked - 1)
	if target == _selected:
		return

	_selected = target
	AudioManager.play_ui_click()
	_refresh_rows()


func _refresh_rows() -> void:
	for index in _rows.size():
		var row := _rows[index]
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue

		if index == _selected:
			style.bg_color = Color(0.14, 0.16, 0.17, 0.95)
			style.border_color = COLOR_AMBER
		else:
			style.bg_color = Color(0.07, 0.08, 0.09, 0.7)
			style.border_color = Color(0.3, 0.33, 0.36, 0.4)


func _build() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(background)
	add_child(background)

	_stripes = StripeBackdrop.new()
	_stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(_stripes)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)

	## Cabecalho: identidade do jogo.
	var eyebrow := _make_label("OPERACOES AEREAS NO DESERTO", 13, COLOR_DIM)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(eyebrow)

	var title := _make_label("PROJECT SANDHAWK", 52, COLOR_AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_bold(title)
	column.add_child(title)

	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(560.0, 14.0)
	column.add_child(rule)

	var caption := _make_label("SELECIONE A OPERACAO", 12, COLOR_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)

	_selected = clampi(GameState.current_mission_index, 0, maxi(0, GameState.unlocked_mission_count - 1))

	for index in GameState.get_mission_count():
		column.add_child(_build_mission_row(index))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	column.add_child(spacer)

	_prompt = _make_label("ENTER PARA INICIAR", 16, COLOR_CYAN)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_prompt)

	var controls := _make_label(
		"W A S D voar · Q E girar · ESPACO/F/R armas · G guincho\nanalogicos + gatilhos no controle · A guincho · Y misseis",
		11,
		COLOR_DIM
	)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(controls)


func _build_mission_row(index: int) -> PanelContainer:
	var unlocked := index < GameState.unlocked_mission_count
	var mission_id := str(GameState.campaign[index].get("id", ""))

	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.09, 0.7)
	style.border_width_left = 3
	style.border_color = Color(0.3, 0.33, 0.36, 0.4)
	style.content_margin_left = 16.0
	style.content_margin_right = 18.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	row.add_theme_stylebox_override("panel", style)
	row.custom_minimum_size = Vector2(560.0, 0.0)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)

	var number := _make_label("%02d" % (index + 1), 18, COLOR_AMBER if unlocked else COLOR_LOCKED)
	UiTheme.apply_bold(number)
	line.add_child(number)

	var name_label := _make_label(
		GameState.get_mission_title(index).to_upper(),
		15,
		COLOR_TEXT if unlocked else COLOR_LOCKED
	)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)

	if not unlocked:
		line.add_child(_make_label("BLOQUEADA", 12, COLOR_LOCKED))
	else:
		var best_score := int(GameState.best_scores.get(mission_id, 0))
		var best_time := float(GameState.best_times.get(mission_id, 0.0))
		if best_score > 0:
			var minutes := int(best_time) / 60
			var seconds := int(best_time) % 60
			line.add_child(_make_label("RECORDE %d · %d:%02d" % [best_score, minutes, seconds], 12, COLOR_CYAN))
		else:
			line.add_child(_make_label("SEM REGISTRO", 12, COLOR_DIM))

	_rows.append(row)
	return row


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
