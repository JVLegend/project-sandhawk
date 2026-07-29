class_name PlayerHelicopter
extends Node3D

## Helicoptero do jogador. Voo arcade (posicao direta, sem corpo fisico), com
## inclinacao e rolagem puramente visuais, e a leitura de altitude vindo da
## sombra projetada no chao.

signal armor_changed(current: int, maximum: int)
signal destroyed(reason: String)

const SHADOW_TEXTURE_SIZE := 128
const RESPAWN_DELAY := 1.6

const RESOURCE_TUNING := preload("res://data/resource_tuning.tres")

const WEAPON_DEFINITIONS := [
	preload("res://data/weapons/machinegun.tres"),
	preload("res://data/weapons/rockets.tres"),
	preload("res://data/weapons/missiles.tres"),
]

const HULL := Color(0.27, 0.30, 0.26)
const HULL_DARK := Color(0.17, 0.19, 0.17)
const HULL_LIGHT := Color(0.36, 0.39, 0.34)
const GLASS := Color(0.11, 0.16, 0.18)
const METAL := Color(0.44, 0.45, 0.42)

var tuning

var planar_velocity := Vector2.ZERO
var visual_pitch := 0.0
var visual_roll := 0.0

var health: Health
var weapons: WeaponSystem
var targeting: TargetingSystem
var fuel: FuelSystem
var winch: WinchSystem

var _body_pivot: Node3D
var _rotor_pivot: Node3D
var _tail_rotor_pivot: Node3D
var _rotor_blur: MeshInstance3D
var _shadow: Decal
var _beacon: MeshInstance3D

var _spawn_position := Vector3.ZERO
var _respawning := false
var _beacon_time := 0.0

## Fracoes acumuladas do reabastecimento gradual na base.
var _service_armor_debt := 0.0
var _service_ammo_debt := 0.0


func _ready() -> void:
	_ensure_structure()
	_ensure_combat()
	if tuning != null:
		_apply_tuning()


func setup(tuning_resource) -> void:
	tuning = tuning_resource
	if is_inside_tree():
		_apply_tuning()


func mark_spawn_point() -> void:
	_spawn_position = global_position


func get_planar_velocity() -> Vector2:
	return planar_velocity


func get_planar_speed() -> float:
	return planar_velocity.length()


func get_speed_ratio() -> float:
	if tuning == null or is_zero_approx(tuning.max_speed):
		return 0.0
	return clampf(planar_velocity.length() / tuning.max_speed, 0.0, 1.0)


func get_aim_point() -> Vector3:
	return global_position


func is_alive() -> bool:
	return health != null and not health.is_dead


func take_damage(event: DamageEvent) -> void:
	if not is_alive() or _respawning:
		return

	health.apply_damage(event)
	armor_changed.emit(health.hp, health.max_hp)

	Vfx.spawn_impact(event.impact_point, Vector3.UP, Color(1.0, 0.72, 0.4))
	get_tree().call_group("camera_rig", "add_trauma", clampf(float(event.amount) * 0.012, 0.03, 0.35))

	AudioManager.play_at(AudioManager.Sfx.ARMOR_HIT, global_position, -8.0)
	AudioManager.report_combat()


## Recebe uma fracao do reabastecimento completo (0..1 acumulado ao longo do tempo).
func receive_service(ratio: float) -> void:
	if ratio <= 0.0:
		return

	fuel.refill(RESOURCE_TUNING.fuel_max * ratio)

	_service_armor_debt += float(health.max_hp) * ratio
	var armor_step := int(_service_armor_debt)
	if armor_step > 0:
		_service_armor_debt -= float(armor_step)
		health.heal(armor_step)
		armor_changed.emit(health.hp, health.max_hp)

	_service_ammo_debt += ratio
	if _service_ammo_debt >= 0.1:
		weapons.refill_fraction(_service_ammo_debt)
		_service_ammo_debt = 0.0


func deliver_passengers() -> int:
	var delivered := winch.deliver_all()
	if delivered > 0:
		health.heal(RESOURCE_TUNING.delivery_armor_bonus * delivered)
		armor_changed.emit(health.hp, health.max_hp)
	return delivered


