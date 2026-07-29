class_name DamageEvent
extends RefCounted

## Pacote de dano trocado entre armas, projeteis e alvos.
## Manter imutavel depois de criado: quem recebe apenas le.

enum Type {
	BULLET,
	EXPLOSIVE,
	COLLISION,
}

var amount: int = 0
var type: int = Type.BULLET
var origin: Vector3 = Vector3.ZERO
var impact_point: Vector3 = Vector3.ZERO
var from_player: bool = false
var source: Node = null


static func create(
	p_amount: int,
	p_type: int,
	p_origin: Vector3,
	p_impact_point: Vector3,
	p_from_player: bool,
	p_source: Node = null
) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = p_amount
	event.type = p_type
	event.origin = p_origin
	event.impact_point = p_impact_point
	event.from_player = p_from_player
	event.source = p_source
	return event
