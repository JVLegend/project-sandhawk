extends Node

## Ferramenta de captura para registro de marco e verificacao visual.
## Roda a cena real (com autoloads) e salva um PNG.
##
## Uso:
##   godot res://tools/capture_screenshot.tscn -- /caminho/saida.png [modo]
##
## Modos: "arena" (padrao, helicoptero perto do alvo) e "explosao" (mata um alvo
## antes de capturar, para conferir os VFX).

const MAIN_SCENE := preload("res://game/main.tscn")
const DAMAGE_EVENT := preload("res://game/combat/damage_event.gd")

const APPROACH_DISTANCE := 13.0
const SETTLE_FRAMES := 50
const CAMERA_CATCHUP_FRAMES := 45
const EXPLOSION_FRAMES := 7


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var output_path := args[0] if args.size() > 0 else "user://capture.png"
	var mode := args[1] if args.size() > 1 else "arena"

	var world := MAIN_SCENE.instantiate()
	add_child(world)

	await _wait_frames(SETTLE_FRAMES)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target := _nearest_enemy(player)

	if player != null and target != null:
		_move_player_near(player, target)
		await _wait_frames(CAMERA_CATCHUP_FRAMES)

	if mode == "explosao" and target != null:
		target.take_damage(DAMAGE_EVENT.create(
			9999,
			DAMAGE_EVENT.Type.EXPLOSIVE,
			Vector3.ZERO,
			target.global_position,
			true,
			null
		))
		await _wait_frames(EXPLOSION_FRAMES)

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)

	if error == OK:
		print("Screenshot salvo em %s" % output_path)
	else:
		push_error("Falha ao salvar screenshot em %s (erro %d)" % [output_path, error])

	get_tree().quit(0 if error == OK else 1)


func _nearest_enemy(player: Node3D) -> Node3D:
	if player == null:
		return null

	var best: Node3D = null
	var best_distance := INF

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy

	return best


func _move_player_near(player: Node3D, target: Node3D) -> void:
	var offset := (player.global_position - target.global_position)
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		offset = Vector3.FORWARD

	var approach := offset.normalized() * APPROACH_DISTANCE
	player.global_position = Vector3(
		target.global_position.x + approach.x,
		player.global_position.y,
		target.global_position.z + approach.z
	)
	player.look_at(Vector3(target.global_position.x, player.global_position.y, target.global_position.z), Vector3.UP)


func _wait_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
