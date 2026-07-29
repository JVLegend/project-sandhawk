extends Node

## Estado global da sessao. Na Fase 6 o MissionManager assume objetivos e score
## de missao; aqui fica so o que e transversal ao jogo inteiro.

signal score_changed(score: int)
signal campaign_changed(current_mission_id: String, unlocked_count: int)

var phase_name := "combat"
var score := 0
var campaign: Array[Dictionary] = []
var current_mission_index := 0
var unlocked_mission_count := 1
var best_scores := {}
var best_times := {}

## Runtime, de proposito fora do save: o menu de titulo aparece so no primeiro
## boot de cada execucao, nunca em restart de missao.
var title_shown := false

var _hitstop_active := false

const CAMPAIGN_PATH := "res://data/campaign.json"
const SAVE_PATH := "user://campaign_save.json"


func _ready() -> void:
	_load_campaign_manifest()
	_load_save()


func has_campaign() -> bool:
	_ensure_campaign_loaded()
	return not campaign.is_empty()


func get_mission_count() -> int:
	_ensure_campaign_loaded()
	return campaign.size()


func get_current_mission_path() -> String:
	_ensure_campaign_loaded()
	if campaign.is_empty():
		return ""
	return str(campaign[_clamp_index(current_mission_index)].get("path", ""))


func get_current_mission_title() -> String:
	_ensure_campaign_loaded()
	if campaign.is_empty():
		return ""
	return str(campaign[_clamp_index(current_mission_index)].get("name", ""))


func get_mission_title(index: int) -> String:
	_ensure_campaign_loaded()
	if campaign.is_empty():
		return ""
	return str(campaign[_clamp_index(index)].get("name", ""))


func has_mission(index: int) -> bool:
	_ensure_campaign_loaded()
	return index >= 0 and index < campaign.size()


func set_current_mission_index(index: int) -> void:
	_ensure_campaign_loaded()
	if campaign.is_empty():
		current_mission_index = 0
		return

	current_mission_index = _clamp_index(index)
	_save()
	_emit_campaign_changed()


func complete_mission(mission_index: int, stats: Dictionary) -> Dictionary:
	_ensure_campaign_loaded()
	var clamped_index := _clamp_index(mission_index)
	var next_index := clamped_index + 1
	var unlocked_next := false

	if next_index < campaign.size() and unlocked_mission_count <= next_index:
		unlocked_mission_count = next_index + 1
		unlocked_next = true

	current_mission_index = mini(next_index, campaign.size() - 1)

	var mission_id := str(stats.get("mission_id", ""))
	var score_value := int(stats.get("score", 0))
	var time_value := float(stats.get("time", 0.0))

	if not mission_id.is_empty():
		var best_score := int(best_scores.get(mission_id, 0))
		if score_value > best_score:
			best_scores[mission_id] = score_value

		var best_time := float(best_times.get(mission_id, 0.0))
		if best_time <= 0.0 or time_value < best_time:
			best_times[mission_id] = time_value

	_save()
	_emit_campaign_changed()

	return {
		"has_next": next_index < campaign.size(),
		"unlocked_next": unlocked_next,
		"next_title": get_mission_title(next_index) if next_index < campaign.size() else "",
	}


func add_score(amount: int) -> void:
	if amount == 0:
		return
	score += amount
	score_changed.emit(score)


func reset_score() -> void:
	score = 0
	score_changed.emit(score)


## Congela o jogo por alguns frames. Da peso ao abate sem custar animacao.
##
## O timer precisa ignorar o time_scale (ultimo argumento), senao ele fica preso
## no proprio congelamento e o jogo nunca volta a rodar.
func hitstop(frames: int = 2) -> void:
	if _hitstop_active or frames <= 0:
		return

	_hitstop_active = true
	Engine.time_scale = 0.0

	await get_tree().create_timer(float(frames) / 60.0, true, false, true).timeout

	Engine.time_scale = 1.0
	_hitstop_active = false


func _load_campaign_manifest() -> void:
	campaign.clear()

	var file := FileAccess.open(CAMPAIGN_PATH, FileAccess.READ)
	if file == null:
		push_error("Campaign manifest nao encontrado: %s" % CAMPAIGN_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Campaign manifest invalido: %s" % CAMPAIGN_PATH)
		return

	for entry in parsed.get("missions", []):
		if typeof(entry) == TYPE_DICTIONARY:
			campaign.append(entry)

	if campaign.is_empty():
		push_error("Campaign manifest sem missoes: %s" % CAMPAIGN_PATH)


func _ensure_campaign_loaded() -> void:
	if campaign.is_empty():
		_load_campaign_manifest()


func _load_save() -> void:
	if campaign.is_empty():
		return

	if not FileAccess.file_exists(SAVE_PATH):
		current_mission_index = 0
		unlocked_mission_count = 1
		_emit_campaign_changed()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_emit_campaign_changed()
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		_emit_campaign_changed()
		return

	current_mission_index = _clamp_index(int(parsed.get("current_mission_index", 0)))
	unlocked_mission_count = clampi(int(parsed.get("unlocked_mission_count", 1)), 1, campaign.size())
	best_scores = parsed.get("best_scores", {})
	best_times = parsed.get("best_times", {})
	_emit_campaign_changed()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Falha ao gravar save em %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify({
		"current_mission_index": current_mission_index,
		"unlocked_mission_count": unlocked_mission_count,
		"best_scores": best_scores,
		"best_times": best_times,
	}))
	file.close()


func _emit_campaign_changed() -> void:
	var mission_id := ""
	if not campaign.is_empty():
		mission_id = str(campaign[_clamp_index(current_mission_index)].get("id", ""))
	campaign_changed.emit(mission_id, unlocked_mission_count)


func _clamp_index(index: int) -> int:
	if campaign.is_empty():
		return 0
	return clampi(index, 0, campaign.size() - 1)
