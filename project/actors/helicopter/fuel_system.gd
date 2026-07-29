class_name FuelSystem
extends Node

## Combustivel: o recurso que transforma "mais um alvo" numa decisao.
## Dreno constante em voo, sem regeneracao, so reabastecimento em pickup ou base.

signal fuel_changed(current: float, maximum: float)
signal warning_entered
signal critical_entered
signal emptied

enum Level {
	NORMAL,
	WARNING,
	CRITICAL,
}

var tuning: ResourceTuning
var fuel: float = 0.0
var level: int = Level.NORMAL

var _draining := true


func setup(p_tuning: ResourceTuning) -> void:
	tuning = p_tuning
	fuel = tuning.fuel_max
	level = Level.NORMAL
	_draining = true
	fuel_changed.emit(fuel, tuning.fuel_max)


func set_draining(value: bool) -> void:
	_draining = value


func refill(amount: float) -> void:
	if tuning == null:
		return

	fuel = minf(tuning.fuel_max, fuel + amount)
	_refresh_level()
	fuel_changed.emit(fuel, tuning.fuel_max)


func refill_full() -> void:
	if tuning != null:
		refill(tuning.fuel_max)


func get_ratio() -> float:
	if tuning == null or tuning.fuel_max <= 0.0:
		return 0.0
	return clampf(fuel / tuning.fuel_max, 0.0, 1.0)


func _process(delta: float) -> void:
	if tuning == null or not _draining or fuel <= 0.0:
		return

	fuel = maxf(0.0, fuel - tuning.fuel_drain_per_second * delta)
	fuel_changed.emit(fuel, tuning.fuel_max)
	_refresh_level()

	if fuel <= 0.0:
		emptied.emit()


func _refresh_level() -> void:
	var previous := level

	if fuel <= tuning.fuel_critical_threshold:
		level = Level.CRITICAL
	elif fuel <= tuning.fuel_warning_threshold:
		level = Level.WARNING
	else:
		level = Level.NORMAL

	if level == previous:
		return

	if level == Level.WARNING:
		warning_entered.emit()
	elif level == Level.CRITICAL:
		critical_entered.emit()