func apply_pickup(type: int) -> void:
	match type:
		Pickup.Type.FUEL:
			fuel.refill(RESOURCE_TUNING.fuel_pickup_amount)
		Pickup.Type.ARMOR:
			health.heal(RESOURCE_TUNING.armor_pickup_amount)
			armor_changed.emit(health.hp, health.max_hp)
		Pickup.Type.AMMO_MACHINEGUN:
			weapons.add_ammo(0, RESOURCE_TUNING.ammo_pickup_machinegun)
		Pickup.Type.AMMO_ROCKETS:
			weapons.add_ammo(1, RESOURCE_TUNING.ammo_pickup_rockets)
		Pickup.Type.AMMO_MISSILES:
			weapons.add_ammo(2, RESOURCE_TUNING.ammo_pickup_missiles)


func _physics_process(delta: float) -> void:
	if tuning == null or _respawning:
		return

	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var target_velocity := Vector2(
		move_input.x * tuning.max_speed * tuning.strafe_ratio,
		move_input.y * tuning.max_speed
	)

	if move_input.length_squared() > 0.001:
		planar_velocity = planar_velocity.move_toward(target_velocity, tuning.accel * delta)
	else:
		planar_velocity = planar_velocity.move_toward(Vector2.ZERO, tuning.decel_drag * delta)

	var yaw_input := Input.get_axis("turn_left", "turn_right")
	rotate_y(deg_to_rad(yaw_input * tuning.turn_rate * delta))

	global_position.x += planar_velocity.x * delta
	global_position.z += planar_velocity.y * delta
	global_position.y = tuning.hover_altitude

	_update_visuals(delta)


func _apply_tuning() -> void:
	global_position.y = tuning.hover_altitude
	if _shadow != null:
		_shadow.position = Vector3.ZERO
		_shadow.size = Vector3(tuning.shadow_size, tuning.hover_altitude * 2.4, tuning.shadow_size)


func _update_visuals(delta: float) -> void:
	if _body_pivot == null or _rotor_pivot == null or tuning == null:
		return

	_rotor_pivot.rotate_y(deg_to_rad(tuning.rotor_speed_degrees * delta))
	if _tail_rotor_pivot != null:
		_tail_rotor_pivot.rotate_x(deg_to_rad(tuning.rotor_speed_degrees * 1.6 * delta))

	var horizontal_velocity := Vector3(planar_velocity.x, 0.0, planar_velocity.y)
	var right_dir := basis.x
	right_dir.y = 0.0
	right_dir = right_dir.normalized()

	var forward_dir := -basis.z
	forward_dir.y = 0.0
	forward_dir = forward_dir.normalized()

	var max_speed := maxf(tuning.max_speed, 0.001)
	var lateral_ratio := horizontal_velocity.dot(right_dir) / max_speed
	var forward_ratio := horizontal_velocity.dot(forward_dir) / max_speed

	var target_roll := deg_to_rad(-lateral_ratio * tuning.bank_max)
	var target_pitch := deg_to_rad(-forward_ratio * tuning.pitch_max)
	var blend := 1.0 - exp(-tuning.bank_lerp * delta)

	visual_roll = lerp_angle(visual_roll, target_roll, blend)
	visual_pitch = lerp_angle(visual_pitch, target_pitch, blend)
	_body_pivot.rotation = Vector3(visual_pitch, 0.0, visual_roll)

	var speed_ratio := get_speed_ratio()
	var blur_alpha := remap(speed_ratio, tuning.rotor_blur_threshold, 1.0, 0.0, tuning.rotor_blur_max_alpha)
	blur_alpha = clampf(blur_alpha, 0.0, tuning.rotor_blur_max_alpha)

	var rotor_material := _rotor_blur.material_override as StandardMaterial3D
	if rotor_material != null:
		var color := rotor_material.albedo_color
		color.a = blur_alpha
		rotor_material.albedo_color = color

	_beacon_time += delta
	if _beacon != null:
		var beacon_material := _beacon.material_override as StandardMaterial3D
		if beacon_material != null:
			beacon_material.emission_energy_multiplier = 3.5 * maxf(0.0, sin(_beacon_time * 4.0))


## ---------------------------------------------------------------- modelo

func _ensure_structure() -> void:
	if get_node_or_null("BodyPivot") != null:
		_body_pivot = get_node("BodyPivot")
		_rotor_pivot = get_node("BodyPivot/RotorPivot")
		_rotor_blur = get_node("BodyPivot/RotorPivot/RotorBlur")
		return

	_body_pivot = Node3D.new()
	_body_pivot.name = "BodyPivot"
	add_child(_body_pivot)

	_build_fuselage()
	_build_tail()
	_build_wings()
	_build_skids()
	_build_main_rotor()
	_build_lights()
	_build_shadow()


