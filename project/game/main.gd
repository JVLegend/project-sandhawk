extends Node3D

const GROUND_SIZE := Vector2(220.0, 220.0)
const FLIGHT_TUNING := preload("res://data/flight_tuning.tres")
const HELICOPTER_SCENE := preload("res://actors/helicopter/placeholder_helicopter.tscn")
const CAMERA_RIG_SCENE := preload("res://game/camera_follow_rig.tscn")
const GROUND_SHADER := preload("res://world/terrain/grid_ground.gdshader")

const SOLDIER_SCENE := preload("res://actors/enemies/soldier_enemy.tscn")
const AAA_SCENE := preload("res://actors/enemies/aaa_turret.tscn")
const SOLDIER_DEFINITION := preload("res://data/enemies/soldier_ak.tres")
const AAA_DEFINITION := preload("res://data/enemies/aaa_gun.tres")

## Arena de teste da Fase 4: 7 soldados + 3 canhoes AAA = 10 alvos.
const SOLDIER_POSITIONS := [
	Vector2(24.0, -26.0),
	Vector2(-30.0, 18.0),
	Vector2(10.0, 40.0),
	Vector2(-18.0, -42.0),
	Vector2(44.0, 8.0),
	Vector2(-46.0, -8.0),
	Vector2(0.0, 58.0),
]

const AAA_POSITIONS := [
	Vector2(38.0, -40.0),
	Vector2(-42.0, 36.0),
	Vector2(52.0, 44.0),
]


func _ready() -> void:
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	_ensure_runtime_input_map()
	_ensure_world_environment()
	_ensure_sun()
	_ensure_ground()
	_ensure_obstacle_course()
	_ensure_enemies()
	var helicopter = _ensure_helicopter()
	_ensure_camera(helicopter)
	_ensure_hud(helicopter)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_restart"):
		GameState.reset_score()
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


func _ensure_world_environment() -> void:
	if get_node_or_null("WorldEnvironment") != null:
		return

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("7ab7e8")
	sky_material.sky_horizon_color = Color("f4d08f")
	sky_material.ground_bottom_color = Color("b0804d")
	sky_material.ground_horizon_color = Color("d0aa72")

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f3dcc0")
	environment.ambient_light_energy = 0.6

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


func _ensure_sun() -> void:
	if get_node_or_null("Sun") != null:
		return

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	add_child(sun)


func _ensure_ground() -> void:
	if get_node_or_null("Ground") != null:
		return

	var mesh := PlaneMesh.new()
	mesh.size = GROUND_SIZE
	mesh.subdivide_depth = 2
	mesh.subdivide_width = 2

	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	ground.material_override = material
	add_child(ground)

	## Sem corpo de colisao, tiros e linha de visada atravessariam o chao.
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	ground_body.collision_layer = CombatLayers.WORLD
	ground_body.collision_mask = 0

	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(GROUND_SIZE.x, 2.0, GROUND_SIZE.y)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(0.0, -1.0, 0.0)
	ground_body.add_child(ground_shape)
	ground.add_child(ground_body)


func _ensure_obstacle_course() -> void:
	if get_node_or_null("ObstacleCourse") != null:
		return

	var course := Node3D.new()
	course.name = "ObstacleCourse"
	add_child(course)

	_add_obstacle(course, Vector3(18.0, 7.0, -12.0), Vector3(4.5, 14.0, 4.5), Color("8a8f97"))
	_add_obstacle(course, Vector3(-22.0, 9.5, 10.0), Vector3(5.5, 19.0, 5.5), Color("787d86"))
	_add_obstacle(course, Vector3(14.0, 6.0, 28.0), Vector3(3.0, 12.0, 9.0), Color("8a8f97"))
	_add_obstacle(course, Vector3(-14.0, 8.0, -30.0), Vector3(7.0, 16.0, 3.5), Color("70757d"))

	_add_obstacle(course, Vector3(34.0, 3.0, 0.0), Vector3(2.0, 6.0, 28.0), Color("5f636a"))
	_add_obstacle(course, Vector3(-34.0, 3.0, 0.0), Vector3(2.0, 6.0, 28.0), Color("5f636a"))


