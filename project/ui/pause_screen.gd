class_name PauseScreen
extends CanvasLayer

## Menu de pausa. Congela a arvore inteira (get_tree().paused) e sobrevive ao
## congelamento via PROCESS_MODE_ALWAYS. A musica continua tocando de proposito:
## o AudioManager e um autoload marcado como ALWAYS, entao so o mundo para.

signal resumed
signal restart_requested
signal quit_to_title_requested

const COLOR_TEXT := Color(0.86, 0.88, 0.9)
const COLOR_DIM := Color(0.5, 0.53, 0.56)
const COLOR_AMBER := Color(0.96, 0.74, 0.28)

const OPTIONS := [
	"CONTINUAR",
	"REINICIAR MISSAO",
	"SAIR PARA O MENU",
]

var _selected := 0
var _labels: Array[Label] = []


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_choose(0)
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_move(1)
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_move(-1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		get_viewport().set_input_as_handled()
		_choose(_selected)


func _move(direction: int) -> void:
	_selected = clampi(_selected + direction, 0, OPTIONS.size() - 1)
	AudioManager.play_ui_click()
	_refresh()


func _choose(index: int) -> void:
	AudioManager.play_ui_click()
	match index:
		0:
			resumed.emit()
			close()
		1:
			get_tree().paused = false
			restart_requested.emit()
		2:
			get_tree().paused = false
			quit_to_title_requested.emit()


func _refresh() -> void:
	for index in _labels.size():
		var label := _labels[index]
		var selected := index == _selected
		label.text = ("▸  %s" if selected else "   %s") % OPTIONS[index]
		label.add_theme_color_override("font_color", COLOR_AMBER if selected else COLOR_TEXT)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(dim)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.08, 0.96)
	style.border_width_left = 3
	style.border_color = COLOR_AMBER
	style.content_margin_left = 34.0
	style.content_margin_right = 44.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSA"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COLOR_AMBER)
	UiTheme.apply_bold(title)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "missao em andamento"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	box.add_child(hint)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	box.add_child(spacer)

	for option in OPTIONS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 16)
		box.add_child(label)
		_labels.append(label)
