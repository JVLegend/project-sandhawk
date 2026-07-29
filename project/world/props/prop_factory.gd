class_name PropFactory
extends RefCounted

## Fabrica de cenario gerado em codigo: pedras, palmeiras, casas e muros.
## Tudo procedural e autoral, sem asset externo, seguindo a politica do repo.

const NEUTRAL_BUILDING_SCRIPT := preload("res://actors/structures/neutral_building.gd")
const SURFACE_FACTORY := preload("res://world/props/surface_factory.gd")


static func make_rock(scale_factor: float, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Rock"

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.38, 0.34).lerp(Color(0.56, 0.5, 0.43), rng.randf())
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var chunks := rng.randi_range(2, 4)
	for index in chunks:
		var chunk := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = scale_factor * rng.randf_range(0.5, 1.0)
		mesh.height = mesh.radius * rng.randf_range(1.1, 1.8)
		mesh.radial_segments = 7
		mesh.rings = 4
		chunk.mesh = mesh
		chunk.position = Vector3(
			rng.randf_range(-scale_factor, scale_factor) * 0.6,
			mesh.height * 0.22,
			rng.randf_range(-scale_factor, scale_factor) * 0.6
		)
		chunk.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
		chunk.scale = Vector3(1.0, rng.randf_range(0.5, 0.85), 1.0)
		chunk.material_override = material
		root.add_child(chunk)

	return root


static func make_palm(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Palm"

	var height := rng.randf_range(5.0, 8.0)
	var lean := rng.randf_range(-0.14, 0.14)

	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.42, 0.33, 0.22)
	trunk_material.roughness = 0.95

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = height
	trunk_mesh.radial_segments = 8
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, height * 0.5, 0.0)
	trunk.rotation = Vector3(lean, 0.0, lean * 0.7)
	trunk.material_override = trunk_material
	root.add_child(trunk)

	var frond_material := StandardMaterial3D.new()
	frond_material.albedo_color = Color(0.31, 0.42, 0.2)
	frond_material.roughness = 0.9
	frond_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var crown := Node3D.new()
	crown.position = Vector3(lean * height, height, lean * 0.7 * height)
	root.add_child(crown)

	var fronds := rng.randi_range(6, 8)
	for index in fronds:
		var frond := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.7, 0.07, rng.randf_range(2.6, 3.8))
		frond.mesh = mesh
		frond.position = Vector3(0.0, 0.0, mesh.size.z * 0.45)
		frond.material_override = frond_material

		var pivot := Node3D.new()
		pivot.rotation.y = TAU * float(index) / float(fronds) + rng.randf_range(-0.2, 0.2)
		pivot.rotation.x = rng.randf_range(0.18, 0.42)
		pivot.add_child(frond)
		crown.add_child(pivot)

	return root


static func make_house(rng: RandomNumberGenerator, neutral: bool = true) -> Node3D:
	var width := rng.randf_range(5.0, 8.5)
	var depth := rng.randf_range(5.0, 8.0)
	var height := rng.randf_range(3.0, 5.2)
	var surface_seed := int(rng.randi())

	var base_tone := Color(0.8, 0.7, 0.53) if neutral else Color(0.38, 0.38, 0.31)
	var wall_color := base_tone.lerp(Color(0.7, 0.6, 0.46), rng.randf() * 0.6)
	var roof_color := base_tone.darkened(0.28)

	if neutral:
		var building = NEUTRAL_BUILDING_SCRIPT.new()
		building.name = "CivilianHouse"
		building.setup_house(width, depth, height, wall_color, roof_color, surface_seed)
		building.rotation.y = rng.randf_range(0.0, TAU)
		return building

	var root := StaticBody3D.new()
	root.name = "House"
	root.collision_layer = CombatLayers.WORLD
	root.collision_mask = 0

	var wall_material := SURFACE_FACTORY.make_plaster_material(wall_color, surface_seed + 7, Vector3(2.4, 2.4, 2.4))

	var walls := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(width, height, depth)
	walls.mesh = wall_mesh
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	walls.material_override = wall_material
	root.add_child(walls)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = wall_mesh.size
	shape.shape = box
	shape.position = walls.position
	root.add_child(shape)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(width + 0.6, 0.4, depth + 0.6)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, height + 0.2, 0.0)

	var roof_material := SURFACE_FACTORY.make_roof_material(roof_color, surface_seed + 17, Vector3(3.2, 3.2, 3.2))
	roof.material_override = roof_material
	root.add_child(roof)

	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.0, 1.85, 0.14)
	door.mesh = door_mesh
	door.position = Vector3(0.0, 0.92, depth * 0.5 + 0.08)
	door.material_override = SURFACE_FACTORY.make_metal_material(Color(0.34, 0.27, 0.18), surface_seed + 31, Vector3(2.0, 2.0, 2.0), 0.12, 0.72)
	root.add_child(door)

	var window_material := StandardMaterial3D.new()
	window_material.albedo_color = Color(0.14, 0.17, 0.19)
	window_material.metallic = 0.16
	window_material.roughness = 0.24

	for side in [-1.0, 1.0]:
		var window := MeshInstance3D.new()
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(0.58, 0.66, 0.08)
		window.mesh = window_mesh
		window.position = Vector3(side * width * 0.24, height * 0.56, depth * 0.5 + 0.05)
		window.material_override = window_material
		root.add_child(window)

	root.rotation.y = rng.randf_range(0.0, TAU)
	return root


