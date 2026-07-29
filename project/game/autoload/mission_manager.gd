extends Node

## Estado de missao: carrega o JSON, acompanha objetivos e decide vitoria/derrota.
## Toda a estrutura da missao (mapa, inimigos, objetivos) vem do arquivo de dados,
## para adicionar conteudo novo sem mexer no codigo central.

signal objectives_changed
signal objective_completed(objective_id: String)
signal objective_unlocked(objective_id: String)
signal mission_completed(stats: Dictionary)
signal mission_failed(reason: String)

const MAX_LOSSES := 3

var mission: Dictionary = {}
var objectives: Array[Dictionary] = []
var elapsed := 0.0
var running := false
var losses := 0
var rescued_delivered := 0


func load_mission(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missao nao encontrada: %s" % path)
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Missao invalida (JSON nao e objeto): %s" % path)
		return false

	mission = parsed
	_build_objective_state()
	return true


func start() -> void:
	elapsed = 0.0
	losses = 0
	rescued_delivered = 0
	running = true
	_build_objective_state()
	objectives_changed.emit()


func stop() -> void:
	running = false


func get_title() -> String:
	return mission.get("name", "Missao sem nome")


func get_briefing_lines() -> Array:
	return mission.get("briefing", [])


func get_world_data() -> Dictionary:
	return mission.get("world", {})


func get_par_time() -> float:
	var debriefing: Dictionary = mission.get("debriefing", {})
	return float(debriefing.get("par_time_sec", 600))


## Objetivos visiveis: os que nao estao travados por outro objetivo.
func get_visible_objectives() -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for objective in objectives:
		if _is_locked(objective):
			continue
		visible.append(objective)
	return visible


func notify_structure_destroyed(structure_id: String) -> void:
	if not running or structure_id.is_empty():
		return

	for objective in objectives:
		if objective["type"] != "destroy" or objective["done"]:
			continue
		if _is_locked(objective):
			continue
		var pending: Array = objective["pending"]
		if not pending.has(structure_id):
			continue
		pending.erase(structure_id)
		if pending.is_empty():
			_complete(objective)

	_refresh_unlocks()
	objectives_changed.emit()
	_check_completion()


func notify_rescued_delivered(count: int) -> void:
	if not running or count <= 0:
		return

	rescued_delivered += count

	for objective in objectives:
		if objective["type"] != "rescue" or objective["done"]:
			continue
		objective["progress"] = mini(objective["target_count"], objective["progress"] + count)
		if objective["progress"] >= objective["target_count"]:
			_complete(objective)

	_refresh_unlocks()
	objectives_changed.emit()
	_check_completion()


func notify_collected(item_id: String) -> void:
	if not running or item_id.is_empty():
		return

	for objective in objectives:
		if objective["type"] != "collect" or objective["done"]:
			continue
		var pending: Array = objective["pending"]
		if not pending.has(item_id):
			continue
		pending.erase(item_id)
		if pending.is_empty():
			_complete(objective)

	objectives_changed.emit()
	_check_completion()


func notify_player_lost() -> void:
	if not running:
		return

	losses += 1
	if losses >= MAX_LOSSES:
		running = false
		mission_failed.emit("helicoptero perdido %d vezes" % losses)


func build_stats() -> Dictionary:
	var required_done := 0
	var required_total := 0
	var optional_done := 0
	var optional_total := 0

	for objective in objectives:
		if objective["required"]:
			required_total += 1
			if objective["done"]:
				required_done += 1
		else:
			optional_total += 1
			if objective["done"]:
				optional_done += 1

	return {
		"title": get_title(),
		"time": elapsed,
		"par_time": get_par_time(),
		"score": GameState.score,
		"losses": losses,
		"rescued": rescued_delivered,
		"required_done": required_done,
		"required_total": required_total,
		"optional_done": optional_done,
		"optional_total": optional_total,
	}


func _process(delta: float) -> void:
	if running:
		elapsed += delta


func _build_objective_state() -> void:
	objectives.clear()

	for entry in mission.get("objectives", []):
		var targets: Array = entry.get("targets", [])
		var objective := {
			"id": str(entry.get("id", "")),
			"label": str(entry.get("label", entry.get("id", ""))),
			"type": str(entry.get("type", "destroy")),
			"required": bool(entry.get("required", true)),
			"locked_by": entry.get("locked_by", []),
			"pending": targets.duplicate(),
			"target_count": int(entry.get("count", 0)),
			"progress": 0,
			"done": false,
			"announced": false,
		}
		objectives.append(objective)


func _is_locked(objective: Dictionary) -> bool:
	for blocker_id in objective["locked_by"]:
		var blocker = _find_objective(str(blocker_id))
		if blocker != null and not blocker["done"]:
			return true
	return false


func _find_objective(objective_id: String):
	for objective in objectives:
		if objective["id"] == objective_id:
			return objective
	return null


func _complete(objective: Dictionary) -> void:
	objective["done"] = true
	objective_completed.emit(objective["id"])


func _refresh_unlocks() -> void:
	for objective in objectives:
		if objective["announced"] or objective["done"]:
			continue
		if _is_locked(objective):
			continue
		objective["announced"] = true
		objective_unlocked.emit(objective["id"])


func _check_completion() -> void:
	if not running:
		return

	for objective in objectives:
		if objective["required"] and not objective["done"]:
			return

	running = false
	mission_completed.emit(build_stats())
