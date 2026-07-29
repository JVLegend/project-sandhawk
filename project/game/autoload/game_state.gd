extends Node

## Estado global da sessao. Na Fase 6 o MissionManager assume objetivos e score
## de missao; aqui fica so o que e transversal ao jogo inteiro.

signal score_changed(score: int)

var phase_name := "combat"
var score := 0

var _hitstop_active := false


func add_score(amount: int) -> void:
	if amount == 0:
		return
	score += amount
	score_changed.emit(score)


func reset_score() -> void:
	score = 0
	score_changed.emit(score)


## Congela o jogo por alguns frames. Da peso ao abate sem custar animacao.
func hitstop(frames: int = 2) -> void:
	if _hitstop_active or frames <= 0:
		return

	_hitstop_active = true
	Engine.time_scale = 0.0

	for _i in frames:
		await get_tree().process_frame

	Engine.time_scale = 1.0
	_hitstop_active = false