static func make_wall_segment(length: float, height: float) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Wall"
	root.collision_layer = CombatLayers.WORLD
	root.collision_mask = 0

	var material := SURFACE_FACTORY.make_concrete_material(Color(0.38, 0.36, 0.3), int(length * 53.0 + height * 97.0), Vector3(2.0, 2.2, 2.0))

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, height, 1.0)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, height * 0.5, 0.0)
	mesh_instance.material_override = material
	root.add_child(mesh_instance)

	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(length + 0.5, 0.22, 1.4)
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, height + 0.12, 0.0)
	cap.material_override = SURFACE_FACTORY.make_concrete_material(Color(0.52, 0.48, 0.39), int(length * 113.0 + height * 149.0), Vector3(2.2, 2.2, 2.2))
	root.add_child(cap)

	for side in [-1.0, 1.0]:
		var buttress := MeshInstance3D.new()
		var buttress_mesh := BoxMesh.new()
		buttress_mesh.size = Vector3(1.3, height * 0.86, 1.4)
		buttress.mesh = buttress_mesh
		buttress.position = Vector3(side * (length * 0.36), buttress_mesh.size.y * 0.5, 0.0)
		buttress.material_override = material
		root.add_child(buttress)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	shape.position = mesh_instance.position
	root.add_child(shape)

	return root


static func make_dead_tree(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "DeadTree"

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.27, 0.21)
	material.roughness = 1.0

	var height := rng.randf_range(2.6, 4.2)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.09
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = height
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, height * 0.5, 0.0)
	trunk.material_override = material
	root.add_child(trunk)

	for index in rng.randi_range(2, 4):
		var branch := MeshInstance3D.new()
		var branch_mesh := CylinderMesh.new()
		branch_mesh.top_radius = 0.04
		branch_mesh.bottom_radius = 0.1
		branch_mesh.height = rng.randf_range(1.0, 1.8)
		branch_mesh.radial_segments = 5
		branch.mesh = branch_mesh
		branch.position = Vector3(0.0, height * rng.randf_range(0.55, 0.92), 0.0)
		branch.rotation = Vector3(rng.randf_range(0.5, 1.1), rng.randf_range(0.0, TAU), 0.0)
		branch.material_override = material
		root.add_child(branch)

	return root


static func make_supply_crate_stack(rng: RandomNumberGenerator, columns: int = 2, rows: int = 2, levels: int = 2) -> Node3D:
	var root := Node3D.new()
	root.name = "CrateStack"

	var material := SURFACE_FACTORY.make_plaster_material(
		Color(0.47, 0.39, 0.26).lerp(Color(0.56, 0.46, 0.31), rng.randf() * 0.4),
		int(rng.randi()),
		Vector3(2.6, 2.6, 2.6)
	)

	var spacing := 1.12
	for level in levels:
		for row in rows:
			for column in columns:
				if level > 0 and rng.randf() < 0.22:
					continue
				var crate := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.92, 0.92, 0.92)
				crate.mesh = mesh
				crate.position = Vector3(
					(float(column) - float(columns - 1) * 0.5) * spacing,
					0.46 + float(level) * 0.96,
					(float(row) - float(rows - 1) * 0.5) * spacing
				)
				crate.rotation.y = rng.randf_range(-0.05, 0.05)
				crate.material_override = material
				root.add_child(crate)

	return root


