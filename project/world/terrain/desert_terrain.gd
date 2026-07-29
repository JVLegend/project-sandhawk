class_name DesertTerrain
extends Node3D

## Terreno de deserto gerado em codigo: duna, cascalho e leito de rocha a partir
## de ruido, com cor por vertice em vez de textura. Zero asset externo, e a
## silhueta ja da a leitura de deserto que o grid cinza nao dava.
##
## A colisao continua sendo um plano no y=0: o relevo e visual e as unidades
## terrestres vivem em zonas achatadas, entao nao ha descompasso perceptivel.

const SAND_SHADER := preload("res://world/terrain/desert_sand.gdshader")
const SAND_COLOR_TEXTURE := preload("res://assets/textures/sand_color.jpg")
const SAND_NORMAL_TEXTURE := preload("res://assets/textures/sand_normal.jpg")
const SAND_ROUGHNESS_TEXTURE := preload("res://assets/textures/sand_roughness.jpg")

const SAND_LOW := Color(0.55, 0.44, 0.29)
const SAND_HIGH := Color(0.74, 0.63, 0.43)
const ROCK := Color(0.33, 0.29, 0.26)
const GRAVEL := Color(0.44, 0.38, 0.3)
const CLAY := Color(0.5, 0.34, 0.23)

var size := 900.0
var resolution := 220
var amplitude := 5.0

var _noise_base: FastNoiseLite
var _noise_detail: FastNoiseLite
var _flat_spots: Array = []


## flat_spots: lista de {"position": Vector2, "radius": float}
func generate(p_size: float, p_amplitude: float, flat_spots: Array, seed_value: int = 20260729) -> void:
	size = p_size
	amplitude = p_amplitude
	_flat_spots = flat_spots

	_noise_base = FastNoiseLite.new()
	_noise_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_base.seed = seed_value
	_noise_base.frequency = 0.0032
	_noise_base.fractal_octaves = 3

	_noise_detail = FastNoiseLite.new()
	_noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_detail.seed = seed_value + 17
	_noise_detail.frequency = 0.014
	_noise_detail.fractal_octaves = 2

	_build_mesh()
	_build_collision()


func sample_height(x: float, z: float) -> float:
	if _noise_base == null:
		return 0.0

	var dune := _noise_base.get_noise_2d(x, z) * amplitude
	var detail := _noise_detail.get_noise_2d(x, z) * amplitude * 0.22
	return (dune + detail) * _flatten_factor(x, z)


func sample_normal(x: float, z: float) -> Vector3:
	var step := 1.5
	var left := sample_height(x - step, z)
	var right := sample_height(x + step, z)
	var back := sample_height(x, z - step)
	var front := sample_height(x, z + step)

	return Vector3(left - right, 2.0 * step, back - front).normalized()


## Zonas de jogo ficam planas: base, campos e vila precisam de chao previsivel.
func _flatten_factor(x: float, z: float) -> float:
	var factor := 1.0

	for spot in _flat_spots:
		var center: Vector2 = spot["position"]
		var radius: float = spot["radius"]
		var falloff: float = spot.get("falloff", 26.0)
		var distance := Vector2(x, z).distance_to(center)
		var local_factor := smoothstep(radius, radius + falloff, distance)
		factor = minf(factor, local_factor)

	return factor


func _build_mesh() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var step := size / float(resolution)
	var half := size * 0.5
	var line := resolution + 1

	for row in range(line):
		for column in range(line):
			var x := -half + float(column) * step
			var z := -half + float(row) * step
			var height := sample_height(x, z)
			var normal := sample_normal(x, z)

			vertices.append(Vector3(x, height, z))
			normals.append(normal)
			colors.append(_color_for(height, normal, x, z))

	for row in range(resolution):
		for column in range(resolution):
			var top_left := row * line + column
			var top_right := top_left + 1
			var bottom_left := top_left + line
			var bottom_right := bottom_left + 1

			## Winding horario visto de cima. Invertido, o terreno inteiro some por
			## backface culling e sobra so a esfera do ceu.
			indices.append(top_left)
			indices.append(top_right)
			indices.append(bottom_left)

			indices.append(top_right)
			indices.append(bottom_right)
			indices.append(bottom_left)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := ShaderMaterial.new()
	material.shader = SAND_SHADER
	material.set_shader_parameter("sand_color", SAND_COLOR_TEXTURE)
	material.set_shader_parameter("sand_normal", SAND_NORMAL_TEXTURE)
	material.set_shader_parameter("sand_roughness", SAND_ROUGHNESS_TEXTURE)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)


func _color_for(height: float, normal: Vector3, x: float, z: float) -> Color:
	var slope := 1.0 - clampf(normal.y, 0.0, 1.0)
	var elevation := clampf(inverse_lerp(-amplitude * 0.9, amplitude * 0.9, height), 0.0, 1.0)

	var color := SAND_LOW.lerp(SAND_HIGH, elevation)

	## Encosta ingreme vira rocha exposta.
	color = color.lerp(ROCK, clampf(slope * 5.5, 0.0, 0.85))

	## Manchas de terreno de ~50m. Independem da altura, entao as zonas achatadas
	## tambem ganham variacao em vez de virar um lencol de areia uniforme.
	var region := _noise_base.get_noise_2d(x * 6.0 - 900.0, z * 6.0 + 640.0)
	color = color.lerp(CLAY, clampf(region * 0.6 + 0.22, 0.0, 0.45))

	## Cascalho fino: quebra a uniformidade de perto.
	var patch := _noise_detail.get_noise_2d(x * 2.6 + 500.0, z * 2.6 - 320.0)
	color = color.lerp(GRAVEL, clampf(patch * 0.5 + 0.16, 0.0, 0.36))

	## Escurece levemente as depressoes: oclusao barata que da volume as dunas.
	color = color.darkened(clampf((1.0 - elevation) * 0.16, 0.0, 0.16))

	return color


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = CombatLayers.WORLD
	body.collision_mask = 0
	add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	body.add_child(shape)
