class_name SurfaceFactory
extends RefCounted

## Materiais procedurais leves para quebrar o visual "cor chapada" de estruturas
## e edificios sem depender de assets externos. Tudo aqui gera texturas pequenas
## em runtime e repete no UV do mesh.

const TEXTURE_SIZE := 96


static func make_plaster_material(base_color: Color, seed: int, uv_scale: Vector3 = Vector3(2.2, 2.2, 2.2)) -> StandardMaterial3D:
	var accent := base_color.lightened(0.08)
	var dirt := base_color.darkened(0.22)
	var texture := _make_plaster_texture(base_color, accent, dirt, seed)

	var material := _make_material(texture, 0.95, 0.02, uv_scale)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


static func make_concrete_material(base_color: Color, seed: int, uv_scale: Vector3 = Vector3(2.8, 2.8, 2.8)) -> StandardMaterial3D:
	var accent := base_color.lightened(0.06)
	var grime := base_color.darkened(0.18)
	var texture := _make_concrete_texture(base_color, accent, grime, seed)

	var material := _make_material(texture, 0.92, 0.04, uv_scale)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


static func make_metal_material(
	base_color: Color,
	seed: int,
	uv_scale: Vector3 = Vector3(2.2, 2.2, 2.2),
	metallic: float = 0.35,
	roughness: float = 0.62
) -> StandardMaterial3D:
	var accent := base_color.lightened(0.12)
	var dark := base_color.darkened(0.24)
	var texture := _make_metal_texture(base_color, accent, dark, seed)

	var material := _make_material(texture, roughness, metallic, uv_scale)
	return material


static func make_roof_material(base_color: Color, seed: int, uv_scale: Vector3 = Vector3(3.2, 3.2, 3.2)) -> StandardMaterial3D:
	var accent := base_color.lightened(0.08)
	var dust := base_color.darkened(0.14)
	var texture := _make_roof_texture(base_color, accent, dust, seed)

	var material := _make_material(texture, 0.9, 0.03, uv_scale)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


static func make_rubble_material(base_color: Color, seed: int, uv_scale: Vector3 = Vector3(2.6, 2.6, 2.6)) -> StandardMaterial3D:
	var accent := base_color.lightened(0.05)
	var dust := base_color.darkened(0.18)
	var texture := _make_concrete_texture(base_color, accent, dust, seed)

	var material := _make_material(texture, 1.0, 0.0, uv_scale)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


static func make_ground_overlay_material(
	base_color: Color,
	seed: int,
	uv_scale: Vector3 = Vector3(3.8, 3.8, 3.8),
	alpha: float = 0.84
) -> StandardMaterial3D:
	var accent := base_color.lightened(0.05)
	var dust := base_color.darkened(0.12)
	## Terra batida, NAO concreto: a textura de concreto tem juntas escuras a
	## cada 18 px que, repetidas sobre um disco de zona inteiro, viram uma grade
	## tipo waffle atravessando o chao.
	var texture := _make_dirt_texture(base_color, accent, dust, seed)

	var material := _make_material(texture, 0.98, 0.0, uv_scale)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	return material


static func make_track_overlay_material(
	base_color: Color,
	seed: int,
	uv_scale: Vector3 = Vector3(4.4, 4.4, 4.4),
	alpha: float = 0.78
) -> StandardMaterial3D:
	var accent := base_color.lightened(0.04)
	var dust := base_color.darkened(0.1)
	var texture := _make_track_texture(base_color, accent, dust, seed)

	var material := _make_material(texture, 0.98, 0.0, uv_scale)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	return material


static func make_burn_mark_material(
	base_color: Color,
	seed: int,
	uv_scale: Vector3 = Vector3(2.8, 2.8, 2.8),
	alpha: float = 0.82
) -> StandardMaterial3D:
	var accent := base_color.lightened(0.02)
	var ash := base_color.darkened(0.24)
	var texture := _make_burn_texture(base_color, accent, ash, seed)

	var material := _make_material(texture, 1.0, 0.0, uv_scale)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	return material


static func make_painted_marking_material(
	paint_color: Color,
	seed: int,
	uv_scale: Vector3 = Vector3(2.8, 2.8, 2.8),
	alpha: float = 0.95
) -> StandardMaterial3D:
	var texture := _make_marking_texture(paint_color, paint_color.lightened(0.08), paint_color.darkened(0.16), seed)

	var material := _make_material(texture, 0.92, 0.0, uv_scale)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	return material


