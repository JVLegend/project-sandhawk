class_name BriefingScreen
extends CanvasLayer

## Tela de briefing: contexto, objetivos e mapa tatico desenhado em runtime.
## O mapa importa tanto quanto o texto: e o que faz o jogador sair sabendo o
## caminho, em vez de vagar pelo deserto.

signal dismissed

const COLOR_BG := Color(0.05, 0.055, 0.06, 0.97)
const COLOR_TEXT := Color(0.86, 0.88, 0.9)
const COLOR_DIM := Color(0.55, 0.58, 0.6)
const COLOR_AMBER := Color(0.96, 0.74, 0.28)
const COLOR_CYAN := Color(0.42, 0.82, 0.94)

var _blink_time := 0.0
var _prompt: Label


class TacticalMap extends Control:
	var world_data: Dictionary = {}
	var world_size := 900.0

	const ZONE_COLORS := {
		"village": Color(0.55, 0.78, 0.55),
		"outpost": Color(0.94, 0.42, 0.36),
		"camp": Color(0.42, 0.82, 0.94),
	}

	func _draw() -> void:
		var font := UiTheme.FONT_REGULAR
		var rect := Rect2(Vector2.ZERO, size)

		draw_rect(rect, Color(0.07, 0.09, 0.09, 0.9))
		draw_rect(rect, Color(0.35, 0.4, 0.42, 0.8), false, 2.0)

		for index in range(1, 8):
			var t := float(index) / 8.0
			draw_line(Vector2(size.x * t, 0.0), Vector2(size.x * t, size.y), Color(1, 1, 1, 0.05), 1.0)
			draw_line(Vector2(0.0, size.y * t), Vector2(size.x, size.y * t), Color(1, 1, 1, 0.05), 1.0)

		for zone in world_data.get("zones", []):
			var center := _project(zone.get("position", [0, 0]))
			var radius := float(zone.get("radius", 40.0)) / world_size * size.x
			var color: Color = ZONE_COLORS.get(str(zone.get("kind", "")), Color(0.8, 0.8, 0.8))

			draw_circle(center, maxf(radius, 6.0), Color(color.r, color.g, color.b, 0.16))
			draw_arc(center, maxf(radius, 6.0), 0.0, TAU, 32, color, 1.6)
			draw_string(
				font,
				center + Vector2(-85.0, radius + 15.0),
				str(zone.get("label", "")).to_upper(),
				HORIZONTAL_ALIGNMENT_CENTER,
				170.0,
				10,
				color
			)

		var base_point := _project(world_data.get("base", [0, 0]))
		draw_circle(base_point, 7.0, Color(0.42, 0.82, 0.94))
		draw_arc(base_point, 13.0, 0.0, TAU, 24, Color(0.42, 0.82, 0.94, 0.7), 1.6)
		draw_string(font, base_point + Vector2(-30.0, -19.0), "BASE", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 11, Color(0.42, 0.82, 0.94))

		for entry in world_data.get("pows", []):
			var point := _project(entry)
			draw_circle(point, 3.0, Color(0.45, 0.95, 0.55))

		for entry in world_data.get("structures", []):
			var point := _project(entry.get("position", [0, 0]))
			var half := 4.0
			draw_rect(Rect2(point - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), Color(0.96, 0.74, 0.28), false, 2.0)

	func _project(value) -> Vector2:
		var world_point := Vector2.ZERO
		if value is Array and value.size() >= 2:
			world_point = Vector2(float(value[0]), float(value[1]))

		var normalized := (world_point / world_size) + Vector2(0.5, 0.5)
		return Vector2(normalized.x * size.x, normalized.y * size.y)


func _ready() -> void:
	layer = 10
	_build()


func _process(delta: float) -> void:
	_blink_time += delta
	if _prompt != null:
		_prompt.modulate.a = 0.45 + 0.55 * absf(sin(_blink_time * 2.6))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui_click()
		dismissed.emit()


func _build() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(background)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	background.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)

	left.add_child(_make_label("OPERACAO", 12, COLOR_DIM))
	var title := _make_label(MissionManager.get_title().to_upper(), 26, COLOR_AMBER)
	UiTheme.apply_bold(title)
	left.add_child(title)
	left.add_child(_make_separator())

	for line in MissionManager.get_briefing_lines():
		var paragraph := _make_label(str(line), 14, COLOR_TEXT)
		paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paragraph.custom_minimum_size = Vector2(520.0, 0.0)
		left.add_child(paragraph)

	left.add_child(_make_separator())
	left.add_child(_make_label("OBJETIVOS", 12, COLOR_DIM))

	for objective in MissionManager.objectives:
		var prefix := "[ ]" if objective["required"] else "( )"
		var color := COLOR_TEXT if objective["required"] else COLOR_DIM
		var suffix := "" if objective["required"] else "  (opcional)"
		left.add_child(_make_label("%s  %s%s" % [prefix, objective["label"], suffix], 14, color))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)

	right.add_child(_make_label("MAPA TATICO", 12, COLOR_DIM))

	var map := TacticalMap.new()
	map.world_data = MissionManager.get_world_data()
	map.world_size = float(map.world_data.get("size", 900.0))
	map.custom_minimum_size = Vector2(430.0, 430.0)
	right.add_child(map)

	var legend := _make_label("◻ estrutura-alvo    ● resgatado    ◉ base", 11, COLOR_DIM)
	right.add_child(legend)

	_prompt = _make_label("ENTER PARA DECOLAR", 16, COLOR_CYAN)
	right.add_child(_prompt)


func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 10)
	return separator


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