func _build_fuselage() -> void:
	var hull := _material(HULL, 0.62, 0.15)
	var hull_dark := _material(HULL_DARK, 0.7, 0.1)
	var glass := _material(GLASS, 0.12, 0.5)
	glass.metallic = 0.4

	## Cabine principal, com o nariz afinando para a frente.
	_add_mesh(_body_pivot, "Cabin", _box(Vector3(2.5, 1.55, 3.4)), Vector3(0.0, 0.2, 0.35), hull)

	var nose := _add_mesh(_body_pivot, "Nose", _box(Vector3(2.1, 1.2, 1.9)), Vector3(0.0, 0.05, -1.65), hull)
	nose.scale = Vector3(0.82, 0.86, 1.0)

	var nose_tip := _add_mesh(_body_pivot, "NoseTip", _box(Vector3(1.35, 0.8, 1.0)), Vector3(0.0, -0.05, -2.75), hull_dark)
	nose_tip.scale = Vector3(0.8, 0.85, 1.0)

	## Canopy: vidro escuro inclinado, e o que da leitura de "frente" ao modelo.
	var canopy := _add_mesh(_body_pivot, "Canopy", _box(Vector3(1.9, 0.9, 2.2)), Vector3(0.0, 0.95, -0.85), glass)
	canopy.rotation_degrees = Vector3(-12.0, 0.0, 0.0)

	_add_mesh(_body_pivot, "Spine", _box(Vector3(1.5, 0.7, 2.6)), Vector3(0.0, 1.05, 0.95), hull_dark)

	## Motores nas laterais do rotor.
	for side in [-0.98, 0.98]:
		var engine := _add_mesh(
			_body_pivot,
			"Engine%s" % ("L" if side < 0.0 else "R"),
			_cylinder(0.42, 2.0, 10),
			Vector3(side, 1.15, 0.85),
			_material(HULL_LIGHT, 0.55, 0.25)
		)
		engine.rotation_degrees = Vector3(90.0, 0.0, 0.0)

		_add_mesh(
			_body_pivot,
			"Exhaust%s" % ("L" if side < 0.0 else "R"),
			_cylinder(0.3, 0.5, 8),
			Vector3(side, 1.15, 1.95),
			_material(Color(0.1, 0.09, 0.08), 0.9, 0.0)
		).rotation_degrees = Vector3(90.0, 0.0, 0.0)


func _build_tail() -> void:
	var hull := _material(HULL, 0.62, 0.15)
	var hull_dark := _material(HULL_DARK, 0.7, 0.1)

	var boom := _add_mesh(_body_pivot, "TailBoom", _box(Vector3(0.62, 0.6, 4.2)), Vector3(0.0, 0.62, 4.1), hull)
	boom.scale = Vector3(1.0, 1.0, 1.0)

	var boom_end := _add_mesh(_body_pivot, "TailBoomEnd", _box(Vector3(0.44, 0.44, 1.4)), Vector3(0.0, 0.68, 6.6), hull)
	boom_end.scale = Vector3(0.9, 0.9, 1.0)

	## Deriva vertical inclinada, com o rotor de cauda embutido.
	var fin := _add_mesh(_body_pivot, "TailFin", _box(Vector3(0.28, 1.9, 1.15)), Vector3(0.0, 1.4, 7.05), hull_dark)
	fin.rotation_degrees = Vector3(14.0, 0.0, 0.0)

	_add_mesh(_body_pivot, "Stabilizer", _box(Vector3(2.6, 0.16, 0.8)), Vector3(0.0, 0.75, 6.5), hull_dark)

	for side in [-1.15, 1.15]:
		_add_mesh(_body_pivot, "StabFin%s" % ("L" if side < 0.0 else "R"), _box(Vector3(0.14, 0.62, 0.7)), Vector3(side, 1.0, 6.5), hull_dark)

	_tail_rotor_pivot = Node3D.new()
	_tail_rotor_pivot.name = "TailRotorPivot"
	_tail_rotor_pivot.position = Vector3(0.32, 1.55, 7.1)
	_body_pivot.add_child(_tail_rotor_pivot)

	var blade_material := _material(Color(0.13, 0.13, 0.13), 0.6, 0.1)
	for angle in [0.0, 90.0]:
		var blade := _add_mesh(_tail_rotor_pivot, "TailBlade%d" % int(angle), _box(Vector3(0.08, 1.7, 0.12)), Vector3.ZERO, blade_material)
		blade.rotation_degrees = Vector3(angle, 0.0, 0.0)


