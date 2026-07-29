class_name Pickup
extends Node3D

## Caixa de recurso. A coleta e por proximidade horizontal, sem exigir pouso:
## o custo do recurso e o desvio de rota, nao a pericia de encostar na caixa.

signal collected(type: int)

enum Type {
	FUEL,
	ARMOR,
	AMMO_MACHINEGUN,
	AMMO_ROCKETS,
	AMMO_MISSILES,
	INTEL,
}

const COLLECT_RADIUS := 4.5

const TYPE_BY_NAME := {
	"fuel": Type.FUEL,
	"armor": Type.ARMOR,
	"ammo_machinegun": Type.AMMO_MACHINEGUN,
	"ammo_rockets": Type.AMMO_ROCKETS,
	"ammo_missiles": Type.AMMO_MISSILES,
	"intel": Type.INTEL,
}

const TYPE_COLORS := {
	Type.FUEL: Color(0.95, 0.78, 0.24),
	Type.ARMOR: Color(0.36, 0.72, 0.95),
	Type.AMMO_MACHINEGUN: Color(0.86, 0.4, 0.32),
	Type.AMMO_ROCKETS: Color(0.9, 0.52, 0.24),
	Type.AMMO_MISSILES: Color(0.72, 0.5, 0.92),
	Type.INTEL: Color(0.55, 0.95, 0.78),
}

const TYPE_LABELS := {
	Type.FUEL: "COMBUSTIVEL",
	Type.ARMOR: "BLINDAGEM",
	Type.AMMO_MACHINEGUN: "MUNICAO",
	Type.AMMO_ROCKETS: "FOGUETES",
	Type.AMMO_MISSILES: "MISSEIS",
	Type.INTEL: "INTELIGENCIA",
}

var type: int = Type.FUEL
## Preenchido quando o item e alvo de um objetivo de coleta.
var item_id := ""

var _player: Node3D
var _bob_time := 0.0
var _collected := false
var _crate: Node3D


func setup(p_type: int, p_item_id: String = "") -> void:
	type = p_type
	item_id = p_item_id


static func type_from_name(kind_name: String) -> int:
	return TYPE_BY_NAME.get(kind_name, Type.FUEL)


func _ready() -> void:
	add_to_group("pickup")
	_build_visual()


func get_label() -> String:
	return TYPE_LABELS.get(type, "RECURSO")


func _process(delta: float) -> void:
	if _collected:
		return

	_bob_time += delta
	if _crate != null:
		_crate.position.y = 0.55 + sin(_bob_time * 2.2) * 0.16
		_crate.rotation.y = _bob_time * 0.8

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return

	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > COLLECT_RADIUS:
		return

	_collect()


func _collect() -> void:
	_collected = true
	remove_from_group("pickup")

	if _player.has_method("apply_pickup"):
		_player.apply_pickup(type)

	if not item_id.is_empty():
		MissionManager.notify_collected(item_id)

	var color: Color = TYPE_COLORS.get(type, Color.WHITE)
	Vfx.spawn_impact(global_position + Vector3.UP, Vector3.UP, color)
	AudioManager.play_ui(AudioManager.Sfx.PICKUP, -8.0)

	collected.emit(type)
	queue_free()


func _build_visual() -> void:
	var color: Color = TYPE_COLORS.get(type, Color.WHITE)

	_crate = Node3D.new()
	_crate.name = "Crate"
	_crate.position = Vector3(0.0, 0.55, 0.0)
	add_child(_crate)

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.1, 0.9, 1.1)
	box.mesh = box_mesh

	var box_material := StandardMaterial3D.new()
	box_material.albedo_color = Color(0.42, 0.4, 0.36)
	box_material.roughness = 0.9
	box.material_override = box_material
	_crate.add_child(box)

	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(1.16, 0.24, 1.16)
	band.mesh = band_mesh
	band.position = Vector3(0.0, 0.18, 0.0)

	var band_material := StandardMaterial3D.new()
	band_material.albedo_color = color
	band_material.emission_enabled = true
	band_material.emission = color
	band_material.emission_energy_multiplier = 1.4
	band_material.roughness = 0.5
	band.material_override = band_material
	_crate.add_child(band)

	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 0.02
	glow_mesh.bottom_radius = 0.55
	glow_mesh.height = 5.0
	glow_mesh.radial_segments = 10
	glow.mesh = glow_mesh
	glow.position = Vector3(0.0, 2.6, 0.0)

	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_material.albedo_color = Color(color.r, color.g, color.b, 0.3)
	glow.material_override = glow_material
	add_child(glow)
