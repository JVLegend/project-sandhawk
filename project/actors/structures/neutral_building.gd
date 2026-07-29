class_name NeutralBuilding
extends StaticBody3D

## Casa civil destrutivel: da feedback claro quando o jogador atira onde nao deve.

var display_name := "Casa civil"
var health: Health

var _destroyed := false
var _body_size := Vector3(6.0, 4.0, 6.0)
var _visual: Node3D


func setup_house(width: float, depth: float, height: float, wall_color: Color, roof_color: Color) -> void:
	_body_size = Vector3(width, height, depth)
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

	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = wall_color
	wall_material.roughness = 0.96
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

	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = roof_color
	roof_material.roughness = 0.98
	roof.material_override = roof_material
	_visual.add_child(roof)


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

	var rubble_material := StandardMaterial3D.new()
	rubble_material.albedo_color = Color(0.24, 0.21, 0.18)
	rubble_material.roughness = 1.0
	rubble.material_override = rubble_material
	add_child(rubble)

	MissionManager.notify_neutral_structure_destroyed(display_name)
