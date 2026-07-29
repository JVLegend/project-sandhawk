extends Node

## Autoload de efeitos visuais procedurais (Fase 4).
## Tudo aqui e gerado em codigo, sem asset externo, para manter o repo limpo de
## material proprietario. A Fase 7 substitui estes efeitos pelo pack visual final.

const SOFT_TEXTURE_SIZE := 64

var _soft_texture: ImageTexture
var _quad_mesh: QuadMesh
var _debris_mesh: BoxMesh


func _ready() -> void:
	_soft_texture = _make_soft_texture()

	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2.ONE

	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3(0.22, 0.22, 0.22)


## Textura radial suave, reaproveitada por qualquer sistema que desenhe
## particula em quad. Sem ela o quad aparece como retangulo de borda dura.
func get_soft_texture() -> ImageTexture:
	return _soft_texture


## Rastro luminoso entre dois pontos (hitscan).
func spawn_tracer(from: Vector3, to: Vector3, color: Color, width: float = 0.05) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return

	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = width
	cylinder.bottom_radius = width
	cylinder.height = length
	cylinder.radial_segments = 6
	cylinder.rings = 0
	mesh_instance.mesh = cylinder

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	mesh_instance.material_override = material

	_host().add_child(mesh_instance)
	mesh_instance.global_position = (from + to) * 0.5
	_orient_along(mesh_instance, to - from)

	var tween := mesh_instance.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(mesh_instance.queue_free)


## Clarao curto na boca da arma, preso ao no que disparou.
func spawn_muzzle_flash(parent: Node3D, local_position: Vector3, color: Color, size: float = 0.5) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	flash.mesh = sphere

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	flash.material_override = material

	parent.add_child(flash)
	flash.position = local_position

	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.35, 0.06)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.06)
	tween.chain().tween_callback(flash.queue_free)


## Faisca de impacto em superficie.
func spawn_impact(position: Vector3, normal: Vector3, color: Color) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 10
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.draw_pass_1 = _debris_mesh

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = normal
	process.spread = 55.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 8.0
	process.gravity = Vector3(0.0, -14.0, 0.0)
	process.scale_min = 0.25
	process.scale_max = 0.7
	process.color = color
	particles.process_material = process

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	particles.material_override = material

	_host().add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_free_after(particles, 1.0)


## Explosao em camadas: clarao, bola de fogo, onda de choque, fumaca e destrocos.
func spawn_explosion(position: Vector3, scale_factor: float = 1.0) -> void:
	## O som mora aqui para que nenhuma explosao possa nascer muda.
	AudioManager.play_at(
		AudioManager.Sfx.EXPLOSION_BIG if scale_factor >= 1.0 else AudioManager.Sfx.EXPLOSION_SMALL,
		position,
		clampf(-6.0 + scale_factor * 4.0, -6.0, 2.0),
		0.1
	)

	_spawn_flash_sphere(position, 1.6 * scale_factor, Color(1.0, 0.95, 0.75, 0.95), 0.14)
	_spawn_fireball(position, scale_factor)
	_spawn_shockwave(position, scale_factor)
	_spawn_smoke(position, scale_factor)
	_spawn_debris(position, scale_factor)


## Flash branco no material de um mesh atingido.
func flash_mesh(mesh_instance: MeshInstance3D, energy: float = 3.0, duration: float = 0.12) -> void:
	if mesh_instance == null or not is_instance_valid(mesh_instance):
		return

	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null:
		return

	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_energy_multiplier = energy

	var tween := mesh_instance.create_tween()
	tween.tween_property(material, "emission_energy_multiplier", 0.0, duration)


func _spawn_flash_sphere(position: Vector3, radius: float, color: Color, duration: float) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	flash.mesh = sphere

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	flash.material_override = material

	_host().add_child(flash)
	flash.global_position = position
	flash.scale = Vector3.ONE * 0.4

	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.3, duration)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(flash.queue_free)