func _build_wings() -> void:
	var hull := _material(HULL, 0.62, 0.15)
	var pod_material := _material(Color(0.22, 0.24, 0.21), 0.55, 0.25)
	var missile_material := _material(Color(0.6, 0.58, 0.52), 0.45, 0.2)

	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"

		_add_mesh(_body_pivot, "Wing%s" % tag, _box(Vector3(2.0, 0.22, 1.2)), Vector3(side * 2.1, 0.35, 0.3), hull)

		## Casulo de foguetes na ponta interna, missil na externa.
		var pod := _add_mesh(_body_pivot, "RocketPod%s" % tag, _cylinder(0.34, 1.6, 10), Vector3(side * 2.5, 0.02, 0.15), pod_material)
		pod.rotation_degrees = Vector3(90.0, 0.0, 0.0)

		var missile := _add_mesh(_body_pivot, "Missile%s" % tag, _capsule(0.16, 1.7, 8), Vector3(side * 3.15, 0.06, 0.1), missile_material)
		missile.rotation_degrees = Vector3(90.0, 0.0, 0.0)


func _build_skids() -> void:
	var skid_material := _material(Color(0.2, 0.21, 0.19), 0.55, 0.35)

	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"

		var skid := _add_mesh(_body_pivot, "Skid%s" % tag, _cylinder(0.11, 4.2, 8), Vector3(side * 1.25, -1.05, 0.4), skid_material)
		skid.rotation_degrees = Vector3(90.0, 0.0, 0.0)

		for offset in [-1.1, 1.2]:
			var strut := _add_mesh(_body_pivot, "Strut%s%d" % [tag, int(offset * 10.0)], _box(Vector3(0.13, 0.95, 0.13)), Vector3(side * 1.05, -0.6, offset), skid_material)
			strut.rotation_degrees = Vector3(0.0, 0.0, side * -9.0)


func _build_main_rotor() -> void:
	var hub_material := _material(Color(0.2, 0.21, 0.19), 0.5, 0.45)
	var blade_material := _material(Color(0.12, 0.12, 0.12), 0.62, 0.1)

	var mast := _add_mesh(_body_pivot, "Mast", _cylinder(0.22, 0.7, 8), Vector3(0.0, 1.65, 0.2), hub_material)

	_rotor_pivot = Node3D.new()
	_rotor_pivot.name = "RotorPivot"
	_rotor_pivot.position = Vector3(0.0, 2.0, 0.2)
	_body_pivot.add_child(_rotor_pivot)

	_add_mesh(_rotor_pivot, "Hub", _cylinder(0.42, 0.34, 10), Vector3.ZERO, hub_material)

	## Quatro pas: silhueta de helicoptero de ataque moderno.
	for index in 4:
		var blade := _add_mesh(_rotor_pivot, "Blade%d" % index, _box(Vector3(0.26, 0.07, 6.4)), Vector3(0.0, 0.06, 0.0), blade_material)
		blade.rotation_degrees = Vector3(0.0, 45.0 * float(index), 0.0)
		blade.position = Vector3(sin(deg_to_rad(45.0 * index)) * 3.2, 0.06, cos(deg_to_rad(45.0 * index)) * 3.2)
		blade.rotation_degrees = Vector3(0.0, 45.0 * float(index), 1.5)

	_rotor_blur = MeshInstance3D.new()
	_rotor_blur.name = "RotorBlur"
	var disc := CylinderMesh.new()
	disc.top_radius = 6.5
	disc.bottom_radius = 6.5
	disc.height = 0.02
	disc.radial_segments = 32
	_rotor_blur.mesh = disc

	var blur_material := StandardMaterial3D.new()
	blur_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur_material.albedo_color = Color(0.82, 0.86, 0.9, 0.0)
	blur_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rotor_blur.material_override = blur_material
	_rotor_pivot.add_child(_rotor_blur)


func _build_lights() -> void:
	## Luzes de navegacao: vermelho a bombordo, verde a estibordo, branco na cauda.
	_add_light(Vector3(-3.35, 0.18, -0.1), Color(1.0, 0.15, 0.12))
	_add_light(Vector3(3.35, 0.18, -0.1), Color(0.2, 1.0, 0.3))
	_add_light(Vector3(0.0, 1.05, 7.4), Color(1.0, 1.0, 0.95))

	_beacon = _add_light(Vector3(0.0, 1.5, 2.1), Color(1.0, 0.2, 0.16))


