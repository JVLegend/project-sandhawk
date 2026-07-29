class_name VehicleParts
extends RefCounted

## Pecas reaproveitadas pelos veiculos inimigos: rodas, esteiras, torres e canos.
## Tudo gerado em codigo, como o resto do jogo.


static func material(color: Color, roughness: float = 0.75, metallic: float = 0.2) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	return result


static func add_box(parent: Node3D, node_name: String, size: Vector3, offset: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = mat
	parent.add_child(instance)
	return instance


static func add_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	offset: Vector3,
	mat: Material,
	segments: int = 12
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = mat
	parent.add_child(instance)
	return instance


## Roda deitada no eixo X, como num veiculo de verdade.
static func add_wheel(parent: Node3D, node_name: String, radius: float, width: float, offset: Vector3) -> MeshInstance3D:
	var rubber := material(Color(0.11, 0.11, 0.12), 0.95, 0.0)
	var wheel := add_cylinder(parent, node_name, radius, width, offset, rubber, 10)
	wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)

	var hub := material(Color(0.45, 0.44, 0.4), 0.6, 0.4)
	var cap := add_cylinder(wheel, "Hub", radius * 0.45, width * 1.05, Vector3.ZERO, hub, 8)
	cap.rotation_degrees = Vector3.ZERO

	return wheel


## Esteira com roletes visiveis, para tanque.
static func add_track(parent: Node3D, node_name: String, length: float, height: float, offset: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = offset
	parent.add_child(root)

	var belt := material(Color(0.13, 0.13, 0.13), 0.98, 0.0)
	add_box(root, "Belt", Vector3(0.9, height, length), Vector3.ZERO, belt)

	var roller := material(Color(0.3, 0.3, 0.28), 0.7, 0.35)
	var count := 5
	for index in count:
		var t := float(index) / float(count - 1)
		var z := lerpf(-length * 0.42, length * 0.42, t)
		var wheel := add_cylinder(root, "Roller%d" % index, height * 0.42, 1.0, Vector3(0.0, -height * 0.12, z), roller, 8)
		wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)

	return root


## Cano de arma com freio de boca na ponta.
static func add_barrel(parent: Node3D, node_name: String, radius: float, length: float, offset: Vector3, mat: Material) -> MeshInstance3D:
	var barrel := add_cylinder(parent, node_name, radius, length, offset, mat, 10)
	barrel.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var brake := add_cylinder(barrel, "MuzzleBrake", radius * 1.5, length * 0.11, Vector3(0.0, -length * 0.46, 0.0), mat, 10)
	brake.rotation_degrees = Vector3.ZERO

	return barrel


## Luz de alerta que pisca quando o inimigo trava a mira.
static func add_warning_light(parent: Node3D, offset: Vector3, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.0

	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 8
	mesh.rings = 4

	var light := MeshInstance3D.new()
	light.name = "WarningLight"
	light.mesh = mesh
	light.position = offset
	light.material_override = mat
	parent.add_child(light)
	return light


static func pulse_warning(light: MeshInstance3D, active: bool, time: float) -> void:
	if light == null:
		return
	var mat := light.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.emission_energy_multiplier = 0.0 if not active else 2.0 + 3.0 * absf(sin(time * 7.0))