static func _make_material(texture: Texture2D, roughness: float, metallic: float, uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = roughness
	material.metallic = metallic
	material.uv1_scale = uv_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


static func _make_plaster_texture(base: Color, accent: Color, dirt: Color, seed: int) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var fine := _hash_2d(x, y, seed)
			var coarse := _hash_2d(x / 6, y / 6, seed + 13)
			var stain := _hash_2d(x / 11, y / 9, seed + 71)
			var vertical := absf(sin((float(x) + float(seed % 17)) * 0.17))
			var seam := 0.0
			if x % 24 == 0 or y % 18 == 0:
				seam = 0.22

			var color := base.lerp(accent, 0.18 + fine * 0.18 + coarse * 0.12)
			color = color.lerp(dirt, 0.08 + stain * 0.12 + vertical * 0.05)
			color = color.darkened(seam)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


static func _make_concrete_texture(base: Color, accent: Color, grime: Color, seed: int) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var fine := _hash_2d(x, y, seed)
			var coarse := _hash_2d(x / 8, y / 8, seed + 29)
			var patch := _hash_2d(x / 16, y / 12, seed + 67)
			var seam := 0.0
			if x % 18 <= 1 or y % 18 <= 1:
				seam = 0.18

			var drip := clampf(float(y) / float(TEXTURE_SIZE) * 0.18 + _hash_2d(x / 5, y / 10, seed + 101) * 0.07, 0.0, 0.28)
			var color := base.lerp(accent, 0.16 + fine * 0.14 + coarse * 0.12)
			color = color.lerp(grime, patch * 0.18 + drip)
			color = color.darkened(seam)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


## Terra batida sem juntas: so manchas organicas em tres escalas.
static func _make_dirt_texture(base: Color, accent: Color, grime: Color, seed: int) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var fine := _hash_2d(x, y, seed)
			var coarse := _hash_2d(x / 7, y / 7, seed + 29)
			var patch := _hash_2d(x / 19, y / 15, seed + 67)

			var color := base.lerp(accent, 0.14 + fine * 0.12 + coarse * 0.16)
			color = color.lerp(grime, patch * 0.22)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


static func _make_metal_texture(base: Color, accent: Color, dark: Color, seed: int) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var fine := _hash_2d(x, y, seed)
			var coarse := _hash_2d(x / 7, y / 7, seed + 17)
			var brushed := 0.5 + 0.5 * sin((float(x) + float(seed % 31)) * 0.42)
			var panel := 0.0
			if x % 20 <= 1 or y % 14 == 0:
				panel = 0.24

			var grime := _hash_2d(x / 9, y / 5, seed + 93) * 0.15
			var color := base.lerp(accent, 0.1 + brushed * 0.12 + fine * 0.08 + coarse * 0.06)
			color = color.lerp(dark, panel + grime)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


static func _make_roof_texture(base: Color, accent: Color, dust: Color, seed: int) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var corrugation := 0.5 + 0.5 * sin((float(x) + float(seed % 23)) * 0.58)
			var dust_noise := _hash_2d(x / 6, y / 6, seed + 41)
			var grain := _hash_2d(x, y, seed + 77)
			var seam := 0.0
			if x % 12 == 0:
				seam = 0.18

			var color := base.lerp(accent, 0.08 + corrugation * 0.14 + grain * 0.06)
			color = color.lerp(dust, 0.08 + dust_noise * 0.14 + seam)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


static func _make_track_texture(base: Color, accent: Color, dust: Color, seed: int) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var lane_a := exp(-pow((float(x) - TEXTURE_SIZE * 0.28) / (TEXTURE_SIZE * 0.12), 2.0))
			var lane_b := exp(-pow((float(x) - TEXTURE_SIZE * 0.72) / (TEXTURE_SIZE * 0.12), 2.0))
			var streak := maxf(lane_a, lane_b)
			var wear := _hash_2d(x / 4, y / 6, seed + 33)
			var break_up := _hash_2d(x / 10, y / 12, seed + 51)
			var alpha := clampf(streak * (0.45 + wear * 0.45) * (0.72 + break_up * 0.28), 0.0, 1.0)

			var color := base.lerp(accent, wear * 0.18)
			color = color.lerp(dust, break_up * 0.24)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	return ImageTexture.create_from_image(image)


static func _make_burn_texture(base: Color, accent: Color, ash: Color, seed: int) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE, TEXTURE_SIZE) * 0.5
	var radius := TEXTURE_SIZE * 0.48

	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var p := Vector2(x, y)
			var distance := p.distance_to(center) / radius
			var edge_noise := _hash_2d(x / 5, y / 5, seed + 61)
			var ring := clampf(1.0 - smoothstep(0.38 + edge_noise * 0.08, 1.0, distance), 0.0, 1.0)
			var crater := clampf(smoothstep(0.0, 0.52, distance), 0.0, 1.0)
			var alpha := ring * (0.28 + crater * 0.72)

			var color := ash.lerp(base, crater * 0.35).lerp(accent, edge_noise * 0.08)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	return ImageTexture.create_from_image(image)


static func _make_marking_texture(base: Color, accent: Color, worn: Color, seed: int) -> Texture2D:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var center_band := 1.0 - smoothstep(TEXTURE_SIZE * 0.18, TEXTURE_SIZE * 0.34, absf(float(x) - TEXTURE_SIZE * 0.5))
			var chips := _hash_2d(x / 3, y / 3, seed + 75)
			var edge := _hash_2d(x / 8, y / 8, seed + 93)
			var alpha := clampf(center_band * (0.82 + edge * 0.18) * (0.45 + chips * 0.55), 0.0, 1.0)

			var color := base.lerp(accent, edge * 0.14).lerp(worn, (1.0 - chips) * 0.18)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	return ImageTexture.create_from_image(image)


static func _hash_2d(x: int, y: int, seed: int) -> float:
	var n := int(x * 1619 + y * 31337 + seed * 6971)
	n = (n << 13) ^ n
	var hashed := 1.0 - float((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 1073741824.0
	return clampf(hashed * 0.5 + 0.5, 0.0, 1.0)
