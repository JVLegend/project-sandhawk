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