func _ensure_helicopter():
	var helicopter = get_node_or_null("PlayerHelicopter")
	if helicopter == null:
		helicopter = HELICOPTER_SCENE.instantiate()
		helicopter.name = "PlayerHelicopter"
		add_child(helicopter)

	helicopter.setup(FLIGHT_TUNING)
	helicopter.global_position = Vector3(0.0, FLIGHT_TUNING.hover_altitude, 0.0)
	helicopter.mark_spawn_point()
	return helicopter


func _ensure_camera(helicopter) -> void:
	var rig = get_node_or_null("CameraRig")
	if rig == null:
		rig = CAMERA_RIG_SCENE.instantiate()
		rig.name = "CameraRig"
		add_child(rig)

	rig.configure(helicopter, FLIGHT_TUNING)


func _add_obstacle(parent: Node3D, obstacle_position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = obstacle_position
	body.collision_layer = CombatLayers.WORLD
	body.collision_mask = 0
	parent.add_child(body)

	var obstacle := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	obstacle.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.metallic = 0.05
	obstacle.material_override = material
	body.add_child(obstacle)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _ensure_enemies() -> void:
	if get_node_or_null("Enemies") != null:
		return

	var container := Node3D.new()
	container.name = "Enemies"
	add_child(container)

	for spot in SOLDIER_POSITIONS:
		var soldier := SOLDIER_SCENE.instantiate()
		container.add_child(soldier)
		soldier.global_position = Vector3(spot.x, SOLDIER_DEFINITION.body_size.y * 0.5 + 0.05, spot.y)
		soldier.setup(SOLDIER_DEFINITION)

	for spot in AAA_POSITIONS:
		var turret := AAA_SCENE.instantiate()
		container.add_child(turret)
		turret.global_position = Vector3(spot.x, AAA_DEFINITION.body_size.y * 0.5 + 0.05, spot.y)
		turret.setup(AAA_DEFINITION)


func _ensure_hud(helicopter) -> void:
	if get_node_or_null("DebugHud") != null:
		return

	var hud := DebugCombatHud.new()
	hud.name = "DebugHud"
	add_child(hud)
	hud.setup(helicopter)


func _ensure_runtime_input_map() -> void:
	_register_action("move_forward", [
		_make_key_event(KEY_W),
		_make_key_event(KEY_UP),
		_make_joy_axis_event(JOY_AXIS_LEFT_Y, -1.0)
	])
	_register_action("move_back", [
		_make_key_event(KEY_S),
		_make_key_event(KEY_DOWN),
		_make_joy_axis_event(JOY_AXIS_LEFT_Y, 1.0)
	])
	_register_action("move_left", [
		_make_key_event(KEY_A),
		_make_key_event(KEY_LEFT),
		_make_joy_axis_event(JOY_AXIS_LEFT_X, -1.0)
	])
	_register_action("move_right", [
		_make_key_event(KEY_D),
		_make_key_event(KEY_RIGHT),
		_make_joy_axis_event(JOY_AXIS_LEFT_X, 1.0)
	])
	_register_action("turn_left", [
		_make_key_event(KEY_Q),
		_make_joy_axis_event(JOY_AXIS_RIGHT_X, -1.0)
	])
	_register_action("turn_right", [
		_make_key_event(KEY_E),
		_make_joy_axis_event(JOY_AXIS_RIGHT_X, 1.0)
	])
	_register_action("fire_primary", [
		_make_key_event(KEY_SPACE),
		_make_mouse_event(MOUSE_BUTTON_LEFT),
		_make_joy_axis_event(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	])
	_register_action("fire_secondary", [
		_make_key_event(KEY_F),
		_make_mouse_event(MOUSE_BUTTON_RIGHT),
		_make_joy_axis_event(JOY_AXIS_TRIGGER_LEFT, 1.0)
	])
	_register_action("fire_special", [
		_make_key_event(KEY_R),
		_make_mouse_event(MOUSE_BUTTON_MIDDLE),
		_make_joy_button_event(JOY_BUTTON_Y)
	])
	_register_action("debug_restart", [
		_make_key_event(KEY_F5)
	])


func _register_action(action_name: String, events: Array) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	InputMap.add_action(action_name, 0.2)

	for event in events:
		InputMap.action_add_event(action_name, event)


func _make_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _make_joy_axis_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


func _make_joy_button_event(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _make_mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
