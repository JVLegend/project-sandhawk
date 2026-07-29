class_name MissionWorld
extends Node3D

## Monta o mundo inteiro a partir dos dados da missao. Nada de layout hardcoded:
## terreno, zonas, estruturas, inimigos, resgatados e pickups saem do JSON, o que
## permite criar missao nova sem tocar em codigo.

signal player_spawned(player: PlayerHelicopter)

const FLIGHT_TUNING := preload("res://data/flight_tuning.tres")
const RESOURCE_TUNING := preload("res://data/resource_tuning.tres")
const SURFACE_FACTORY := preload("res://world/props/surface_factory.gd")
const HELICOPTER_SCENE := preload("res://actors/helicopter/player_helicopter.tscn")
const CAMERA_RIG_SCENE := preload("res://game/camera_follow_rig.tscn")
const POW_SCENE := preload("res://actors/pow/pow.tscn")
const PICKUP_SCENE := preload("res://actors/pickups/pickup.tscn")

const ENEMY_SCENES := {
	"soldier_ak": preload("res://actors/enemies/soldier_enemy.tscn"),
	"aaa_gun": preload("res://actors/enemies/aaa_turret.tscn"),
	"sam_launcher": preload("res://actors/enemies/sam_launcher.tscn"),
	"technical": preload("res://actors/enemies/technical_enemy.tscn"),
	"tank": preload("res://actors/enemies/tank_enemy.tscn"),
	"enemy_helicopter": preload("res://actors/enemies/enemy_helicopter.tscn"),
}

