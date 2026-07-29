class_name MissionWorld
extends Node3D

## Monta o mundo inteiro a partir dos dados da missao. Nada de layout hardcoded:
## terreno, zonas, estruturas, inimigos, resgatados e pickups saem do JSON, o que
## permite criar missao nova sem tocar em codigo.

signal player_spawned(player: PlayerHelicopter)

const FLIGHT_TUNING := preload("res://data/flight_tuning.tres")
const RESOURCE_TUNING := preload("res://data/resource_tuning.tres")
const HELICOPTER_SCENE := preload("res://actors/helicopter/player_helicopter.tscn")
const CAMERA_RIG_SCENE := preload("res://game/camera_follow_rig.tscn")
const POW_SCENE := preload("res://actors/pow/pow.tscn")
const PICKUP_SCENE := preload("res://actors/pickups/pickup.tscn")

const ENEMY_SCENES := {
	"soldier_ak": preload("res://actors/enemies/soldier_enemy.tscn"),
	"aaa_gun": preload("res://actors/enemies/aaa_turret.tscn"),
	"sam_launcher": preload("res://actors/enemies/sam_launcher.tscn"),
}

const ENEMY_DEFINITIONS := {
	"soldier_ak": preload("res://data/enemies/soldier_ak.tres"),
	"aaa_gun": preload("res://data/enemies/aaa_gun.tres"),
	"sam_launcher": preload("res://data/enemies/sam_launcher.tres"),
}

var terrain: DesertTerrain
var base: FriendlyBase
var player: PlayerHelicopter
var camera_rig: CameraFollowRig

var _rng := RandomNumberGenerator.new()
var _zones: Array = []


func build(world_data: Dictionary) -> void:
	_rng.seed = int(world_data.get("seed", 20260729))

	_build_environment()
	_build_sun()
	_build_terrain(world_data)
	_build_zones(world_data)
	_build_scatter(world_data)
	_build_base(world_data)
	_build_structures(world_data)
	_build_enemies(world_data)
	_build_rescue_targets(world_data)
	_build_pickups(world_data)
	_build_player(world_data)


func height_at(x: float, z: float) -> float:
	if terrain == null:
		return 0.0
	return terrain.sample_height(x, z)


func find_zone(zone_id: String) -> Dictionary:
	for zone in _zones:
		if str(zone.get("id", "")) == zone_id:
			return zone
	return {}


## ---------------------------------------------------------------- ambiente

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.31, 0.52, 0.78)
	sky_material.sky_horizon_color = Color(0.85, 0.78, 0.62)
	sky_material.sky_curve = 0.15
	sky_material.ground_bottom_color = Color(0.5, 0.42, 0.3)
	sky_material.ground_horizon_color = Color(0.82, 0.74, 0.58)
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.08

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.5
	environment.ambient_light_energy = 0.45

	## Tonemap filmico: sem isso o deserto estoura em branco no sol forte.
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.86
	environment.tonemap_white = 6.0

	environment.glow_enabled = true
	environment.glow_intensity = 0.32
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.1
	environment.ssao_light_affect = 0.12

	## Neblina quente da distancia: da profundidade e esconde a borda do mapa.
	## Densidade baixa de proposito. Nevoa de altura fica desligada: com a camera
	## quase de cima ela cobre a cena inteira em vez de so o horizonte.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.82, 0.74, 0.58)
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.2
	environment.fog_density = 0.0026
	environment.fog_sky_affect = 0.12
	environment.fog_height_density = 0.0

	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 1.16

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-48.0, 34.0, 0.0)
	sun.shadow_enabled = true
	## A camera so enxerga ~40m de chao: cascatas curtas dao sombra nitida
	## e eliminam o chuvisco de shadow acne no deserto plano.
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 0.7
	sun.directional_shadow_max_distance = 85.0
	sun.directional_shadow_split_1 = 0.12
	sun.directional_shadow_split_2 = 0.3
	sun.directional_shadow_split_3 = 0.6
	## Sombra levemente suave: sol de deserto nao tem borda de navalha.
	sun.light_angular_distance = 0.9
	add_child(sun)

	var bounce := DirectionalLight3D.new()
	bounce.name = "BounceFill"
	bounce.light_color = Color(0.66, 0.6, 0.52)
	bounce.light_energy = 0.28
	bounce.rotation_degrees = Vector3(28.0, -140.0, 0.0)
	bounce.shadow_enabled = false
	add_child(bounce)


