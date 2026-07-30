class_name CombatUtils
extends RefCounted

## Helpers compartilhados entre armas, projeteis e IA.


## Sobe na arvore ate achar quem sabe receber dano.
## Necessario porque o raycast devolve o corpo/area atingido, nao o ator.
static func resolve_damageable(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null


## Direcao com dispersao aleatoria dentro de um cone, em graus.
static func apply_spread(direction: Vector3, spread_degrees: float) -> Vector3:
	if spread_degrees <= 0.0:
		return direction.normalized()

	var spread := deg_to_rad(spread_degrees)
	var basis_dir := direction.normalized()
	var reference := Vector3.UP
	if absf(basis_dir.dot(reference)) > 0.98:
		reference = Vector3.RIGHT

	var tangent := basis_dir.cross(reference).normalized()
	var bitangent := basis_dir.cross(tangent).normalized()

	var angle := randf_range(0.0, TAU)
	var radius := sqrt(randf()) * tan(spread)
	var offset := (tangent * cos(angle) + bitangent * sin(angle)) * radius

	return (basis_dir + offset).normalized()


## Linha de visada livre entre dois pontos (so o cenario bloqueia).
static func has_line_of_sight(world: World3D, from: Vector3, to: Vector3) -> bool:
	if world == null:
		return true

	var query := PhysicsRayQueryParameters3D.create(from, to, CombatLayers.LINE_OF_SIGHT_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := world.direct_space_state.intersect_ray(query)
	return result.is_empty()


## Ponto de mira de um alvo: centro do corpo, nao a base.
static func aim_point_for(target: Node3D) -> Vector3:
	if target == null:
		return Vector3.ZERO
	if target.has_method("get_aim_point"):
		return target.get_aim_point()
	return target.global_position


static func closest_point_on_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> Vector3:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared < 0.000001:
		return segment_start

	var t := clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return segment_start + segment * t


static func distance_point_to_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	return point.distance_to(closest_point_on_segment(point, segment_start, segment_end))


static func hit_radius_for(target: Node3D) -> float:
	if target == null:
		return 0.6

	var collision_shape := _find_collision_shape(target)
	if collision_shape == null or collision_shape.shape == null:
		return 0.6

	var shape := collision_shape.shape
	if shape is SphereShape3D:
		return shape.radius
	if shape is CapsuleShape3D:
		return maxf(shape.radius, shape.height * 0.5)
	if shape is CylinderShape3D:
		return shape.radius
	if shape is BoxShape3D:
		return maxf(maxf(shape.size.x, shape.size.y), shape.size.z) * 0.5

	return 0.6


static func _find_collision_shape(node: Node) -> CollisionShape3D:
	for child in node.get_children():
		if child is CollisionShape3D and child.shape != null and not child.disabled:
			return child

		var nested := _find_collision_shape(child)
		if nested != null:
			return nested

	return null
