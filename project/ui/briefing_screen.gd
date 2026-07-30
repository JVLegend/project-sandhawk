class_name BriefingScreen
extends CanvasLayer

## Tela de briefing: ordem de operacoes a esquerda, mapa tatico a direita.
##
## O mapa e desenhado como papel militar de verdade: fundo de areia (a mesma
## textura CC0 do terreno), grade com coordenadas alfanumericas, rosa dos
## ventos, rota tracejada da base ate cada zona-alvo com ordem numerada e
## carimbo de sigilo. Nao e decoracao gratuita: o jogador sai daqui sabendo
## o caminho, a ordem e o que e neutro.

signal dismissed

const COLOR_BG := Color(0.05, 0.055, 0.06, 0.97)
const COLOR_TEXT := Color(0.86, 0.88, 0.9)
const COLOR_DIM := Color(0.55, 0.58, 0.6)
const COLOR_AMBER := Color(0.96, 0.74, 0.28)
const COLOR_CYAN := Color(0.42, 0.82, 0.94)

## Glifo por tipo de objetivo: leitura instantanea na lista.
const OBJECTIVE_GLYPHS := {
	"destroy": "◎",
	"rescue": "✚",
	"collect": "◆",
}

var _blink_time := 0.0
var _prompt: Label


class TacticalMap extends Control:
	const SAND_TEXTURE := preload("res://assets/textures/sand_color.jpg")

	## Papel de mapa: tons de campo, nao de tela.
	const PAPER := Color(0.84, 0.77, 0.62)
	const INK := Color(0.24, 0.2, 0.15)
	const INK_SOFT := Color(0.24, 0.2, 0.15, 0.35)
	const ROUTE := Color(0.68, 0.2, 0.14)
	const STAMP := Color(0.72, 0.16, 0.12, 0.85)

	const ZONE_COLORS := {
		"village": Color(0.24, 0.42, 0.2),
		"outpost": Color(0.6, 0.16, 0.12),
		"camp": Color(0.16, 0.35, 0.5),
	}

	var world_data: Dictionary = {}
	var world_size := 900.0

	func _draw() -> void:
		var font := UiTheme.FONT_REGULAR
		var bold := UiTheme.FONT_BOLD
		var rect := Rect2(Vector2.ZERO, size)

		## Papel: textura de areia clareada, com borda dupla de documento.
		draw_texture_rect(SAND_TEXTURE, rect, false, PAPER)
		draw_rect(rect, Color(0.32, 0.26, 0.18), false, 3.0)
		draw_rect(Rect2(Vector2(6.0, 6.0), size - Vector2(12.0, 12.0)), INK_SOFT, false, 1.0)

		_draw_grid(font)
		_draw_route(bold)
		_draw_zones(font)
		_draw_pows()
		_draw_structures()
		_draw_base(bold)
		_draw_compass(bold)
		_draw_stamp(bold)

	func _draw_grid(font: Font) -> void:
		var cells := 8
		for index in range(1, cells):
			var t := float(index) / float(cells)
			draw_line(Vector2(size.x * t, 8.0), Vector2(size.x * t, size.y - 8.0), INK_SOFT, 1.0)
			draw_line(Vector2(8.0, size.y * t), Vector2(size.x - 8.0, size.y * t), INK_SOFT, 1.0)

		## Coordenadas alfanumericas nas margens, como carta topografica.
		for index in cells:
			var t := (float(index) + 0.5) / float(cells)
			draw_string(font, Vector2(size.x * t - 4.0, 20.0), char(65 + index), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, INK_SOFT)
			draw_string(font, Vector2(10.0, size.y * t + 4.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, INK_SOFT)

	## Rota tracejada da base ate cada zona hostil, com a ordem numerada.
	func _draw_route(bold: Font) -> void:
		var base_point := _project(world_data.get("base", [0, 0]))
		var order := 1

		for zone in world_data.get("zones", []):
			var kind := str(zone.get("kind", ""))
			if kind == "village":
				continue

			var target := _project(zone.get("position", [0, 0]))
			_draw_dashed(base_point, target, ROUTE, 2.0, 9.0)

			var badge := target + Vector2(14.0, -14.0)
			draw_circle(badge, 10.0, ROUTE)
			draw_string(bold, badge + Vector2(-4.0, 5.0), str(order), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.95, 0.9, 0.8))
			order += 1

	func _draw_zones(font: Font) -> void:
		for zone in world_data.get("zones", []):
			var center := _project(zone.get("position", [0, 0]))
			var radius := float(zone.get("radius", 40.0)) / world_size * size.x
			var kind := str(zone.get("kind", ""))
			var color: Color = ZONE_COLORS.get(kind, INK)

			draw_circle(center, maxf(radius, 7.0), Color(color.r, color.g, color.b, 0.14))
			_draw_dashed_arc(center, maxf(radius, 7.0), color)

			if kind == "village":
				draw_string(font, center + Vector2(-radius, -radius - 6.0), "NEUTRA · NAO ENGAJAR", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, ZONE_COLORS["village"])

			var label := str(zone.get("label", "")).to_upper()
			draw_string(font, center + Vector2(-85.0, radius + 15.0), label, HORIZONTAL_ALIGNMENT_CENTER, 170.0, 10, color.darkened(0.15))

	func _draw_pows() -> void:
		for entry in world_data.get("pows", []):
			var point := _project(entry)
			## Cruz de resgate, nao um pontinho anonimo.
			draw_line(point + Vector2(-4.0, 0.0), point + Vector2(4.0, 0.0), Color(0.1, 0.45, 0.2), 2.4)
			draw_line(point + Vector2(0.0, -4.0), point + Vector2(0.0, 4.0), Color(0.1, 0.45, 0.2), 2.4)

	func _draw_structures() -> void:
		for entry in world_data.get("structures", []):
			var point := _project(entry.get("position", [0, 0]))
			var half := 5.0
			## Alvo: quadrado com X, simbologia de demolicao.
			draw_rect(Rect2(point - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), ROUTE, false, 2.0)
			draw_line(point - Vector2(half, half), point + Vector2(half, half), ROUTE, 1.4)
			draw_line(point + Vector2(-half, half), point + Vector2(half, -half), ROUTE, 1.4)

	func _draw_base(bold: Font) -> void:
		var base_point := _project(world_data.get("base", [0, 0]))
		draw_circle(base_point, 9.0, Color(0.12, 0.3, 0.45))
		draw_arc(base_point, 13.0, 0.0, TAU, 28, Color(0.12, 0.3, 0.45), 1.6)
		draw_string(bold, base_point + Vector2(-4.0, 5.0), "H", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.92, 0.9, 0.82))

	func _draw_compass(bold: Font) -> void:
		var center := Vector2(size.x - 34.0, 40.0)
		draw_arc(center, 14.0, 0.0, TAU, 24, INK, 1.4)
		var tip := center + Vector2(0.0, -12.0)
		draw_colored_polygon(PackedVector2Array([
			tip, center + Vector2(-4.0, 2.0), center + Vector2(4.0, 2.0),
		]), ROUTE)
		draw_string(bold, center + Vector2(-4.0, -18.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, INK)

	func _draw_stamp(bold: Font) -> void:
		## Carimbo rotacionado: transform temporario so para ele.
		var anchor := Vector2(size.x - 128.0, size.y - 26.0)
		draw_set_transform(anchor, -0.09, Vector2.ONE)
		draw_rect(Rect2(Vector2(-6.0, -18.0), Vector2(118.0, 26.0)), STAMP, false, 2.0)
		draw_string(bold, Vector2(2.0, 1.0), "CONFIDENCIAL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, STAMP)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_dashed(from: Vector2, to: Vector2, color: Color, width: float, dash: float) -> void:
		var direction := to - from
		var length := direction.length()
		if length < 1.0:
			return
		direction /= length

		var travelled := 0.0
		while travelled < length:
			var segment_end := minf(travelled + dash, length)
			draw_line(from + direction * travelled, from + direction * segment_end, color, width)
			travelled += dash * 2.0

	func _draw_dashed_arc(center: Vector2, radius: float, color: Color) -> void:
		var segments := 26
		for index in segments:
			if index % 2 == 1:
				continue
			var from_angle := TAU * float(index) / float(segments)
			var to_angle := TAU * float(index + 1) / float(segments)
			draw_arc(center, radius, from_angle, to_angle, 4, color, 1.8)

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
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 30)
	background.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	margin.add_child(columns)

	## -------------------------------------------------- coluna da ordem
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)

	left.add_child(_make_label("ORDEM DE OPERACOES · ALTO SIGILO", 12, COLOR_DIM))

	var title := _make_label(MissionManager.get_title().to_upper(), 26, COLOR_AMBER)
	UiTheme.apply_bold(title)
	left.add_child(title)

	left.add_child(_make_label(
		"TEATRO: DESERTO DE KHARUN          PREVISAO: %d MIN" % int(MissionManager.get_par_time() / 60.0),
		11,
		COLOR_DIM
	))
	left.add_child(_make_separator())

	for line in MissionManager.get_briefing_lines():
		var paragraph := _make_label(str(line), 14, COLOR_TEXT)
		paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paragraph.custom_minimum_size = Vector2(520.0, 0.0)
		left.add_child(paragraph)

	left.add_child(_make_separator())
	left.add_child(_make_label("OBJETIVOS", 12, COLOR_DIM))

	for objective in MissionManager.objectives:
		var glyph: String = OBJECTIVE_GLYPHS.get(str(objective["type"]), "◻")
		var color := COLOR_TEXT if objective["required"] else COLOR_DIM
		var suffix := "" if objective["required"] else "  (opcional)"

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		left.add_child(row)

		var glyph_label := _make_label(glyph, 15, COLOR_AMBER if objective["required"] else COLOR_DIM)
		glyph_label.custom_minimum_size = Vector2(20.0, 0.0)
		row.add_child(glyph_label)
		row.add_child(_make_label("%s%s" % [objective["label"], suffix], 14, color))

	## -------------------------------------------------- coluna do mapa
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)

	right.add_child(_make_label("CARTA TATICA · ESCALA 1:%d" % int(MissionManager.get_world_data().get("size", 900.0) * 10.0), 12, COLOR_DIM))

	var map := TacticalMap.new()
	map.world_data = MissionManager.get_world_data()
	map.world_size = float(map.world_data.get("size", 900.0))
	map.custom_minimum_size = Vector2(440.0, 440.0)
	right.add_child(map)

	right.add_child(_make_label("◎ demolir    ✚ resgatar    ◆ recuperar    ⬡ base    - - rota", 11, COLOR_DIM))

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
