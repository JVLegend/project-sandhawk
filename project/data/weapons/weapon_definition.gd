class_name WeaponDefinition
extends Resource

## Definicao de arma 100% data-driven: mudar um .tres muda o jogo sem tocar em codigo.

enum Mode {
	HITSCAN,
	PROJECTILE,
	HOMING,
}

@export_group("Identidade")
@export var id: String = ""
@export var display_name: String = ""
@export var mode: Mode = Mode.HITSCAN

@export_group("Municao e cadencia")
@export var max_ammo: int = 100
## Disparos por segundo.
@export var fire_rate: float = 10.0

@export_group("Dano")
@export var damage: int = 1
@export var range_meters: float = 35.0
@export var splash_radius: float = 0.0
@export var splash_damage: int = 0

@export_group("Balistica")
## Dispersao em graus (so vale para HITSCAN).
@export var spread_degrees: float = 3.0
@export var projectile_speed: float = 60.0
## Graus por segundo de correcao para o modo HOMING.
@export var homing_turn_rate: float = 90.0

@export_group("Feedback")
@export var trauma: float = 0.02
@export var tracer_color: Color = Color(1.0, 0.86, 0.45)
@export var muzzle_offset: Vector3 = Vector3(0.0, -0.1, -2.8)


func seconds_between_shots() -> float:
	return 1.0 / maxf(0.01, fire_rate)
