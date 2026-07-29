class_name PlaceholderHelicopter
extends Node3D

signal armor_changed(current: int, maximum: int)
signal destroyed

const SHADOW_TEXTURE_SIZE := 96

## Escala de blindagem do original. A Fase 5 move este valor para um resource de
## tuning junto com combustivel e municao.
const ARMOR_MAX := 600
const RESPAWN_DELAY := 1.6

const WEAPON_DEFINITIONS := [
	preload("res://data/weapons/machinegun.tres"),
	preload("res://data/weapons/rockets.tres"),
	preload("res://data/weapons/missiles.tres"),
]

var tuning

var planar_velocity := Vector2.ZERO
var visual_pitch := 0.0
var visual_roll := 0.0

var health: Health
var weapons: WeaponSystem
var targeting: TargetingSystem

var _body_pivot: Node3D
var _rotor_pivot: Node3D
var _rotor_blur: MeshInstance3D
var _shadow: MeshInstance3D
var _spawn_position := Vector3.ZERO
var _respawning := false


func _ready() -> void:
	_ensure_structure()
	_ensure_combat()
	if tuning != null:
		_apply_tuning()


func setup(tuning_resource) -> void:
	tuning = tuning_resource
	if is_inside_tree():
		_apply_tuning()


func get_planar_velocity() -> Vector2:
	return planar_velocity


func get_planar_speed() -> float:
	return planar_velocity.length()


func get_speed_ratio() -> float:
	if tuning == null or is_zero_approx(tuning.max_speed):
		return 0.0
	return clampf(planar_velocity.length() / tuning.max_speed, 0.0, 1.0)


## Chamado pelo mundo depois de posicionar o helicoptero.
func mark_spawn_point() -> void:
	_spawn_position = global_position


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
		_shadow.position = Vector3(0.0, -tuning.hover_altitude + 0.08, 0.0)
		var quad_mesh := _shadow.mesh as QuadMesh
		if quad_mesh != null:
			quad_mesh.size = Vector2.ONE * tuning.shadow_size


func _update_visuals(delta: float) -> void:
	if _body_pivot == null or _rotor_pivot == null or tuning == null:
		return

	_rotor_pivot.rotate_y(deg_to_rad(tuning.rotor_speed_degrees * delta))

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