## ---------------------------------------------------------------- terreno

func _build_terrain(world_data: Dictionary) -> void:
	var flat_spots: Array = []

	var base_position := _to_vector2(world_data.get("base", [0.0, 0.0]))
	flat_spots.append({"position": base_position, "radius": 26.0, "falloff": 30.0})

	for zone in world_data.get("zones", []):
		flat_spots.append({
			"position": _to_vector2(zone.get("position", [0.0, 0.0])),
			"radius": float(zone.get("radius", 40.0)) * 0.75,
			"falloff": float(zone.get("radius", 40.0)) * 0.7,
		})

	terrain = DesertTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate(
		float(world_data.get("size", 900.0)),
		float(world_data.get("amplitude", 5.0)),
		flat_spots,
		int(world_data.get("seed", 20260729))
	)


## ---------------------------------------------------------------- zonas

func _build_zones(world_data: Dictionary) -> void:
	_zones = world_data.get("zones", [])

	var container := Node3D.new()
	container.name = "Zones"
	add_child(container)

	for zone in _zones:
		var kind := str(zone.get("kind", ""))
		var center := _to_vector2(zone.get("position", [0.0, 0.0]))

		match kind:
			"village":
				_build_village(container, zone, center)
			"outpost":
				_build_outpost(container, zone, center)
			"camp":
				_build_camp(container, zone, center)


func _build_village(container: Node3D, zone: Dictionary, center: Vector2) -> void:
	var radius := float(zone.get("radius", 45.0)) * 0.68
	var houses := int(zone.get("houses", 8))

	for index in houses:
		var angle := TAU * float(index) / float(houses) + _rng.randf_range(-0.25, 0.25)
		var distance := radius * _rng.randf_range(0.28, 1.0)
		var spot := center + Vector2(cos(angle), sin(angle)) * distance
		var house := PropFactory.make_house(_rng, true)
		container.add_child(house)
		house.global_position = _ground_point(spot)

	for index in int(zone.get("palms", 8)):
		var angle := _rng.randf_range(0.0, TAU)
		var spot := center + Vector2(cos(angle), sin(angle)) * radius * _rng.randf_range(0.5, 1.25)
		var palm := PropFactory.make_palm(_rng)
		container.add_child(palm)
		palm.global_position = _ground_point(spot)

	var well := PropFactory.make_rock(1.6, _rng)
	container.add_child(well)
	well.global_position = _ground_point(center)


func _build_outpost(container: Node3D, zone: Dictionary, center: Vector2) -> void:
	var radius := float(zone.get("radius", 45.0)) * 0.8
	var segments := 8

	for index in segments:
		if index % 3 == 0:
			continue
		var angle := TAU * float(index) / float(segments)
		var spot := center + Vector2(cos(angle), sin(angle)) * radius
		var wall := PropFactory.make_wall_segment(14.0, 2.4)
		container.add_child(wall)
		wall.global_position = _ground_point(spot)
		wall.rotation.y = -angle + PI * 0.5


func _build_camp(container: Node3D, zone: Dictionary, center: Vector2) -> void:
	var radius := float(zone.get("radius", 40.0)) * 0.6

	for index in int(zone.get("tents", 5)):
		var angle := TAU * float(index) / 5.0 + _rng.randf_range(-0.3, 0.3)
		var spot := center + Vector2(cos(angle), sin(angle)) * radius * _rng.randf_range(0.4, 1.0)
		var tent := PropFactory.make_house(_rng, false)
		tent.scale = Vector3(0.6, 0.55, 0.6)
		container.add_child(tent)
		tent.global_position = _ground_point(spot)


