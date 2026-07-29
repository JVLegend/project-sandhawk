class_name DebugCombatHud
extends CanvasLayer

## HUD provisorio da Fase 4: existe para tornar o combate testavel (municao,
## blindagem, alvo travado). O HUD real, com fuel e passageiros, entra na Fase 5.

const WEAPON_KEYS := ["ESPACO", "F", "R"]

var _player: PlaceholderHelicopter
var _armor_bar: ProgressBar
var _armor_label: Label
var _score_label: Label
var _targets_label: Label
var _target_label: Label
var _weapon_labels: Array[Label] = []


func setup(player: PlaceholderHelicopter) -> void:
	_player = player
	_build_ui()

	if _player == null:
		return

	_player.armor_changed.connect(_on_armor_changed)
	if _player.weapons != null:
		_player.weapons.ammo_changed.connect(_on_ammo_changed)
	if _player.targeting != null:
		_player.targeting.target_changed.connect(_on_target_changed)

	GameState.score_changed.connect(_on_score_changed)

	## O helicoptero monta as armas no proprio _ready, antes do HUD existir, entao
	## as emissoes iniciais de ammo_changed ja passaram: preencher na mao aqui.
	if _player.weapons != null:
		for slot in _player.weapons.runtimes.size():
			var runtime := _player.weapons.get_runtime(slot)
			_on_ammo_changed(slot, runtime.ammo, runtime.definition.max_ammo)

	if _player.health != null:
		_on_armor_changed(_player.health.hp, _player.health.max_hp)
	_on_score_changed(GameState.score)


func _process(_delta: float) -> void:
	if _targets_label == null:
		return
	_targets_label.text = "ALVOS RESTANTES  %d" % get_tree().get_nodes_in_group("enemy").size()


func _on_armor_changed(current: int, maximum: int) -> void:
	if _armor_bar == null:
		return
	_armor_bar.max_value = maximum
	_armor_bar.value = current
	_armor_label.text = "BLINDAGEM  %d / %d" % [current, maximum]

	var ratio := float(current) / maxf(1.0, float(maximum))
	var color := Color(0.45, 0.85, 0.5)
	if ratio < 0.25:
		color = Color(0.92, 0.32, 0.28)
	elif ratio < 0.55:
		color = Color(0.95, 0.75, 0.3)
	_armor_bar.add_theme_color_override("font_color", color)

	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	_armor_bar.add_theme_stylebox_override("fill", fill)


func _on_ammo_changed(slot: int, ammo: int, max_ammo: int) -> void:
	if slot < 0 or slot >= _weapon_labels.size():
		return

	var definition: WeaponDefinition = _player.weapons.get_runtime(slot).definition
	var label := _weapon_labels[slot]
	label.text = "[%s] %-12s %4d / %d" % [WEAPON_KEYS[slot], definition.display_name, ammo, max_ammo]
	label.add_theme_color_override("font_color", Color(0.62, 0.28, 0.24) if ammo == 0 else Color(0.9, 0.93, 0.96))


func _on_score_changed(score: int) -> void:
	if _score_label != null:
		_score_label.text = "PONTOS  %d" % score


func _on_target_changed(target: Node3D) -> void:
	if _target_label == null:
		return

	if target == null:
		_target_label.text = ""
		return

	var display_name := "ALVO"
	if target is EnemyBase and target.definition != null:
		display_name = target.definition.display_name.to_upper()
	_target_label.text = "▼ %s TRAVADO" % display_name


func _build_ui() -> void:
	var status_panel := _make_panel(Vector2(18.0, 16.0))
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 4)
	status_panel.add_child(status_box)

	_armor_label = _make_label("BLINDAGEM")
	status_box.add_child(_armor_label)

	_armor_bar = ProgressBar.new()
	_armor_bar.custom_minimum_size = Vector2(240.0, 10.0)
	_armor_bar.show_percentage = false

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.11, 0.12, 0.9)
	_armor_bar.add_theme_stylebox_override("background", background)
	status_box.add_child(_armor_bar)

	_score_label = _make_label("PONTOS  0")
	status_box.add_child(_score_label)

	_targets_label = _make_label("ALVOS RESTANTES  0")
	status_box.add_child(_targets_label)

	var weapon_panel := _make_panel(Vector2(18.0, 0.0))
	weapon_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	weapon_panel.position = Vector2(18.0, -132.0)
	weapon_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var weapon_box := VBoxContainer.new()
	weapon_box.add_theme_constant_override("separation", 3)
	weapon_panel.add_child(weapon_box)

	for index in 3:
		var label := _make_label("")
		label.add_theme_font_override("font", ThemeDB.fallback_font)
		weapon_box.add_child(label)
		_weapon_labels.append(label)

	weapon_box.add_child(_make_label("W A S D mover · Q E girar · F5 reiniciar", 12, Color(0.65, 0.68, 0.72)))

	_target_label = _make_label("", 15, Color(1.0, 0.45, 0.36))
	_target_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_target_label.position = Vector2(-90.0, 22.0)
	_target_label.custom_minimum_size = Vector2(180.0, 0.0)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_child(status_panel)
	root.add_child(weapon_panel)
	root.add_child(_target_label)


func _make_panel(panel_position: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = panel_position
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.08, 0.62)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	return panel


func _make_label(text: String, font_size: int = 14, color: Color = Color(0.9, 0.93, 0.96)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