static func make_barrel_cluster(rng: RandomNumberGenerator, count: int = 3) -> Node3D:
	var root := Node3D.new()
	root.name = "BarrelCluster"
	var material := SURFACE_FACTORY.make_metal_material(
		Color(0.43, 0.38, 0.28).lerp(Color(0.54, 0.49, 0.38), rng.randf() * 0.35),
		int(rng.randi()),
		Vector3(2.8, 2.8, 2.8),
		0.28,
		0.62
	)

	for index in count:
		var barrel := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.34
		mesh.bottom_radius = 0.36
		mesh.height = 0.96
		mesh.radial_segments = 10
		barrel.mesh = mesh
		barrel.position = Vector3(
			rng.randf_range(-0.9, 0.9),
			0.48,
			rng.randf_range(-0.9, 0.9)
		)
		barrel.rotation.y = rng.randf_range(0.0, TAU)
		barrel.material_override = material
		root.add_child(barrel)

	return root


static func make_watch_tower(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "WatchTower"

	var wood := SURFACE_FACTORY.make_plaster_material(Color(0.47, 0.39, 0.28), int(rng.randi()), Vector3(2.2, 2.2, 2.2))
	var metal := SURFACE_FACTORY.make_metal_material(Color(0.35, 0.35, 0.33), int(rng.randi()), Vector3(2.6, 2.6, 2.6), 0.22, 0.68)
	var height := rng.randf_range(4.8, 6.8)

	for offset in [
		Vector3(-1.0, height * 0.5, -1.0),
		Vector3(1.0, height * 0.5, -1.0),
		Vector3(-1.0, height * 0.5, 1.0),
		Vector3(1.0, height * 0.5, 1.0),
	]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.22, height, 0.22)
		leg.mesh = leg_mesh
		leg.position = offset
		leg.material_override = wood
		root.add_child(leg)

	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(3.0, 0.22, 3.0)
	deck.mesh = deck_mesh
	deck.position = Vector3(0.0, height + 0.12, 0.0)
	deck.material_override = wood
	root.add_child(deck)

	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(3.0, 0.12, 0.12)
		rail.mesh = rail_mesh
		rail.position = Vector3(0.0, height + 0.76, side * 1.42)
		rail.material_override = wood
		root.add_child(rail)

		var rail_side := MeshInstance3D.new()
		var rail_side_mesh := BoxMesh.new()
		rail_side_mesh.size = Vector3(0.12, 0.12, 3.0)
		rail_side.mesh = rail_side_mesh
		rail_side.position = Vector3(side * 1.42, height + 0.76, 0.0)
		rail_side.material_override = wood
		root.add_child(rail_side)

	var ladder := MeshInstance3D.new()
	var ladder_mesh := BoxMesh.new()
	ladder_mesh.size = Vector3(0.14, height * 0.82, 0.14)
	ladder.mesh = ladder_mesh
	ladder.position = Vector3(1.18, height * 0.42, 0.0)
	ladder.material_override = metal
	root.add_child(ladder)

	return root


static func make_cloth_canopy(rng: RandomNumberGenerator, width: float = 3.2, depth: float = 2.6, cloth_color: Color = Color(0.64, 0.52, 0.34)) -> Node3D:
	var root := Node3D.new()
	root.name = "ClothCanopy"

	var pole_material := SURFACE_FACTORY.make_metal_material(Color(0.38, 0.36, 0.32), int(rng.randi()), Vector3(2.0, 2.0, 2.0), 0.14, 0.72)
	var cloth_material := SURFACE_FACTORY.make_roof_material(cloth_color, int(rng.randi()), Vector3(2.4, 2.4, 2.4))

	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.08
			pole_mesh.bottom_radius = 0.1
			pole_mesh.height = 2.6
			pole_mesh.radial_segments = 6
			pole.mesh = pole_mesh
			pole.position = Vector3(x_sign * width * 0.45, 1.3, z_sign * depth * 0.45)
			pole.material_override = pole_material
			root.add_child(pole)

	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(width, 0.12, depth)
	cloth.mesh = cloth_mesh
	cloth.position = Vector3(0.0, 2.56, 0.0)
	cloth.rotation_degrees = Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
	cloth.material_override = cloth_material
	root.add_child(cloth)

	return root


