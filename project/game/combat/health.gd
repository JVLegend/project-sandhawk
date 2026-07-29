class_name Health
extends Node

## Vida sem regeneracao, conforme a spec da Fase 4/5.
## Usada tanto pelo helicoptero do jogador quanto pelos inimigos.

signal damaged(event: DamageEvent, remaining: int)
signal died(event: DamageEvent)

@export var max_hp: int = 10

var hp: int = 0
var is_dead: bool = false


func _ready() -> void:
	if hp <= 0:
		hp = max_hp


func setup(p_max_hp: int) -> void:
	max_hp = maxi(1, p_max_hp)
	hp = max_hp
	is_dead = false


## Retorna true quando este dano matou o alvo.
func apply_damage(event: DamageEvent) -> bool:
	if is_dead or event == null or event.amount <= 0:
		return false

	hp = maxi(0, hp - event.amount)
	damaged.emit(event, hp)

	if hp == 0:
		is_dead = true
		died.emit(event)
		return true

	return false


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	hp = mini(max_hp, hp + amount)


func revive() -> void:
	hp = max_hp
	is_dead = false


func get_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)
