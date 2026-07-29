class_name EnemyBase
extends CharacterBody3D

## Base comum dos inimigos: vida, dano, morte, feedback e helpers de tiro.
## A maquina de estados vive nas subclasses e e proposital que seja simples
## (enum + match), conforme a spec da Fase 4.

signal killed(enemy: EnemyBase)

enum State {
	IDLE,
	ALERT,
	ATTACK,
	FLEE,
	DEAD,
}

const PROJECTILE_SCENE := preload("res://actors/projectiles/projectile.tscn")

var definition: EnemyDefinition
var health: Health
var state: int = State.IDLE

var _body_mesh: MeshInstance3D
var _player: Node3D
var _attack_cooldown := 0.0
var _burst_left := 0
var _burst_timer := 0.0


func setup(p_definition: EnemyDefinition) -> void:
	definition = p_definition

	collision_layer = CombatLayers.ENEMY
	collision_mask = CombatLayers.WORLD
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("enemy")

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(definition.max_hp)
	health.died.connect(_on_died)

	_build_collision()
	_build_visual()


func _physics_process(delta: float) -> void:
	if state == State.DEAD or definition == null:
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_tick_burst(delta)
	_tick_state(delta)


## Ponto de mira: centro do corpo, nao a base.
func get_aim_point() -> Vector3:
	if definition == null:
		return global_position
	return global_position + Vector3.UP * definition.body_size.y * 0.25


func is_alive() -> bool:
	return state != State.DEAD and health != null and not health.is_dead


func take_damage(event: DamageEvent) -> void:
	if not is_alive():
		return

	Vfx.flash_mesh(_body_mesh)
	health.apply_damage(event)


## Sobrescrito pelas subclasses.
func _tick_state(_delta: float) -> void:
	pass


## Sobrescrito pelas subclasses para detalhes de silhueta.
func _build_visual() -> void:
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "Body"

	var mesh := BoxMesh.new()
	mesh.size = definition.body_size
	_body_mesh.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = definition.body_color
	material.roughness = 0.85
	material.metallic = 0.05
	_body_mesh.material_override = material

	add_child(_body_mesh)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Hitbox"
	var box := BoxShape3D.new()
	box.size = definition.body_size
	shape.shape = box
	add_child(shape)


func distance_to_player() -> float:
	if _player == null:
		return INF
	return global_position.distance_to(_player.global_position)


func has_line_of_sight_to_player() -> bool:
	if _player == null:
		return false
	if not definition.requires_line_of_sight:
		return true
	return CombatUtils.has_line_of_sight(
		get_world_3d(),
		get_aim_point() + Vector3.UP * definition.body_size.y * 0.35,
		CombatUtils.aim_point_for(_player)
	)


func start_burst() -> void:
	if _attack_cooldown > 0.0 or _burst_left > 0:
		return
	_burst_left = maxi(1, definition.burst_count)
	_burst_timer = 0.0
	_attack_cooldown = definition.attack_cooldown


func _tick_burst(delta: float) -> void:
	if _burst_left <= 0:
		return

	_burst_timer -= delta
	if _burst_timer > 0.0:
		return

	_burst_timer = definition.burst_interval
	_burst_left -= 1
	_shoot_once()


func _shoot_once() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var muzzle := get_aim_point() + Vector3.UP * definition.body_size.y * 0.3
	var direction := (CombatUtils.aim_point_for(_player) - muzzle).normalized()

	AudioManager.play_at(AudioManager.Sfx.ENEMY_SHOT, muzzle, -7.0)
	AudioManager.report_combat()

	if definition.projectile_speed > 0.0:
		_shoot_projectile(muzzle, direction)
	else:
		_shoot_hitscan(muzzle, direction)


func _shoot_hitscan(muzzle: Vector3, direction: Vector3) -> void:
	var spread_direction := CombatUtils.apply_spread(direction, 2.5)
	var end_point := muzzle + spread_direction * definition.attack_range

	var query := PhysicsRayQueryParameters3D.create(muzzle, end_point, CombatLayers.ENEMY_SHOT_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var tracer_color := Color(1.0, 0.42, 0.3)
	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		Vfx.spawn_tracer(muzzle, end_point, tracer_color, 0.035)
		return

	var impact_point: Vector3 = result.get("position", end_point)
	Vfx.spawn_tracer(muzzle, impact_point, tracer_color, 0.035)

	var target := CombatUtils.resolve_damageable(result.get("collider") as Node)
	if target == null:
		Vfx.spawn_impact(impact_point, result.get("normal", -spread_direction), Color(0.75, 0.68, 0.55))
		return

	target.take_damage(DamageEvent.create(
		definition.attack_damage,
		DamageEvent.Type.BULLET,
		muzzle,
		impact_point,
		false,
		self
	))


func _shoot_projectile(muzzle: Vector3, direction: Vector3) -> void:
	var homing := definition.projectile_homing_turn_rate > 0.0
	var spread_direction := CombatUtils.apply_spread(direction, 0.4 if homing else 1.8)

	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectile.setup_simple(
		definition.projectile_speed,
		definition.attack_damage,
		spread_direction,
		Color(0.86, 0.9, 1.0) if homing else Color(1.0, 0.5, 0.24),
		definition.attack_range * 1.4,
		_player if homing else null,
		definition.projectile_homing_turn_rate,
		definition.projectile_splash_radius,
		definition.projectile_splash_damage
	)
	projectile.source = self

	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(projectile)
	projectile.global_position = muzzle


func _on_died(_event: DamageEvent) -> void:
	state = State.DEAD
	set_physics_process(false)
	collision_layer = 0
	remove_from_group("enemy")

	Vfx.spawn_explosion(get_aim_point(), definition.explosion_scale)
	get_tree().call_group("camera_rig", "add_trauma", clampf(definition.explosion_scale * 0.22, 0.06, 0.4))
	GameState.add_score(definition.score_value)
	GameState.hitstop()

	killed.emit(self)
	queue_free()
