class_name Vegetation
extends Node3D

## Vegetacao rasteira do deserto: tufos de capim seco e arbustos de espinho.
##
## Tudo em MultiMesh: milhares de instancias custam UM draw call por tipo, entao
## da para encher o mapa sem tocar no orcamento de frame. A distribuicao usa
## ruido de aglomeracao em vez de aleatorio uniforme: capim de verdade cresce
## em manchas onde ha agua, nao espalhado como confete.

const GRASS_BLADES := 3

var _cluster_noise: FastNoiseLite


## sampler_height: Callable(x, z) -> float, para apoiar cada tufo no relevo.
## keep_out: lista de {"position": Vector2, "radius": float} onde nada cresce.
func generate(
	map_size: float,
	seed_value: int,
	grass_count: int,
	bush_count: int,
	sampler_height: Callable,
	keep_out: Array
) -> void:
	_cluster_noise = FastNoiseLite.new()
	_cluster_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cluster_noise.seed = seed_value + 3301
	_cluster_noise.frequency = 0.011

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 77

	_scatter(
		"Grass",
		_make_grass_mesh(),
		_make_plant_material(),
		grass_count,
		map_size,
		rng,
		sampler_height,
		keep_out,
		Color(0.62, 0.55, 0.3),
		Color(0.45, 0.48, 0.22),
		Vector2(0.7, 1.5)
	)

	_scatter(
		"Bushes",
		_make_bush_mesh(),
		_make_plant_material(),
		bush_count,
		map_size,
		rng,
		sampler_height,
		keep_out,
		Color(0.35, 0.38, 0.2),
		Color(0.42, 0.34, 0.2),
		Vector2(0.8, 1.7)
	)


func _scatter(
	node_name: String,
	mesh: Mesh,
	material: Material,
	count: int,
	map_size: float,
	rng: RandomNumberGenerator,
	sampler_height: Callable,
	keep_out: Array,
	color_a: Color,
	color_b: Color,
	scale_range: Vector2
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count

	var half := map_size * 0.46
	var placed := 0
	var attempts := 0
	var max_attempts := count * 14

	while placed < count and attempts < max_attempts:
		attempts += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)

		## Ruido decide onde ha "umidade": rejeita a maior parte do deserto
		## aberto e concentra a vegetacao em manchas.
		var cluster := _cluster_noise.get_noise_2d(x, z)
		if cluster < 0.08 or rng.randf() > (cluster + 0.25):
			continue

		if _inside_keep_out(Vector2(x, z), keep_out):
			continue

		var y := float(sampler_height.call(x, z))
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var scale := rng.randf_range(scale_range.x, scale_range.y)
		basis = basis.scaled(Vector3(scale, scale * rng.randf_range(0.85, 1.25), scale))

		multimesh.set_instance_transform(placed, Transform3D(basis, Vector3(x, y, z)))
		multimesh.set_instance_color(placed, color_a.lerp(color_b, rng.randf()).darkened(rng.randf() * 0.18))
		placed += 1

	## Rejeicao por ruido pode nao preencher tudo: encolhe para o que existe.
	multimesh.instance_count = placed
	multimesh.visible_instance_count = placed

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _inside_keep_out(point: Vector2, keep_out: Array) -> bool:
	for zone in keep_out:
		var center: Vector2 = zone["position"]
		if point.distance_to(center) < float(zone["radius"]):
			return true
	return false


## Tufo: laminas cruzadas com base larga e topo estreito, dobradas pelo vento.
func _make_grass_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for blade in GRASS_BLADES:
		var angle := TAU * float(blade) / float(GRASS_BLADES)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var lean := direction * 0.22

		var base_half := direction.cross(Vector3.UP) * 0.16
		var top_half := base_half * 0.25
		var height := 0.55

		var start := vertices.size()
		vertices.append(-base_half)
		vertices.append(base_half)
		vertices.append(top_half + Vector3.UP * height + lean)
		vertices.append(-top_half + Vector3.UP * height + lean)

		for _i in 4:
			normals.append(Vector3.UP)

		## Base escura, ponta clara: gradiente de planta seca sem textura.
		colors.append(Color(0.55, 0.5, 0.42))
		colors.append(Color(0.55, 0.5, 0.42))
		colors.append(Color(1.18, 1.12, 0.92))
		colors.append(Color(1.18, 1.12, 0.92))

		indices.append_array(PackedInt32Array([
			start, start + 2, start + 1,
			start, start + 3, start + 2,
		]))

	return _build_mesh(vertices, normals, colors, indices)


## Arbusto: aglomerado de losangos achatados, silhueta de espinheiro.
func _make_bush_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var lobes := [
		[Vector3(0.0, 0.3, 0.0), 0.5],
		[Vector3(0.32, 0.22, 0.14), 0.34],
		[Vector3(-0.28, 0.2, -0.18), 0.38],
		[Vector3(0.06, 0.18, -0.34), 0.3],
	]

	for lobe in lobes:
		var center: Vector3 = lobe[0]
		var radius: float = lobe[1]

		## Octaedro achatado por lobo: barato e le como folhagem densa.
		var top := center + Vector3.UP * radius * 0.7
		var bottom := center - Vector3.UP * radius * 0.45
		var ring := [
			center + Vector3(radius, 0.0, 0.0),
			center + Vector3(0.0, 0.0, radius),
			center + Vector3(-radius, 0.0, 0.0),
			center + Vector3(0.0, 0.0, -radius),
		]

		var start := vertices.size()
		vertices.append(top)
		for point in ring:
			vertices.append(point)
		vertices.append(bottom)

		for index in 6:
			normals.append(Vector3.UP)
			colors.append(Color(1.0, 1.0, 1.0) if index == 0 else Color(0.72, 0.7, 0.62))

		for index in 4:
			var next := (index + 1) % 4
			indices.append_array(PackedInt32Array([
				start, start + 1 + next, start + 1 + index,
				start + 5, start + 1 + index, start + 1 + next,
			]))

	return _build_mesh(vertices, normals, colors, indices)


func _make_plant_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	## Laminas sao planas: sem cull as duas faces aparecem.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_mesh(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
