class_name DebriefingScreen
extends CanvasLayer

## Tela de debriefing: resultado, tempo contra o par, resgatados e pontuacao.
## Existe para o jogador querer um segundo run, entao mostra o que deu para melhorar.

signal restart_requested
signal continue_requested

const COLOR_BG := Color(0.05, 0.055, 0.06, 0.97)
const COLOR_TEXT := Color(0.86, 0.88, 0.9)
const COLOR_DIM := Color(0.55, 0.58, 0.6)
const COLOR_AMBER := Color(0.96, 0.74, 0.28)
const COLOR_GREEN := Color(0.45, 0.9, 0.55)
const COLOR_RED := Color(0.94, 0.36, 0.3)
const COLOR_CYAN := Color(0.42, 0.82, 0.94)

var _blink_time := 0.0
var _prompt: Label
var _secondary_prompt: Label
var _allow_continue := false
var _success := false


func setup(
	stats: Dictionary,
	success: bool,
	failure_reason: String = "",
	allow_continue: bool = false,
	next_title: String = ""
) -> void:
	layer = 10
	_allow_continue = allow_continue
	_success = success
	_build(stats, success, failure_reason, next_title)


func _process(delta: float) -> void:
	_blink_time += delta
	if _prompt != null:
		_prompt.modulate.a = 0.45 + 0.55 * absf(sin(_blink_time * 2.6))


func _unhandled_input(event: InputEvent) -> void:
	if _allow_continue and _success and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui_click()
		continue_requested.emit()
		return

	if event.is_action_pressed("debug_restart") or ((event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")) and not _allow_continue):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui_click()
		restart_requested.emit()


func _build(stats: Dictionary, success: bool, failure_reason: String, next_title: String) -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(background)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	center.add_child(box)

	box.add_child(_make_label("DEBRIEFING", 12, COLOR_DIM))
	box.add_child(_make_label(
		"MISSAO CUMPRIDA" if success else "MISSAO FRACASSADA",
		30,
		COLOR_GREEN if success else COLOR_RED
	))
	box.add_child(_make_label(str(stats.get("title", "")).to_upper(), 14, COLOR_AMBER))

	if not success and not failure_reason.is_empty():
		box.add_child(_make_label("Motivo: %s" % failure_reason, 13, COLOR_DIM))

	var separator := HSeparator.new()
	separator.custom_minimum_size = Vector2(420.0, 12.0)
	box.add_child(separator)

	var elapsed := float(stats.get("time", 0.0))
	var par := float(stats.get("par_time", 600.0))
	var time_color := COLOR_GREEN if elapsed <= par else COLOR_AMBER

	box.add_child(_make_row("TEMPO", "%s  (par %s)" % [_format_time(elapsed), _format_time(par)], time_color))
	box.add_child(_make_row("PONTOS", str(stats.get("score", 0)), COLOR_TEXT))
	box.add_child(_make_row("RESGATADOS ENTREGUES", str(stats.get("rescued", 0)), COLOR_TEXT))
	box.add_child(_make_row(
		"OBJETIVOS PRINCIPAIS",
		"%d / %d" % [stats.get("required_done", 0), stats.get("required_total", 0)],
		COLOR_TEXT
	))
	box.add_child(_make_row(
		"OBJETIVOS OPCIONAIS",
		"%d / %d" % [stats.get("optional_done", 0), stats.get("optional_total", 0)],
		COLOR_DIM
	))
	box.add_child(_make_row(
		"HELICOPTEROS PERDIDOS",
		str(stats.get("losses", 0)),
		COLOR_RED if int(stats.get("losses", 0)) > 0 else COLOR_TEXT
	))
	box.add_child(_make_row(
		"ALVOS CIVIS ATINGIDOS",
		str(stats.get("civilian_hits", 0)),
		COLOR_RED if int(stats.get("civilian_hits", 0)) > 0 else COLOR_TEXT
	))

	var separator_two := HSeparator.new()
	separator_two.custom_minimum_size = Vector2(420.0, 12.0)
	box.add_child(separator_two)

	if _allow_continue and success:
		_prompt = _make_label("ENTER PARA AVANCAR: %s" % next_title.to_upper(), 16, COLOR_CYAN)
		_secondary_prompt = _make_label("F5 PARA REVOAR ESTA MISSAO", 13, COLOR_DIM)
		_secondary_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_prompt)
		box.add_child(_secondary_prompt)
		return

	_prompt = _make_label("ENTER PARA VOAR DE NOVO", 16, COLOR_CYAN)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prompt)


func _make_row(label_text: String, value_text: String, value_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var label := _make_label(label_text, 13, COLOR_DIM)
	label.custom_minimum_size = Vector2(250.0, 0.0)
	row.add_child(label)

	var value := _make_label(value_text, 14, value_color)
	row.add_child(value)

	return row


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