const ENEMY_DEFINITIONS := {
	"soldier_ak": preload("res://data/enemies/soldier_ak.tres"),
	"aaa_gun": preload("res://data/enemies/aaa_gun.tres"),
	"sam_launcher": preload("res://data/enemies/sam_launcher.tres"),
	"technical": preload("res://data/enemies/technical.tres"),
	"tank": preload("res://data/enemies/tank.tres"),
	"enemy_helicopter": preload("res://data/enemies/enemy_helicopter.tres"),
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
	_build_horizon(world_data)
	_build_atmospherics(world_data)
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
	environment.set("glow_levels/2", 0.78)
	environment.set("glow_levels/3", 0.22)

	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.1
	environment.ssao_light_affect = 0.12
	## SSIL fica DESLIGADO por medicao, nao por gosto: custava 1,02 ms de um frame
	## de 6,42 ms (16%) e mudava 0,25% dos pixels. Numa cena aberta de deserto,
	## com sol direcional forte e pouca geometria para rebater luz, nao ha o que
	## ele acrescente. Ver tools/perf_probe.tscn para refazer a medicao.
	environment.ssil_enabled = false

	## SDFGI custa caro (2,02 ms) mas muda 7,66% da imagem, entao fica. Cascatas
	## reduzidas e celula maior: a camera e distante e o relevo e suave, entao
	## resolucao fina de GI e desperdicio.
	environment.sdfgi_enabled = true
	environment.sdfgi_cascades = 2
	environment.sdfgi_min_cell_size = 3.2
	environment.sdfgi_energy = 0.85
	environment.sdfgi_normal_bias = 0.65
	environment.sdfgi_probe_bias = 1.2

	## Neblina quente da distancia: da profundidade e esconde a borda do mapa.
	## Densidade baixa de proposito. Nevoa de altura fica desligada: com a camera
	## quase de cima ela cobre a cena inteira em vez de so o horizonte.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.82, 0.74, 0.58)
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.2
	## Densidades recalibradas depois de afastar a camera: com o dobro de
	## distancia ate o alvo, a densidade antiga saturava a cena inteira em marrom.
	environment.fog_density = 0.0015
	environment.fog_sky_affect = 0.12
	environment.fog_height_density = 0.0
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0022
	## O volume precisa passar do alcance visivel, senao a borda dele aparece
	## como uma faixa reta atravessando a tela.
	environment.volumetric_fog_length = 200.0
	environment.volumetric_fog_albedo = Color(0.85, 0.76, 0.62)
	environment.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	environment.volumetric_fog_detail_spread = 9.0
	environment.volumetric_fog_gi_inject = 0.35

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
	## A camera fica a ~59m do alvo e enxerga ~66m de chao, entao o fim da
	## sombra precisa passar de 125m: abaixo disso a borda da ultima cascata
	## aparece como uma faixa horizontal atravessando a tela.
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 0.7
	sun.directional_shadow_max_distance = 210.0
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

	var rim := DirectionalLight3D.new()
	rim.name = "HazeRim"
	rim.light_color = Color(0.95, 0.74, 0.52)
	rim.light_energy = 0.08
	rim.rotation_degrees = Vector3(-6.0, -118.0, 0.0)
	rim.shadow_enabled = false
	add_child(rim)


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


func _build_horizon(world_data: Dictionary) -> void:
	var container := Node3D.new()
	container.name = "Horizon"
	add_child(container)

	var map_size := float(world_data.get("size", 900.0))
	var ring_radius := map_size * 0.67
	var mesa_count := 18
	var seed := int(world_data.get("seed", 20260729))
	var material := SURFACE_FACTORY.make_rubble_material(Color(0.43, 0.35, 0.26), seed + 901, Vector3(4.4, 2.8, 4.4))

	for index in mesa_count:
		var angle := TAU * float(index) / float(mesa_count) + _rng.randf_range(-0.08, 0.08)
		var width := _rng.randf_range(34.0, 92.0)
		var depth := _rng.randf_range(42.0, 118.0)
		var height := _rng.randf_range(20.0, 52.0)
		var center := Vector3(cos(angle) * ring_radius, -2.0, sin(angle) * ring_radius)

		var mesa := Node3D.new()
		mesa.rotation.y = -angle + PI * 0.5
		container.add_child(mesa)
		mesa.position = center

		var base := MeshInstance3D.new()
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(width, height, depth)
		base.mesh = base_mesh
		base.position = Vector3(0.0, height * 0.5, 0.0)
		base.material_override = material
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesa.add_child(base)

		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(width * _rng.randf_range(0.55, 0.8), height * _rng.randf_range(0.16, 0.26), depth * _rng.randf_range(0.58, 0.84))
		cap.mesh = cap_mesh
		cap.position = Vector3(_rng.randf_range(-6.0, 6.0), height + cap_mesh.size.y * 0.42, _rng.randf_range(-8.0, 8.0))
		cap.material_override = SURFACE_FACTORY.make_concrete_material(Color(0.58, 0.47, 0.34), seed + index * 47, Vector3(3.5, 2.4, 3.5))
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesa.add_child(cap)


func _build_atmospherics(world_data: Dictionary) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "DustLayer"
	particles.amount = 180
	particles.lifetime = 14.0
	particles.preprocess = 14.0
	particles.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	particles.position = Vector3(0.0, 6.0, 0.0)
	particles.visibility_aabb = AABB(Vector3(-700.0, -4.0, -700.0), Vector3(1400.0, 30.0, 1400.0))

	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 3.4)
	particles.draw_pass_1 = quad

	var process := ParticleProcessMaterial.new()
	var half := float(world_data.get("size", 900.0)) * 0.42
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(half, 4.0, half)
	process.direction = Vector3(1.0, 0.03, 0.2)
	process.spread = 20.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.9
	process.gravity = Vector3(0.0, 0.02, 0.0)
	process.scale_min = 1.6
	process.scale_max = 3.8
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.damping_min = 0.0
	process.damping_max = 0.08

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.88, 0.78, 0.62, 0.0),
		Color(0.84, 0.72, 0.56, 0.22),
		Color(0.84, 0.72, 0.56, 0.0),
	])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	## Sem textura o quad de poeira vira um retangulo translucido de borda dura
	## atravessando a tela. A radial suave e o que transforma em nuvem de pó.
	material.albedo_texture = Vfx.get_soft_texture()
	particles.material_override = material
	add_child(particles)
	particles.emitting = true


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
	var seed := int(zone.get("id", "village").hash())

	_add_ground_patch(
		container,
		center,
		Vector2(radius * 1.25, radius * 1.1),
		SURFACE_FACTORY.make_ground_overlay_material(Color(0.63, 0.56, 0.42), seed + 11, Vector3(4.6, 4.6, 4.6), 0.88),
		0.05
	)
	_add_ground_patch(
		container,
		center,
		Vector2(radius * 0.54, radius * 0.54),
		SURFACE_FACTORY.make_ground_overlay_material(Color(0.74, 0.67, 0.51), seed + 23, Vector3(3.2, 3.2, 3.2), 0.94),
		0.07
	)

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

	for offset in [Vector2(-radius * 0.24, radius * 0.08), Vector2(radius * 0.28, -radius * 0.18)]:
		var canopy := PropFactory.make_cloth_canopy(_rng, 3.4, 2.8, Color(0.68, 0.56, 0.36))
		container.add_child(canopy)
		canopy.global_position = _ground_point(center + offset)
		canopy.rotation.y = _rng.randf_range(0.0, TAU)

		var crates := PropFactory.make_supply_crate_stack(_rng, 2, 1, 2)
		container.add_child(crates)
		crates.global_position = _ground_point(center + offset + Vector2(1.8, -1.2))