func _spawn_fireball(position: Vector3, scale_factor: float) -> void:
	var fireball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.1 * scale_factor
	sphere.height = 2.2 * scale_factor
	sphere.radial_segments = 12
	sphere.rings = 6
	fireball.mesh = sphere

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.55, 0.16, 0.9)
	fireball.material_override = material

	_host().add_child(fireball)
	fireball.global_position = position + Vector3.UP * 0.4 * scale_factor
	fireball.scale = Vector3.ONE * 0.5

	var tween := fireball.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fireball, "scale", Vector3.ONE * 1.5, 0.32)
	tween.tween_property(fireball, "global_position:y", fireball.global_position.y + 1.4 * scale_factor, 0.32)
	tween.tween_property(material, "albedo_color", Color(0.55, 0.2, 0.08, 0.0), 0.32)
	tween.chain().tween_callback(fireball.queue_free)


func _spawn_shockwave(position: Vector3, scale_factor: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.88, 0.66, 0.55)
	ring.material_override = material

	_host().add_child(ring)
	ring.global_position = position + Vector3.UP * 0.25
	ring.scale = Vector3(0.4, 0.4, 0.4)

	var target_scale := 4.2 * scale_factor
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(target_scale, 0.6, target_scale), 0.42)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.42)
	tween.chain().tween_callback(ring.queue_free)


func _spawn_smoke(position: Vector3, scale_factor: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = int(18 * scale_factor) + 6
	particles.lifetime = 1.5
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.draw_pass_1 = _quad_mesh

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.8 * scale_factor
	process.direction = Vector3.UP
	process.spread = 35.0
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 4.5 * scale_factor
	process.gravity = Vector3(0.0, 1.1, 0.0)
	process.damping_min = 1.2
	process.damping_max = 2.4
	process.scale_min = 1.4 * scale_factor
	process.scale_max = 3.2 * scale_factor
	process.angle_min = -180.0
	process.angle_max = 180.0

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.32, 0.28, 0.25, 0.85))
	ramp.set_color(1, Color(0.55, 0.5, 0.46, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_texture
	particles.material_override = material

	_host().add_child(particles)
	particles.global_position = position + Vector3.UP * 0.5
	particles.emitting = true
	_free_after(particles, 2.6)


func _spawn_debris(position: Vector3, scale_factor: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = int(14 * scale_factor) + 4
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.draw_pass_1 = _debris_mesh

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.4
	process.direction = Vector3.UP
	process.spread = 70.0
	process.initial_velocity_min = 6.0
	process.initial_velocity_max = 15.0 * scale_factor
	process.gravity = Vector3(0.0, -22.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.5 * scale_factor
	process.angular_velocity_min = -420.0
	process.angular_velocity_max = 420.0
	process.color = Color(0.25, 0.22, 0.2)
	particles.process_material = process

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	particles.material_override = material

	_host().add_child(particles)
	particles.global_position = position + Vector3.UP * 0.3
	particles.emitting = true
	_free_after(particles, 2.0)


func _orient_along(node: Node3D, direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return

	var normalized := direction.normalized()
	var up := Vector3.UP
	if absf(normalized.dot(up)) > 0.99:
		up = Vector3.RIGHT

	node.look_at(node.global_position + normalized, up)
	node.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _free_after(node: Node, seconds: float) -> void:
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)


func _host() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		return scene
	return get_tree().root


func _make_soft_texture() -> ImageTexture:
	var image := Image.create(SOFT_TEXTURE_SIZE, SOFT_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SOFT_TEXTURE_SIZE, SOFT_TEXTURE_SIZE) * 0.5
	var radius := SOFT_TEXTURE_SIZE * 0.5

	for y in range(SOFT_TEXTURE_SIZE):
		for x in range(SOFT_TEXTURE_SIZE):
			var distance := Vector2(x, y).distance_to(center)
			var alpha := 1.0 - smoothstep(radius * 0.1, radius, distance)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)