static func make_sandbag_barricade(length: int, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "SandbagBarricade"
	var material := SURFACE_FACTORY.make_plaster_material(Color(0.68, 0.61, 0.45), int(rng.randi()), Vector3(2.2, 2.2, 2.2))

	for index in length:
		var bag := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.38
		mesh.height = 0.54
		mesh.radial_segments = 8
		mesh.rings = 4
		bag.mesh = mesh
		bag.scale = Vector3(1.32, 0.82, 0.88)
		bag.position = Vector3((float(index) - float(length - 1) * 0.5) * 0.72, 0.22, rng.randf_range(-0.08, 0.08))
		bag.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.14, 0.14), rng.randf_range(-0.08, 0.08))
		bag.material_override = material
		root.add_child(bag)

	return root


static func make_signal_post(rng: RandomNumberGenerator, flag_color: Color = Color(0.78, 0.16, 0.12), height: float = 4.6) -> Node3D:
	var root := Node3D.new()
	root.name = "SignalPost"

	var pole_material := SURFACE_FACTORY.make_metal_material(Color(0.36, 0.36, 0.34), int(rng.randi()), Vector3(2.8, 2.8, 2.8), 0.24, 0.68)
	var flag_material := SURFACE_FACTORY.make_roof_material(flag_color, int(rng.randi()), Vector3(2.0, 2.0, 2.0))

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = height
	pole_mesh.radial_segments = 6
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, height * 0.5, 0.0)
	pole.material_override = pole_material
	root.add_child(pole)

	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(1.45, 0.08, 0.08)
	arm.mesh = arm_mesh
	arm.position = Vector3(0.68, height - 0.18, 0.0)
	arm.material_override = pole_material
	root.add_child(arm)

	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(1.15, 0.6, 0.06)
	flag.mesh = flag_mesh
	flag.position = Vector3(1.18, height - 0.52, 0.0)
	flag.rotation_degrees = Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-10.0, 10.0))
	flag.material_override = flag_material
	root.add_child(flag)

	return root


static func make_generator(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Generator"

	var body_material := SURFACE_FACTORY.make_metal_material(Color(0.46, 0.49, 0.36), int(rng.randi()), Vector3(2.2, 2.2, 2.2), 0.18, 0.72)
	var dark_material := SURFACE_FACTORY.make_metal_material(Color(0.22, 0.23, 0.22), int(rng.randi()), Vector3(2.2, 2.2, 2.2), 0.18, 0.78)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.2, 1.35, 1.26)
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.68, 0.0)
	body.material_override = body_material
	root.add_child(body)

	for side in [-1.0, 1.0]:
		var vent := MeshInstance3D.new()
		var vent_mesh := BoxMesh.new()
		vent_mesh.size = Vector3(0.1, 0.82, 0.82)
		vent.mesh = vent_mesh
		vent.position = Vector3(side * 1.12, 0.72, 0.0)
		vent.material_override = dark_material
		root.add_child(vent)

	var exhaust := MeshInstance3D.new()
	var exhaust_mesh := CylinderMesh.new()
	exhaust_mesh.top_radius = 0.1
	exhaust_mesh.bottom_radius = 0.12
	exhaust_mesh.height = 0.9
	exhaust_mesh.radial_segments = 6
	exhaust.mesh = exhaust_mesh
	exhaust.position = Vector3(-0.64, 1.76, -0.22)
	exhaust.material_override = dark_material
	root.add_child(exhaust)

	return root