func _build_outpost(container: Node3D, zone: Dictionary, center: Vector2) -> void:
	var radius := float(zone.get("radius", 45.0)) * 0.8
	var segments := 8
	var seed := int(zone.get("id", "outpost").hash())

	_add_ground_patch(
		container,
		center,
		Vector2(radius * 1.12, radius * 1.12),
		SURFACE_FACTORY.make_ground_overlay_material(Color(0.44, 0.39, 0.31), seed + 31, Vector3(4.0, 4.0, 4.0), 0.9),
		0.045
	)

	for index in segments:
		if index % 3 == 0:
			continue
		var angle := TAU * float(index) / float(segments)
		var spot := center + Vector2(cos(angle), sin(angle)) * radius
		var wall := PropFactory.make_wall_segment(14.0, 2.4)
		container.add_child(wall)
		wall.global_position = _ground_point(spot)
		wall.rotation.y = -angle + PI * 0.5

	for offset in [Vector2(-radius * 0.66, -radius * 0.66), Vector2(radius * 0.66, radius * 0.66)]:
		var tower := PropFactory.make_watch_tower(_rng)
		container.add_child(tower)
		tower.global_position = _ground_point(center + offset)
		tower.rotation.y = _rng.randf_range(0.0, TAU)

	for offset in [Vector2(-radius * 0.18, 0.0), Vector2(radius * 0.24, -radius * 0.14)]:
		var crates := PropFactory.make_supply_crate_stack(_rng, 2, 2, 2)
		container.add_child(crates)
		crates.global_position = _ground_point(center + offset)

	var barrels := PropFactory.make_barrel_cluster(_rng, 4)
	container.add_child(barrels)
	barrels.global_position = _ground_point(center + Vector2(0.0, radius * 0.26))


func _build_camp(container: Node3D, zone: Dictionary, center: Vector2) -> void:
	var radius := float(zone.get("radius", 40.0)) * 0.6
	var seed := int(zone.get("id", "camp").hash())

	_add_ground_patch(
		container,
		center,
		Vector2(radius * 1.22, radius * 1.08),
		SURFACE_FACTORY.make_ground_overlay_material(Color(0.52, 0.43, 0.31), seed + 41, Vector3(4.2, 4.2, 4.2), 0.88),
		0.04
	)

	for index in int(zone.get("tents", 5)):
		var angle := TAU * float(index) / 5.0 + _rng.randf_range(-0.3, 0.3)
		var spot := center + Vector2(cos(angle), sin(angle)) * radius * _rng.randf_range(0.4, 1.0)
		var tent := PropFactory.make_house(_rng, false)
		tent.scale = Vector3(0.6, 0.55, 0.6)
		container.add_child(tent)
		tent.global_position = _ground_point(spot)

	var canopy := PropFactory.make_cloth_canopy(_rng, 4.2, 3.1, Color(0.58, 0.48, 0.31))
	container.add_child(canopy)
	canopy.global_position = _ground_point(center)
	canopy.rotation.y = _rng.randf_range(0.0, TAU)

	var crates := PropFactory.make_supply_crate_stack(_rng, 2, 2, 1)
	container.add_child(crates)
	crates.global_position = _ground_point(center + Vector2(radius * 0.22, -radius * 0.18))

	var barrels := PropFactory.make_barrel_cluster(_rng, 3)
	container.add_child(barrels)
	barrels.global_position = _ground_point(center + Vector2(-radius * 0.24, radius * 0.12))


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
	_add_base_grounding(world_data)


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
		## Aereos nascem na altitude de cruzeiro; terrestres apoiam no chao.
		var lift := definition.spawn_altitude
		if lift <= 0.0:
			lift = definition.body_size.y * 0.5 + 0.05
		enemy.global_position = ground + Vector3(0.0, lift, 0.0)
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


func _add_base_grounding(world_data: Dictionary) -> void:
	var base_center := _to_vector2(world_data.get("base", [0.0, 0.0]))
	var seed := int(base_center.x * 97.0 + base_center.y * 131.0)

	var apron := MeshInstance3D.new()
	apron.name = "BaseApron"
	var apron_mesh := CylinderMesh.new()
	apron_mesh.top_radius = 20.0
	apron_mesh.bottom_radius = 20.0
	apron_mesh.height = 0.08
	apron_mesh.radial_segments = 32
	apron.mesh = apron_mesh
	apron.position = _ground_point(base_center) + Vector3(0.0, 0.03, 0.0)
	apron.material_override = SURFACE_FACTORY.make_ground_overlay_material(Color(0.4, 0.39, 0.35), seed + 51, Vector3(4.6, 4.6, 4.6), 0.95)
	add_child(apron)

	var road := MeshInstance3D.new()
	road.name = "BaseRoad"
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(12.0, 0.06, 28.0)
	road.mesh = road_mesh
	road.position = _ground_point(base_center + Vector2(-11.0, -6.0)) + Vector3(0.0, 0.028, 0.0)
	road.rotation.y = deg_to_rad(18.0)
	road.material_override = SURFACE_FACTORY.make_ground_overlay_material(Color(0.47, 0.41, 0.31), seed + 63, Vector3(3.2, 3.2, 3.2), 0.92)
	add_child(road)


func _add_ground_patch(container: Node3D, center: Vector2, radius: Vector2, material: Material, y_offset: float = 0.03) -> void:
	var patch := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.06
	mesh.radial_segments = 28
	patch.mesh = mesh
	patch.scale = Vector3(radius.x, 1.0, radius.y)
	patch.position = _ground_point(center) + Vector3(0.0, y_offset, 0.0)
	patch.rotation.y = _rng.randf_range(0.0, TAU)
	patch.material_override = material
	container.add_child(patch)


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
