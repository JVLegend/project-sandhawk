class_name ResourceTuning
extends Resource

## Tuning do triangulo combustivel / blindagem / municao e do resgate.
## Separado do FlightTuning de proposito: voo e uma coisa, economia e outra.

@export_group("Combustivel")
@export var fuel_max: float = 100.0
## Unidades por segundo em voo.
@export var fuel_drain_per_second: float = 1.0
@export var fuel_warning_threshold: float = 25.0
@export var fuel_critical_threshold: float = 10.0
@export var fuel_pickup_amount: float = 50.0

@export_group("Blindagem")
@export var armor_max: int = 600
@export var armor_pickup_amount: int = 200

@export_group("Base amiga")
@export var pad_radius: float = 9.0
## Velocidade maxima para o pad reconhecer que o helicoptero estabilizou.
@export var pad_max_speed: float = 2.5
@export var pad_hold_seconds: float = 2.0
## Tempo para reabastecer tudo. Longo de proposito: cria janela de vulnerabilidade.
@export var refuel_seconds: float = 10.0

@export_group("Resgate")
@export var winch_descend_seconds: float = 2.0
@export var winch_ascend_seconds: float = 2.0
@export var winch_max_speed: float = 3.0
@export var rescue_radius: float = 5.0
@export var passenger_capacity: int = 6
@export var rescue_score: int = 150
@export var delivery_score_bonus: int = 100
@export var delivery_armor_bonus: int = 40

@export_group("Municao por pickup")
@export var ammo_pickup_machinegun: int = 400
@export var ammo_pickup_rockets: int = 12
@export var ammo_pickup_missiles: int = 3
