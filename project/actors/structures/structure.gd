class_name Structure
extends StaticBody3D

## Alvo de missao destrutivel (radar, QG, deposito). Fica no grupo "enemy" para a
## mira assistida funcionar e no grupo "structure" para a missao acompanhar.
## Ao morrer vira escombro em vez de sumir: o mapa precisa mostrar o que ja foi feito.

signal destroyed(structure_id: String)

enum Kind {
	RADAR,
	HQ,
	DEPOT,
}

const KIND_BY_NAME := {
	"radar": Kind.RADAR,
	"hq": Kind.HQ,
	"depot": Kind.DEPOT,
}

var structure_id := ""
var kind: int = Kind.RADAR
var display_name := "Estrutura"
var health: Health

var _visual: Node3D
var _spin_target: Node3D
var _destroyed := false


func setup(p_structure_id: String, kind_name: String) -> void:
	structure_id = p_structure_id
	kind = KIND_BY_NAME.get(kind_name, Kind.RADAR)

	collision_layer = CombatLayers.WORLD | CombatLayers.ENEMY
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("structure")

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(_default_hp())
	health.died.connect(_on_died)

	_build()


func is_alive() -> bool:
	return not _destroyed


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * _body_size().y * 0.5


func take_damage(event: DamageEvent) -> void:
	if _destroyed:
		return

	if _visual != null:
		for child in _visual.get_children():
			if child is MeshInstance3D:
				Vfx.flash_mesh(child)
				break

	health.apply_damage(event)


func _process(delta: float) -> void:
	if _destroyed or _spin_target == null:
		return
	_spin_target.rotate_y(delta * 0.8)


func _default_hp() -> int:
	match kind:
		Kind.RADAR:
			return 30
		Kind.HQ:
			return 90
		_:
			return 40


func _body_size() -> Vector3:
	match kind:
		Kind.RADAR:
			return Vector3(4.0, 9.0, 4.0)
		Kind.HQ:
			return Vector3(18.0, 10.0, 14.0)
		_:
			return Vector3(7.0, 6.0, 7.0)


func _build() -> void:
	var size := _body_size()

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	match kind:
		Kind.RADAR:
			display_name = "Radar"
			_build_radar()
		Kind.HQ:
			display_name = "Quartel-general"
			_build_hq()
		_:
			display_name = "Deposito"
			_build_depot()


func _build_radar() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.33, 0.35, 0.32)
	metal.metallic = 0.4
	metal.roughness = 0.6

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(3.4, 1.4, 3.4)
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.7, 0.0)
	base.material_override = metal
	_visual.add_child(base)

	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.28
	mast_mesh.bottom_radius = 0.42
	mast_mesh.height = 5.0
	mast_mesh.radial_segments = 10
	mast.mesh = mast_mesh
	mast.position = Vector3(0.0, 3.9, 0.0)
	mast.material_override = metal
	_visual.add_child(mast)

	_spin_target = Node3D.new()
	_spin_target.name = "DishPivot"
	_spin_target.position = Vector3(0.0, 6.6, 0.0)
	_visual.add_child(_spin_target)

	var dish := MeshInstance3D.new()
	var dish_mesh := CylinderMesh.new()
	dish_mesh.top_radius = 3.2
	dish_mesh.bottom_radius = 0.5
	dish_mesh.height = 1.7
	dish_mesh.radial_segments = 18
	dish.mesh = dish_mesh
	dish.rotation_degrees = Vector3(58.0, 0.0, 0.0)
	dish.position = Vector3(0.0, 0.4, 0.0)

	var dish_material := StandardMaterial3D.new()
	dish_material.albedo_color = Color(0.55, 0.56, 0.53)
	dish_material.metallic = 0.25
	dish_material.roughness = 0.5
	dish_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	dish.material_override = dish_material
	_spin_target.add_child(dish)


func _build_hq() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.34, 0.35, 0.31)
	concrete.roughness = 0.95

	var main := MeshInstance3D.new()
	var main_mesh := BoxMesh.new()
	main_mesh.size = Vector3(16.0, 7.0, 12.0)
	main.mesh = main_mesh
	main.position = Vector3(0.0, 3.5, 0.0)
	main.material_override = concrete
	_visual.add_child(main)

	var tower := MeshInstance3D.new()
	var tower_mesh := BoxMesh.new()
	tower_mesh.size = Vector3(5.0, 4.5, 5.0)
	tower.mesh = tower_mesh
	tower.position = Vector3(4.5, 9.0, -2.5)
	tower.material_override = concrete
	_visual.add_child(tower)

	var antenna := MeshInstance3D.new()
	var antenna_mesh := CylinderMesh.new()
	antenna_mesh.top_radius = 0.1
	antenna_mesh.bottom_radius = 0.16
	antenna_mesh.height = 6.0
	antenna_mesh.radial_segments = 8
	antenna.mesh = antenna_mesh
	antenna.position = Vector3(4.5, 14.2, -2.5)

	var antenna_material := StandardMaterial3D.new()
	antenna_material.albedo_color = Color(0.3, 0.3, 0.28)
	antenna_material.metallic = 0.5
	antenna.material_override = antenna_material
	_visual.add_child(antenna)


func _build_depot() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.4, 0.36, 0.27)
	metal.metallic = 0.3
	metal.roughness = 0.6

	for offset in [Vector3(-1.8, 0.0, -1.8), Vector3(1.8, 0.0, -1.8), Vector3(0.0, 0.0, 1.8)]:
		var tank := MeshInstance3D.new()
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = 1.6
		tank_mesh.bottom_radius = 1.6
		tank_mesh.height = 4.4
		tank_mesh.radial_segments = 14
		tank.mesh = tank_mesh
		tank.position = offset + Vector3(0.0, 2.2, 0.0)
		tank.material_override = metal
		_visual.add_child(tank)


func _on_died(_event: DamageEvent) -> void:
	_destroyed = true
	remove_from_group("enemy")
	collision_layer = CombatLayers.WORLD

	var size := _body_size()
	var scale_factor := clampf(size.y * 0.22, 1.2, 3.4)

	Vfx.spawn_explosion(global_position + Vector3.UP * size.y * 0.4, scale_factor)
	get_tree().call_group("camera_rig", "add_trauma", clampf(scale_factor * 0.2, 0.2, 0.7))
	GameState.add_score(int(size.y * 40.0))

	_replace_with_rubble(size)

	destroyed.emit(structure_id)
	MissionManager.notify_structure_destroyed(structure_id)


func _replace_with_rubble(size: Vector3) -> void:
	if _visual != null:
		_visual.queue_free()
		_visual = null
	_spin_target = null

	var rubble := MeshInstance3D.new()
	rubble.name = "Rubble"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x * 0.92, maxf(0.8, size.y * 0.16), size.z * 0.92)
	rubble.mesh = mesh
	rubble.position = Vector3(0.0, mesh.size.y * 0.5, 0.0)
	rubble.rotation.y = randf_range(-0.2, 0.2)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.16, 0.14)
	material.roughness = 1.0
	rubble.material_override = material
	add_child(rubble)
