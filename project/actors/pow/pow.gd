class_name Pow
extends Node3D

## Prisioneiro/piloto abatido a resgatar. Fica no grupo "pow" e so some do mapa
## quando o guincho conclui a subida.

signal rescued

enum State {
	AVAILABLE,
	BEING_RESCUED,
	RESCUED,
}

var state: int = State.AVAILABLE

var _beacon: MeshInstance3D
var _arm: Node3D
var _wave_time := 0.0


func _ready() -> void:
	add_to_group("pow")
	_build_visual()


func is_available() -> bool:
	return state == State.AVAILABLE


func begin_rescue() -> void:
	state = State.BEING_RESCUED


func cancel_rescue() -> void:
	if state == State.BEING_RESCUED:
		state = State.AVAILABLE


func complete_rescue() -> void:
	state = State.RESCUED
	remove_from_group("pow")
	rescued.emit()
	queue_free()


func _process(delta: float) -> void:
	_wave_time += delta

	if _beacon != null:
		var pulse := 0.55 + 0.45 * sin(_wave_time * 3.4)
		var material := _beacon.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color.a = pulse
		_beacon.rotation.y = _wave_time * 1.1

	if _arm != null and state == State.AVAILABLE:
		_arm.rotation.z = deg_to_rad(-150.0 + sin(_wave_time * 7.0) * 22.0)


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.32
	body_mesh.height = 1.5
	body_mesh.radial_segments = 10
	body_mesh.rings = 4
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.75, 0.0)

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.36, 0.55, 0.72)
	body_material.roughness = 0.85
	body.material_override = body_material
	add_child(body)

	var helmet := MeshInstance3D.new()
	helmet.name = "Helmet"
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.24
	helmet_mesh.height = 0.42
	helmet_mesh.radial_segments = 10
	helmet_mesh.rings = 5
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 1.52, 0.0)

	var helmet_material := StandardMaterial3D.new()
	helmet_material.albedo_color = Color(0.88, 0.85, 0.72)
	helmet_material.roughness = 0.7
	helmet.material_override = helmet_material
	add_child(helmet)

	_arm = Node3D.new()
	_arm.name = "ArmPivot"
	_arm.position = Vector3(0.3, 1.18, 0.0)
	add_child(_arm)

	var arm := MeshInstance3D.new()
	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.09
	arm_mesh.height = 0.7
	arm_mesh.radial_segments = 6
	arm_mesh.rings = 2
	arm.mesh = arm_mesh
	arm.position = Vector3(0.0, 0.35, 0.0)
	arm.material_override = body_material
	_arm.add_child(arm)

	## Farol vertical: sem isso o resgatado desaparece no deserto.
	_beacon = MeshInstance3D.new()
	_beacon.name = "Beacon"
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.02
	beacon_mesh.bottom_radius = 0.75
	beacon_mesh.height = 9.0
	beacon_mesh.radial_segments = 12
	_beacon.mesh = beacon_mesh
	_beacon.position = Vector3(0.0, 4.6, 0.0)

	var beacon_material := StandardMaterial3D.new()
	beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beacon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beacon_material.albedo_color = Color(0.42, 0.95, 0.55, 0.55)
	_beacon.material_override = beacon_material
	add_child(_beacon)
