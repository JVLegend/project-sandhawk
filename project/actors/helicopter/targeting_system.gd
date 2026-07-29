class_name TargetingSystem
extends Node3D

## Mira assistida. O original tinha mira "grudenta": sem isso o combate isometrico
## frustra, porque acertar em profundidade fica adivinhacao.
## Escolhe o inimigo de MENOR angulo em relacao ao nariz, dentro de um cone.

signal target_changed(target: Node3D)

@export var cone_degrees: float = 12.0
@export var max_range: float = 90.0
@export var show_marker: bool = true

var current_target: Node3D

var _shooter: Node3D
var _marker: Node3D
var _marker_spin := 0.0


func _ready() -> void:
	_shooter = get_parent() as Node3D
	if show_marker:
		_build_marker()


func _process(delta: float) -> void:
	var previous := current_target
	current_target = _find_best_target()

	if current_target != previous:
		target_changed.emit(current_target)

	_update_marker(delta)


## Alvo valido dentro do alcance da arma pedida.
func target_within(range_meters: float) -> Node3D:
	if current_target == null or not is_instance_valid(current_target):
		return null
	if _shooter == null:
		return null
	if _shooter.global_position.distance_to(current_target.global_position) > range_meters:
		return null
	return current_target


func _find_best_target() -> Node3D:
	if _shooter == null:
		return null

	var forward := -_shooter.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return null
	forward = forward.normalized()

	var best: Node3D = null
	var best_angle := deg_to_rad(cone_degrees)

	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue

		var candidate := node as Node3D
		if candidate == null:
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue

		var offset := candidate.global_position - _shooter.global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		if flat.length() > max_range or flat.length_squared() < 0.0001:
			continue

		var angle := forward.angle_to(flat.normalized())
		if angle < best_angle:
			best_angle = angle
			best = candidate

	return best


func _update_marker(delta: float) -> void:
	if _marker == null:
		return

	var has_target := current_target != null and is_instance_valid(current_target)
	_marker.visible = has_target
	if not has_target:
		return

	_marker_spin += delta * 1.4
	_marker.global_position = CombatUtils.aim_point_for(current_target) + Vector3.UP * 1.6
	_marker.rotation.y = _marker_spin


func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "TargetMarker"
	_marker.top_level = true
	add_child(_marker)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.05
	torus.rings = 4
	torus.ring_segments = 16
	ring.mesh = torus

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.36, 0.28, 0.85)
	material.no_depth_test = true
	ring.material_override = material

	_marker.add_child(ring)
	_marker.visible = false