static func make_radar_dish(rng: RandomNumberGenerator, mast_height: float = 3.8) -> Node3D:
	var root := Node3D.new()
	root.name = "RadarDish"

	var mast_material := SURFACE_FACTORY.make_metal_material(Color(0.42, 0.43, 0.4), int(rng.randi()), Vector3(2.8, 2.8, 2.8), 0.26, 0.62)
	var dish_material := SURFACE_FACTORY.make_metal_material(Color(0.56, 0.57, 0.53), int(rng.randi()), Vector3(3.0, 3.0, 3.0), 0.18, 0.54)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.7
	base_mesh.bottom_radius = 0.82
	base_mesh.height = 0.46
	base_mesh.radial_segments = 10
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.23, 0.0)
	base.material_override = mast_material
	root.add_child(base)

	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.12
	mast_mesh.bottom_radius = 0.16
	mast_mesh.height = mast_height
	mast_mesh.radial_segments = 8
	mast.mesh = mast_mesh
	mast.position = Vector3(0.0, 0.46 + mast_height * 0.5, 0.0)
	mast.material_override = mast_material
	root.add_child(mast)

	var arm_pivot := Node3D.new()
	arm_pivot.position = Vector3(0.0, mast_height + 0.38, 0.0)
	arm_pivot.rotation_degrees = Vector3(rng.randf_range(-18.0, -8.0), rng.randf_range(0.0, 360.0), 0.0)
	root.add_child(arm_pivot)

	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.16, 0.16, 1.5)
	arm.mesh = arm_mesh
	arm.position = Vector3(0.0, 0.0, 0.72)
	arm.material_override = mast_material
	arm_pivot.add_child(arm)

	var dish := MeshInstance3D.new()
	var dish_mesh := SphereMesh.new()
	dish_mesh.radius = 1.28
	dish_mesh.height = 0.42
	dish_mesh.radial_segments = 14
	dish_mesh.rings = 6
	dish.mesh = dish_mesh
	dish.position = Vector3(0.0, 0.0, 1.66)
	dish.rotation_degrees = Vector3(-78.0, 0.0, 0.0)
	dish.scale = Vector3(1.0, 0.32, 1.0)
	dish.material_override = dish_material
	arm_pivot.add_child(dish)

	var feed := MeshInstance3D.new()
	var feed_mesh := BoxMesh.new()
	feed_mesh.size = Vector3(0.14, 0.14, 0.5)
	feed.mesh = feed_mesh
	feed.position = Vector3(0.0, 0.0, 1.24)
	feed.material_override = mast_material
	arm_pivot.add_child(feed)

	return root


static func make_fuel_tank_rack(rng: RandomNumberGenerator, tank_count: int = 2) -> Node3D:
	var root := Node3D.new()
	root.name = "FuelTankRack"

	var rack_material := SURFACE_FACTORY.make_metal_material(Color(0.34, 0.33, 0.31), int(rng.randi()), Vector3(2.4, 2.4, 2.4), 0.24, 0.7)
	var tank_material := SURFACE_FACTORY.make_metal_material(Color(0.54, 0.5, 0.38), int(rng.randi()), Vector3(2.8, 2.8, 2.8), 0.2, 0.58)

	var spacing := 2.35
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.16, 0.92, 0.16)
			leg.mesh = leg_mesh
			leg.position = Vector3(x_sign * (float(tank_count - 1) * spacing * 0.5 + 0.68), 0.46, z_sign * 0.76)
			leg.material_override = rack_material
			root.add_child(leg)

	for index in tank_count:
		var x_offset := (float(index) - float(tank_count - 1) * 0.5) * spacing

		var support := MeshInstance3D.new()
		var support_mesh := BoxMesh.new()
		support_mesh.size = Vector3(1.58, 0.14, 1.72)
		support.mesh = support_mesh
		support.position = Vector3(x_offset, 1.02, 0.0)
		support.material_override = rack_material
		root.add_child(support)

		var tank := MeshInstance3D.new()
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = 0.58
		tank_mesh.bottom_radius = 0.58
		tank_mesh.height = 1.72
		tank_mesh.radial_segments = 12
		tank.mesh = tank_mesh
		tank.position = Vector3(x_offset, 1.68, 0.0)
		tank.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		tank.material_override = tank_material
		root.add_child(tank)

	return root
