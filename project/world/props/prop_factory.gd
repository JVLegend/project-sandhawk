class_name PropFactory
extends RefCounted

## Fabrica de cenario gerado em codigo: pedras, palmeiras, casas e muros.
## Tudo procedural e autoral, sem asset externo, seguindo a politica do repo.


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
	var root := StaticBody3D.new()
	root.name = "House"
	root.collision_layer = CombatLayers.WORLD
	root.collision_mask = 0

	var width := rng.randf_range(5.0, 8.5)
	var depth := rng.randf_range(5.0, 8.0)
	var height := rng.randf_range(3.0, 5.2)

	var wall_material := StandardMaterial3D.new()
	var base_tone := Color(0.8, 0.7, 0.53) if neutral else Color(0.38, 0.38, 0.31)
	wall_material.albedo_color = base_tone.lerp(Color(0.7, 0.6, 0.46), rng.randf() * 0.6)
	wall_material.roughness = 0.96

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

	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = base_tone.darkened(0.28)
	roof_material.roughness = 0.98
	roof.material_override = roof_material
	root.add_child(roof)

	root.rotation.y = rng.randf_range(0.0, TAU)
	return root


static func make_wall_segment(length: float, height: float) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Wall"
	root.collision_layer = CombatLayers.WORLD
	root.collision_mask = 0

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.36, 0.3)
	material.roughness = 0.97

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, height, 1.0)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, height * 0.5, 0.0)
	mesh_instance.material_override = material
	root.add_child(mesh_instance)

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
