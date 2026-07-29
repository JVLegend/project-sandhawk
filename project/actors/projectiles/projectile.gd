class_name Projectile
extends Node3D

## Projetil de foguete/missil. O movimento e manual e a colisao usa raycast de
## segmento (posicao anterior -> posicao nova), o que elimina tunelamento em
## velocidades altas sem depender de fisica continua.

var speed: float = 60.0
var damage: int = 8
var splash_radius: float = 0.0
var splash_damage: int = 0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 4.0
var homing_target: Node3D = null
var homing_turn_rate: float = 0.0
var from_player: bool = true
var body_color: Color = Color(1.0, 0.55, 0.22)
var source: Node = null

var _collision_mask: int = CombatLayers.PLAYER_SHOT_MASK
var _trail: GPUParticles3D


func setup(definition: WeaponDefinition, start_direction: Vector3, shooter_is_player: bool, target: Node3D = null) -> void:
	speed = definition.projectile_speed
	damage = definition.damage
	splash_radius = definition.splash_radius
	splash_damage = definition.splash_damage
	homing_turn_rate = definition.homing_turn_rate
	body_color = definition.tracer_color
	direction = start_direction.normalized()
	from_player = shooter_is_player
	homing_target = target
	lifetime = definition.range_meters / maxf(1.0, definition.projectile_speed) + 0.5
	_collision_mask = CombatLayers.PLAYER_SHOT_MASK if shooter_is_player else CombatLayers.ENEMY_SHOT_MASK


## Usado pelos inimigos, que nao tem WeaponDefinition.
func setup_simple(
	p_speed: float,
	p_damage: int,
	start_direction: Vector3,
	p_color: Color,
	p_range: float,
	p_homing_target: Node3D = null,
	p_homing_turn_rate: float = 0.0,
	p_splash_radius: float = 0.0,
	p_splash_damage: int = 0
) -> void:
	speed = p_speed
	damage = p_damage
	splash_radius = p_splash_radius
	splash_damage = p_splash_damage
	homing_target = p_homing_target
	homing_turn_rate = p_homing_turn_rate
	body_color = p_color
	direction = start_direction.normalized()
	from_player = false
	lifetime = p_range / maxf(1.0, p_speed) + 0.5
	_collision_mask = CombatLayers.ENEMY_SHOT_MASK


func _ready() -> void:
	_build_visual()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
		return

	_update_homing(delta)

	var from := global_position
	var to := from + direction * speed * delta

	var query := PhysicsRayQueryParameters3D.create(from, to, _collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		_detonate(result.get("position", to), result.get("collider"))
		return

	global_position = to
	look_at(global_position + direction, Vector3.UP)


func _update_homing(delta: float) -> void:
	if homing_turn_rate <= 0.0 or homing_target == null or not is_instance_valid(homing_target):
		return

	var target_point := CombatUtils.aim_point_for(homing_target)

	## Quebrar linha de visada despista o missil: e a defesa do jogador contra o SAM.
	if not from_player and not CombatUtils.has_line_of_sight(get_world_3d(), global_position, target_point):
		homing_target = null
		return

	var desired := (target_point - global_position).normalized()
	var max_turn := deg_to_rad(homing_turn_rate) * delta
	var angle := direction.angle_to(desired)

	if angle <= max_turn:
		direction = desired
		return

	var axis := direction.cross(desired)
	if axis.length_squared() < 0.000001:
		return
	direction = direction.rotated(axis.normalized(), max_turn).normalized()


func _detonate(impact_point: Vector3, collider: Object) -> void:
	var direct_target := CombatUtils.resolve_damageable(collider as Node)
	if direct_target != null:
		var event := DamageEvent.create(
			damage,
			DamageEvent.Type.EXPLOSIVE if splash_radius > 0.0 else DamageEvent.Type.BULLET,
			global_position,
			impact_point,
			from_player,
			source
		)
		direct_target.take_damage(event)

	if splash_radius > 0.0:
		_apply_splash(impact_point, direct_target)
		Vfx.spawn_explosion(impact_point, clampf(splash_radius / 3.0, 0.6, 2.0))
		_shake_camera(clampf(splash_radius * 0.03, 0.05, 0.25))
	else:
		Vfx.spawn_impact(impact_point, -direction, body_color)

	_expire()


func _apply_splash(center: Vector3, already_hit: Node) -> void:
	var group := "enemy" if from_player else "player"

	for node in get_tree().get_nodes_in_group(group):
		if node == already_hit or not is_instance_valid(node):
			continue
		var target := node as Node3D
		if target == null or not target.has_method("take_damage"):
			continue
		if CombatUtils.aim_point_for(target).distance_to(center) > splash_radius:
			continue

		var event := DamageEvent.create(
			splash_damage,
			DamageEvent.Type.EXPLOSIVE,
			center,
			target.global_position,
			from_player,
			source
		)
		target.take_damage(event)


func _shake_camera(amount: float) -> void:
	get_tree().call_group("camera_rig", "add_trauma", amount)


func _expire() -> void:
	_detach_trail()
	queue_free()


## Solta o rastro antes de morrer para a fumaca nao sumir de repente.
func _detach_trail() -> void:
	if _trail == null or not is_instance_valid(_trail):
		return

	var trail := _trail
	_trail = null
	var global_transform_snapshot := trail.global_transform
	remove_child(trail)

	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(trail)
	trail.global_transform = global_transform_snapshot
	trail.emitting = false

	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(trail):
			trail.queue_free()
	)


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.95
	mesh.radial_segments = 8
	mesh.rings = 2
	body.mesh = mesh
	body.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	material.emission_enabled = true
	material.emission = body_color
	material.emission_energy_multiplier = 2.2
	material.roughness = 0.6
	body.material_override = material
	add_child(body)

	_trail = GPUParticles3D.new()
	_trail.name = "Trail"
	_trail.amount = 22
	_trail.lifetime = 0.55
	_trail.local_coords = false

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_trail.draw_pass_1 = quad

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = Vector3.ZERO
	process.spread = 8.0
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0.0, 0.6, 0.0)
	process.scale_min = 0.35
	process.scale_max = 0.8
	process.damping_min = 0.5
	process.damping_max = 1.5

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.78, 0.7, 0.7))
	ramp.set_color(1, Color(0.6, 0.55, 0.5, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	_trail.process_material = process

	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	trail_material.vertex_color_use_as_albedo = true
	_trail.material_override = trail_material

	add_child(_trail)
	_trail.emitting = true
