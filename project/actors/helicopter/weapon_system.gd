class_name WeaponSystem
extends Node3D

## Gerencia as tres armas do helicoptero. Toda regra vem do WeaponDefinition:
## trocar um .tres muda cadencia, dano, alcance e municao sem tocar em codigo.

signal ammo_changed(slot: int, ammo: int, max_ammo: int)
signal weapon_fired(slot: int)
signal shot_denied(slot: int)

const PROJECTILE_SCENE := preload("res://actors/projectiles/projectile.tscn")

const SLOT_ACTIONS := ["fire_primary", "fire_secondary", "fire_special"]


class WeaponRuntime extends RefCounted:
	var definition: WeaponDefinition
	var ammo: int = 0
	var cooldown: float = 0.0

	func _init(p_definition: WeaponDefinition) -> void:
		definition = p_definition
		ammo = p_definition.max_ammo


var runtimes: Array[WeaponRuntime] = []

var _shooter: Node3D
var _targeting: TargetingSystem


func setup(definitions: Array, targeting: TargetingSystem) -> void:
	_shooter = get_parent() as Node3D
	_targeting = targeting

	runtimes.clear()
	for definition in definitions:
		runtimes.append(WeaponRuntime.new(definition))

	for slot in runtimes.size():
		var runtime := runtimes[slot]
		ammo_changed.emit(slot, runtime.ammo, runtime.definition.max_ammo)


func get_runtime(slot: int) -> WeaponRuntime:
	if slot < 0 or slot >= runtimes.size():
		return null
	return runtimes[slot]


func refill_all() -> void:
	for slot in runtimes.size():
		var runtime := runtimes[slot]
		runtime.ammo = runtime.definition.max_ammo
		ammo_changed.emit(slot, runtime.ammo, runtime.definition.max_ammo)


func _physics_process(delta: float) -> void:
	if _shooter == null:
		return

	for slot in runtimes.size():
		var runtime := runtimes[slot]
		runtime.cooldown = maxf(0.0, runtime.cooldown - delta)

		if slot >= SLOT_ACTIONS.size():
			continue
		if not Input.is_action_pressed(SLOT_ACTIONS[slot]):
			continue
		if runtime.cooldown > 0.0:
			continue

		if runtime.ammo <= 0:
			if Input.is_action_just_pressed(SLOT_ACTIONS[slot]):
				shot_denied.emit(slot)
			continue

		_fire(slot, runtime)


func _fire(slot: int, runtime: WeaponRuntime) -> void:
	var definition := runtime.definition
	var muzzle_global := _shooter.to_global(definition.muzzle_offset)
	var aim_direction := _aim_direction(muzzle_global, definition)

	match definition.mode:
		WeaponDefinition.Mode.HITSCAN:
			_fire_hitscan(muzzle_global, aim_direction, definition)
		WeaponDefinition.Mode.PROJECTILE:
			_fire_projectile(muzzle_global, aim_direction, definition, null)
		WeaponDefinition.Mode.HOMING:
			_fire_projectile(muzzle_global, aim_direction, definition, _targeting.target_within(definition.range_meters) if _targeting != null else null)

	runtime.ammo -= 1
	runtime.cooldown = definition.seconds_between_shots()

	Vfx.spawn_muzzle_flash(_shooter, definition.muzzle_offset, definition.tracer_color, 0.42)
	get_tree().call_group("camera_rig", "add_trauma", definition.trauma)

	ammo_changed.emit(slot, runtime.ammo, definition.max_ammo)
	weapon_fired.emit(slot)


func _aim_direction(muzzle_global: Vector3, definition: WeaponDefinition) -> Vector3:
	if _targeting != null:
		var target := _targeting.target_within(definition.range_meters)
		if target != null:
			var to_target := CombatUtils.aim_point_for(target) - muzzle_global
			if to_target.length_squared() > 0.0001:
				return to_target.normalized()

	return -_shooter.global_transform.basis.z.normalized()


func _fire_hitscan(muzzle_global: Vector3, aim_direction: Vector3, definition: WeaponDefinition) -> void:
	var direction := CombatUtils.apply_spread(aim_direction, definition.spread_degrees)
	var end_point := muzzle_global + direction * definition.range_meters

	var query := PhysicsRayQueryParameters3D.create(muzzle_global, end_point, CombatLayers.PLAYER_SHOT_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		Vfx.spawn_tracer(muzzle_global, end_point, definition.tracer_color)
		return

	var impact_point: Vector3 = result.get("position", end_point)
	var normal: Vector3 = result.get("normal", -direction)
	Vfx.spawn_tracer(muzzle_global, impact_point, definition.tracer_color)

	var target := CombatUtils.resolve_damageable(result.get("collider") as Node)
	if target == null:
		Vfx.spawn_impact(impact_point, normal, Color(0.75, 0.68, 0.55))
		return

	var event := DamageEvent.create(
		definition.damage,
		DamageEvent.Type.BULLET,
		muzzle_global,
		impact_point,
		true,
		_shooter
	)
	target.take_damage(event)
	Vfx.spawn_impact(impact_point, normal, definition.tracer_color)


func _fire_projectile(muzzle_global: Vector3, aim_direction: Vector3, definition: WeaponDefinition, target: Node3D) -> void:
	var direction := CombatUtils.apply_spread(aim_direction, definition.spread_degrees)

	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectile.setup(definition, direction, true, target)
	projectile.source = _shooter

	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(projectile)

	projectile.global_position = muzzle_global
	projectile.look_at(muzzle_global + direction, Vector3.UP)
