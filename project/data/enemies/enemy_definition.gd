class_name EnemyDefinition
extends Resource

## Definicao de inimigo data-driven. Um .tres por tipo em data/enemies/.

@export_group("Identidade")
@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 2
@export var score_value: int = 10

@export_group("Movimento")
## Zero para torretas e alvos fixos.
@export var move_speed: float = 0.0
@export var flee_speed: float = 0.0
## Abaixo ou igual a este HP o inimigo foge. Zero desliga a fuga.
@export var flee_at_hp: int = 0

@export_group("Combate")
@export var detection_range: float = 30.0
@export var attack_range: float = 20.0
@export var attack_damage: int = 4
@export var attack_cooldown: float = 1.4
@export var burst_count: int = 1
@export var burst_interval: float = 0.18
## Zero dispara hitscan; acima de zero dispara projetil nessa velocidade.
@export var projectile_speed: float = 0.0
## Tempo de travamento antes do primeiro tiro, em segundos.
@export var lock_on_time: float = 0.0
@export var requires_line_of_sight: bool = true
## Acima de zero o projetil persegue o jogador nessa taxa de curva (graus/s).
@export var projectile_homing_turn_rate: float = 0.0
@export var projectile_splash_radius: float = 0.0
@export var projectile_splash_damage: int = 0

@export_group("Visual")
@export var body_color: Color = Color("b4443c")
@export var body_size: Vector3 = Vector3(1.0, 1.8, 1.0)
@export var explosion_scale: float = 1.0
