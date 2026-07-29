class_name NeutralBuilding
extends StaticBody3D

## Casa civil destrutivel: da feedback claro quando o jogador atira onde nao deve.

const SURFACE_FACTORY := preload("res://world/props/surface_factory.gd")

var display_name := "Casa civil"
var health: Health

var _destroyed := false
var _body_size := Vector3(6.0, 4.0, 6.0)
var _visual: Node3D
var _surface_seed := 0


func setup_house(width: float, depth: float, height: float, wall_color: Color, roof_color: Color, surface_seed: int) -> void:
	_body_size = Vector3(width, height, depth)
	_surface_seed = surface_seed
	collision_layer = CombatLayers.WORLD
	collision_mask = 0
	add_to_group("neutral_structure")

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(12)
	health.died.connect(_on_died)

	_build_visual(wall_color, roof_color)


func take_damage(event: DamageEvent) -> void:
	if _destroyed or health == null:
		return

	if _visual != null:
		for child in _visual.get_children():
			if child is MeshInstance3D:
				Vfx.flash_mesh(child)
				break

	health.apply_damage(event)


func _build_visual(wall_color: Color, roof_color: Color) -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var walls := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = _body_size
	walls.mesh = wall_mesh
	walls.position = Vector3(0.0, _body_size.y * 0.5, 0.0)

	var wall_material := SURFACE_FACTORY.make_plaster_material(wall_color, _surface_seed + 5, Vector3(2.4, 2.4, 2.4))
	walls.material_override = wall_material
	_visual.add_child(walls)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = wall_mesh.size
	shape.shape = box
	shape.position = walls.position
	add_child(shape)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(_body_size.x + 0.6, 0.4, _body_size.z + 0.6)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, _body_size.y + 0.2, 0.0)

	var roof_material := SURFACE_FACTORY.make_roof_material(roof_color, _surface_seed + 19, Vector3(3.4, 3.4, 3.4))
	roof.material_override = roof_material
	_visual.add_child(roof)

	_add_trim()
	_add_windows()
	_add_door()
	_add_roof_detail()


func _add_trim() -> void:
	var trim := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_body_size.x + 0.18, 0.22, _body_size.z + 0.18)
	trim.mesh = mesh
	trim.position = Vector3(0.0, _body_size.y * 0.72, 0.0)
	trim.material_override = SURFACE_FACTORY.make_concrete_material(Color(0.56, 0.49, 0.38), _surface_seed + 53, Vector3(4.0, 2.2, 4.0))
	_visual.add_child(trim)


func _add_windows() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.16, 0.2, 0.22)
	glass.metallic = 0.18
	glass.roughness = 0.2

	var count := maxi(2, int(round(_body_size.x / 2.6)))
	for face in [-1.0, 1.0]:
		for index in count:
			var x := lerpf(-_body_size.x * 0.32, _body_size.x * 0.32, float(index) / maxf(1.0, float(count - 1)))
			var window := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.62, 0.82, 0.09)
			window.mesh = mesh
			window.position = Vector3(x, _body_size.y * 0.54, face * (_body_size.z * 0.5 + 0.045))
			window.material_override = glass
			_visual.add_child(window)


func _add_door() -> void:
	var door := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.05, 1.9, 0.16)
	door.mesh = mesh
	door.position = Vector3(0.0, 0.95, _body_size.z * 0.5 + 0.08)
	door.material_override = SURFACE_FACTORY.make_metal_material(Color(0.36, 0.27, 0.19), _surface_seed + 61, Vector3(2.0, 2.0, 2.0), 0.14, 0.72)
	_visual.add_child(door)

	var awning := MeshInstance3D.new()
	var awning_mesh := BoxMesh.new()
	awning_mesh.size = Vector3(1.7, 0.16, 0.9)
	awning.mesh = awning_mesh
	awning.position = Vector3(0.0, 2.2, _body_size.z * 0.5 + 0.36)
	awning.material_override = SURFACE_FACTORY.make_roof_material(Color(0.44, 0.34, 0.26), _surface_seed + 67, Vector3(2.6, 2.6, 2.6))
	_visual.add_child(awning)


func _add_roof_detail() -> void:
	var vent := MeshInstance3D.new()
	var vent_mesh := CylinderMesh.new()
	vent_mesh.top_radius = 0.24
	vent_mesh.bottom_radius = 0.32
	vent_mesh.height = 0.9
	vent_mesh.radial_segments = 8
	vent.mesh = vent_mesh
	vent.position = Vector3(_body_size.x * 0.18, _body_size.y + 0.65, -_body_size.z * 0.12)
	vent.material_override = SURFACE_FACTORY.make_metal_material(Color(0.52, 0.49, 0.42), _surface_seed + 79, Vector3(2.6, 2.6, 2.6), 0.24, 0.58)
	_visual.add_child(vent)


func _on_died(_event: DamageEvent) -> void:
	_destroyed = true

	var blast_center := global_position + Vector3.UP * (_body_size.y * 0.45)
	Vfx.spawn_explosion(blast_center, clampf(_body_size.y * 0.16, 0.8, 1.4))
	get_tree().call_group("camera_rig", "add_trauma", 0.12)

	if _visual != null:
		_visual.queue_free()
		_visual = null

	var rubble := MeshInstance3D.new()
	var rubble_mesh := BoxMesh.new()
	rubble_mesh.size = Vector3(_body_size.x * 0.92, maxf(0.7, _body_size.y * 0.16), _body_size.z * 0.92)
	rubble.mesh = rubble_mesh
	rubble.position = Vector3(0.0, rubble_mesh.size.y * 0.5, 0.0)
	rubble.rotation.y = randf_range(-0.18, 0.18)

	var rubble_material := SURFACE_FACTORY.make_rubble_material(Color(0.24, 0.21, 0.18), _surface_seed + 41, Vector3(2.1, 2.1, 2.1))
	rubble.material_override = rubble_material
	add_child(rubble)

	MissionManager.notify_neutral_structure_destroyed(display_name)