func _build_scatter(world_data: Dictionary) -> void:
	var scatter: Dictionary = world_data.get("scatter", {})
	if scatter.is_empty():
		return

	var container := Node3D.new()
	container.name = "Scatter"
	add_child(container)

	var half := float(world_data.get("size", 900.0)) * 0.44

	for index in int(scatter.get("rocks", 0)):
		var spot := Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))
		if _too_close_to_gameplay(spot, 16.0):
			continue
		var rock := PropFactory.make_rock(_rng.randf_range(0.8, 3.2), _rng)
		container.add_child(rock)
		rock.global_position = _ground_point(spot)

	for index in int(scatter.get("dead_trees", 0)):
		var spot := Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))
		if _too_close_to_gameplay(spot, 18.0):
			continue
		var tree := PropFactory.make_dead_tree(_rng)
		container.add_child(tree)
		tree.global_position = _ground_point(spot)


## ---------------------------------------------------------------- atores

func _build_base(world_data: Dictionary) -> void:
	base = FriendlyBase.new()
	base.name = "FriendlyBase"
	base.setup(RESOURCE_TUNING)
	add_child(base)
	base.global_position = _ground_point(_to_vector2(world_data.get("base", [0.0, 0.0])))


func _build_structures(world_data: Dictionary) -> void:
	var container := Node3D.new()
	container.name = "Structures"
	add_child(container)

	for entry in world_data.get("structures", []):
		var structure := Structure.new()
		container.add_child(structure)
		structure.global_position = _ground_point(_to_vector2(entry.get("position", [0.0, 0.0])))
		structure.setup(str(entry.get("id", "")), str(entry.get("kind", "radar")))


func _build_enemies(world_data: Dictionary) -> void:
	var container := Node3D.new()
	container.name = "Enemies"
	add_child(container)

	for entry in world_data.get("enemies", []):
		var kind := str(entry.get("kind", "soldier_ak"))
		if not ENEMY_SCENES.has(kind):
			push_warning("Tipo de inimigo desconhecido na missao: %s" % kind)
			continue

		var definition: EnemyDefinition = ENEMY_DEFINITIONS[kind]
		var enemy = ENEMY_SCENES[kind].instantiate()
		container.add_child(enemy)

		var spot := _to_vector2(entry.get("position", [0.0, 0.0]))
		var ground := _ground_point(spot)
		enemy.global_position = ground + Vector3(0.0, definition.body_size.y * 0.5 + 0.05, 0.0)
		enemy.setup(definition)


func _build_rescue_targets(world_data: Dictionary) -> void:
	var container := Node3D.new()
	container.name = "RescueTargets"
	add_child(container)

	for entry in world_data.get("pows", []):
		var pow_node := POW_SCENE.instantiate()
		container.add_child(pow_node)
		pow_node.global_position = _ground_point(_to_vector2(entry))


func _build_pickups(world_data: Dictionary) -> void:
	var container := Node3D.new()
	container.name = "Pickups"
	add_child(container)

	for entry in world_data.get("pickups", []):
		var pickup := PICKUP_SCENE.instantiate()
		pickup.setup(
			Pickup.type_from_name(str(entry.get("kind", "fuel"))),
			str(entry.get("id", ""))
		)
		container.add_child(pickup)
		pickup.global_position = _ground_point(_to_vector2(entry.get("position", [0.0, 0.0])))


func _build_player(world_data: Dictionary) -> void:
	var spawn := _to_vector2(world_data.get("spawn", world_data.get("base", [0.0, 0.0])))

	player = HELICOPTER_SCENE.instantiate()
	player.name = "PlayerHelicopter"
	add_child(player)
	player.setup(FLIGHT_TUNING)
	player.global_position = Vector3(spawn.x, FLIGHT_TUNING.hover_altitude, spawn.y)
	player.mark_spawn_point()

	camera_rig = CAMERA_RIG_SCENE.instantiate()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.configure(player, FLIGHT_TUNING)

	player_spawned.emit(player)


## ---------------------------------------------------------------- helpers

func _ground_point(spot: Vector2) -> Vector3:
	return Vector3(spot.x, height_at(spot.x, spot.y), spot.y)


func _too_close_to_gameplay(spot: Vector2, margin: float) -> bool:
	for zone in _zones:
		var center := _to_vector2(zone.get("position", [0.0, 0.0]))
		if spot.distance_to(center) < float(zone.get("radius", 40.0)) + margin:
			return true
	return spot.length() < 40.0 + margin


func _to_vector2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