func _ensure_structure() -> void:
	if get_node_or_null("BodyPivot") != null:
		_body_pivot = get_node("BodyPivot")
		_rotor_pivot = get_node("BodyPivot/RotorPivot")
		_rotor_blur = get_node("BodyPivot/RotorPivot/RotorBlur")
		_shadow = get_node("Shadow")
		return

	_body_pivot = Node3D.new()
	_body_pivot.name = "BodyPivot"
	add_child(_body_pivot)

	var heli_material := _make_material(Color("7d8289"))
	var accent_material := _make_material(Color("969da6"))
	var dark_material := _make_material(Color("44484f"))

	_add_box_mesh(_body_pivot, "Body", Vector3(2.8, 0.9, 4.4), Vector3(0.0, 0.25, 0.0), heli_material)
	_add_box_mesh(_body_pivot, "Cockpit", Vector3(1.9, 0.55, 1.8), Vector3(0.0, 0.55, -0.65), accent_material)
	_add_box_mesh(_body_pivot, "TailBoom", Vector3(0.34, 0.3, 4.2), Vector3(0.0, 0.28, 3.75), heli_material)
	_add_box_mesh(_body_pivot, "TailFin", Vector3(0.22, 0.95, 0.55), Vector3(0.0, 0.8, 5.45), dark_material)
	_add_box_mesh(_body_pivot, "LeftSkid", Vector3(0.14, 0.14, 3.3), Vector3(-1.05, -0.38, 0.0), dark_material)
	_add_box_mesh(_body_pivot, "RightSkid", Vector3(0.14, 0.14, 3.3), Vector3(1.05, -0.38, 0.0), dark_material)

	_add_box_mesh(_body_pivot, "SkidStrutFrontL", Vector3(0.1, 0.45, 0.1), Vector3(-0.7, -0.12, -1.0), dark_material)
	_add_box_mesh(_body_pivot, "SkidStrutFrontR", Vector3(0.1, 0.45, 0.1), Vector3(0.7, -0.12, -1.0), dark_material)
	_add_box_mesh(_body_pivot, "SkidStrutRearL", Vector3(0.1, 0.45, 0.1), Vector3(-0.7, -0.12, 1.0), dark_material)
	_add_box_mesh(_body_pivot, "SkidStrutRearR", Vector3(0.1, 0.45, 0.1), Vector3(0.7, -0.12, 1.0), dark_material)

	_rotor_pivot = Node3D.new()
	_rotor_pivot.name = "RotorPivot"
	_rotor_pivot.position = Vector3(0.0, 0.82, -0.1)
	_body_pivot.add_child(_rotor_pivot)

	_add_box_mesh(_rotor_pivot, "RotorBladeA", Vector3(0.14, 0.04, 5.2), Vector3.ZERO, dark_material)
	_add_box_mesh(_rotor_pivot, "RotorBladeB", Vector3(5.2, 0.04, 0.14), Vector3.ZERO, dark_material)

	_rotor_blur = MeshInstance3D.new()
	_rotor_blur.name = "RotorBlur"
	var rotor_disc := CylinderMesh.new()
	rotor_disc.top_radius = 2.35
	rotor_disc.bottom_radius = 2.35
	rotor_disc.height = 0.02
	rotor_disc.radial_segments = 24
	_rotor_blur.mesh = rotor_disc
	_rotor_blur.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var blur_material := StandardMaterial3D.new()
	blur_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur_material.albedo_color = Color(0.88, 0.91, 0.95, 0.0)
	blur_material.no_depth_test = true
	_rotor_blur.material_override = blur_material
	_rotor_pivot.add_child(_rotor_blur)

	_shadow = MeshInstance3D.new()
	_shadow.name = "Shadow"
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(7.0, 7.0)
	_shadow.mesh = shadow_quad
	_shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_shadow.position = Vector3(0.0, -11.92, 0.0)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_texture = _make_shadow_texture()
	shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	shadow_material.no_depth_test = true
	_shadow.material_override = shadow_material
	add_child(_shadow)


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
	health.setup(ARMOR_MAX)
	health.died.connect(_on_destroyed)

	targeting = TargetingSystem.new()
	targeting.name = "TargetingSystem"
	add_child(targeting)

	weapons = WeaponSystem.new()
	weapons.name = "WeaponSystem"
	add_child(weapons)
	weapons.setup(WEAPON_DEFINITIONS, targeting)

	armor_changed.emit(health.hp, health.max_hp)


func _on_destroyed(_event: DamageEvent) -> void:
	if _respawning:
		return

	_respawning = true
	planar_velocity = Vector2.ZERO

	Vfx.spawn_explosion(global_position, 2.0)
	get_tree().call_group("camera_rig", "add_trauma", 0.9)
	destroyed.emit()

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

	if hitbox != null:
		hitbox.collision_layer = CombatLayers.PLAYER

	visible = true
	_respawning = false
	armor_changed.emit(health.hp, health.max_hp)


func _add_box_mesh(parent: Node3D, node_name: String, size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	mesh.material_override = material
	parent.add_child(mesh)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.metallic = 0.05
	return material


func _make_shadow_texture() -> ImageTexture:
	var image := Image.create(SHADOW_TEXTURE_SIZE, SHADOW_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SHADOW_TEXTURE_SIZE, SHADOW_TEXTURE_SIZE) * 0.5
	var radius := SHADOW_TEXTURE_SIZE * 0.42

	for y in range(SHADOW_TEXTURE_SIZE):
		for x in range(SHADOW_TEXTURE_SIZE):
			var distance := Vector2(x, y).distance_to(center)
			var alpha := 1.0 - smoothstep(radius * 0.28, radius, distance)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)