func _add_light(light_position: Vector3, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.6

	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	mesh.radial_segments = 7
	mesh.rings = 4

	return _add_mesh(_body_pivot, "NavLight", mesh, light_position, material)


func _build_shadow() -> void:
	## Decal em vez de quad: projeta certo em duna, telhado e pista, e some
	## quando o helicoptero passa sobre um vao.
	_shadow = Decal.new()
	_shadow.name = "GroundShadow"
	_shadow.texture_albedo = _make_shadow_texture()
	_shadow.modulate = Color(0.05, 0.05, 0.07)
	_shadow.albedo_mix = 0.85
	_shadow.upper_fade = 0.1
	_shadow.lower_fade = 2.0
	_shadow.size = Vector3(8.0, 30.0, 8.0)
	add_child(_shadow)


## ---------------------------------------------------------------- combate

func _ensure_combat() -> void:
	if get_node_or_null("Health") != null:
		return

	add_to_group("player")

	var hitbox := Area3D.new()
	hitbox.name = "HitBox"
	hitbox.collision_layer = CombatLayers.PLAYER
	hitbox.collision_mask = 0
	hitbox.monitorable = true
	hitbox.monitoring = false

	var hitbox_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 1.8, 5.2)
	hitbox_shape.shape = box
	hitbox.add_child(hitbox_shape)
	add_child(hitbox)

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(RESOURCE_TUNING.armor_max)
	health.died.connect(_on_destroyed)

	targeting = TargetingSystem.new()
	targeting.name = "TargetingSystem"
	add_child(targeting)

	weapons = WeaponSystem.new()
	weapons.name = "WeaponSystem"
	add_child(weapons)
	weapons.setup(WEAPON_DEFINITIONS, targeting)

	fuel = FuelSystem.new()
	fuel.name = "FuelSystem"
	add_child(fuel)
	fuel.setup(RESOURCE_TUNING)
	fuel.emptied.connect(_on_fuel_emptied)

	winch = WinchSystem.new()
	winch.name = "WinchSystem"
	add_child(winch)
	winch.setup(RESOURCE_TUNING, self)

	armor_changed.emit(health.hp, health.max_hp)


func _on_fuel_emptied() -> void:
	_crash("combustivel")


func _on_destroyed(_event: DamageEvent) -> void:
	_crash("blindagem")


func _crash(reason: String) -> void:
	if _respawning:
		return

	_respawning = true
	planar_velocity = Vector2.ZERO
	fuel.set_draining(false)

	Vfx.spawn_explosion(global_position, 2.0)
	get_tree().call_group("camera_rig", "add_trauma", 0.9)
	destroyed.emit(reason)

	visible = false
	var hitbox := get_node_or_null("HitBox") as Area3D
	if hitbox != null:
		hitbox.collision_layer = 0

	await get_tree().create_timer(RESPAWN_DELAY).timeout
	_respawn(hitbox)


func _respawn(hitbox: Area3D) -> void:
	global_position = _spawn_position
	rotation = Vector3.ZERO
	planar_velocity = Vector2.ZERO
	visual_pitch = 0.0
	visual_roll = 0.0

	health.revive()
	if weapons != null:
		weapons.refill_all()
	if fuel != null:
		fuel.refill_full()
		fuel.set_draining(true)

	if hitbox != null:
		hitbox.collision_layer = CombatLayers.PLAYER

	visible = true
	_respawning = false
	armor_changed.emit(health.hp, health.max_hp)
	get_tree().call_group("camera_rig", "snap_to_target")


## ---------------------------------------------------------------- helpers

func _add_mesh(parent: Node3D, node_name: String, mesh: Mesh, offset: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder(radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


func _capsule(radius: float, height: float, segments: int) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 3
	return mesh


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _make_shadow_texture() -> ImageTexture:
	var image := Image.create(SHADOW_TEXTURE_SIZE, SHADOW_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SHADOW_TEXTURE_SIZE, SHADOW_TEXTURE_SIZE) * 0.5
	var radius := SHADOW_TEXTURE_SIZE * 0.46

	for y in range(SHADOW_TEXTURE_SIZE):
		for x in range(SHADOW_TEXTURE_SIZE):
			var distance := Vector2(x, y).distance_to(center)
			var alpha := 1.0 - smoothstep(radius * 0.2, radius, distance)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)
