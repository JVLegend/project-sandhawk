extends SceneTree

## Teste de fumaca do combate (Fase 4). Roda headless e exercita o caminho real:
## spawn de inimigos, disparo por input, dano, morte, score e dano no jogador.
## Uso: godot --headless --script tools/combat_smoke_test.gd
##
## IMPORTANTE: em modo --script este arquivo vira o main loop e compila ANTES de
## os autoloads existirem. Por isso nada aqui referencia classes do jogo nem
## autoloads de forma estatica: tudo e resolvido em runtime, com load() e por
## grupo/duck typing. Referenciar PlaceholderHelicopter ou Vfx diretamente
## quebraria a compilacao deste script, nao o jogo.

const EXPECTED_ARMOR := 600
const EXPECTED_SOLDIERS := 7
const EXPECTED_TURRETS := 3

var _failures: Array[String] = []
var _damage_event_script: GDScript


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_damage_event_script = load("res://game/combat/damage_event.gd") as GDScript
	if _damage_event_script == null:
		_fail("Falha ao carregar damage_event.gd")
		_finish()
		return

	var scene: PackedScene = load("res://game/main.tscn") as PackedScene
	if scene == null:
		_fail("Falha ao carregar main.tscn")
		_finish()
		return

	var world := scene.instantiate()
	root.add_child(world)
	current_scene = world

	for _i in 4:
		await physics_frame

	await _test_spawns()
	await _test_player_setup(world)
	await _test_weapon_fire()
	await _test_enemy_death()
	await _test_player_damage()
	await _test_hitscan_end_to_end()
	await _test_aaa_threat()

	_finish()


func _test_spawns() -> void:
	var enemies := get_nodes_in_group("enemy")
	var expected_total := EXPECTED_SOLDIERS + EXPECTED_TURRETS
	_expect(enemies.size() == expected_total,
		"Arena deve ter %d alvos, tem %d" % [expected_total, enemies.size()])

	var soldiers := 0
	var turrets := 0
	for enemy in enemies:
		var definition = enemy.get("definition")
		if definition == null:
			_fail("Inimigo sem definition carregada")
			continue
		match definition.id:
			"soldier_ak":
				soldiers += 1
			"aaa_gun":
				turrets += 1

	_expect(soldiers == EXPECTED_SOLDIERS, "Esperado %d soldados, achou %d" % [EXPECTED_SOLDIERS, soldiers])
	_expect(turrets == EXPECTED_TURRETS, "Esperado %d canhoes AAA, achou %d" % [EXPECTED_TURRETS, turrets])


func _test_player_setup(world: Node) -> void:
	var player := get_first_node_in_group("player")
	_expect(player != null, "Helicoptero do jogador nao entrou no grupo player")
	if player == null:
		return

	var health = player.get("health")
	_expect(health != null, "Jogador sem componente Health")
	if health != null:
		_expect(health.max_hp == EXPECTED_ARMOR,
			"Blindagem maxima deveria ser %d, e %d" % [EXPECTED_ARMOR, health.max_hp])
		_expect(health.hp == health.max_hp, "Jogador deveria comecar com blindagem cheia")

	var weapons = player.get("weapons")
	_expect(weapons != null and weapons.runtimes.size() == 3, "Jogador deveria ter 3 armas carregadas")
	_expect(player.get("targeting") != null, "Sistema de mira nao foi criado")
	_expect(world.get_node_or_null("DebugHud") != null, "HUD de debug nao foi criado")


func _test_weapon_fire() -> void:
	var player := get_first_node_in_group("player")
	if player == null:
		return

	var weapons = player.get("weapons")
	if weapons == null:
		return

	var machinegun = weapons.get_runtime(0)
	var ammo_before: int = machinegun.ammo

	Input.action_press("fire_primary")
	for _i in 6:
		await physics_frame
	Input.action_release("fire_primary")
	await physics_frame

	_expect(machinegun.ammo < ammo_before,
		"Metralhadora nao consumiu municao (antes %d, depois %d)" % [ammo_before, machinegun.ammo])

	var rockets = weapons.get_runtime(1)
	var rockets_before: int = rockets.ammo

	Input.action_press("fire_secondary")
	await physics_frame
	Input.action_release("fire_secondary")
	for _i in 3:
		await physics_frame

	_expect(rockets.ammo == rockets_before - 1,
		"Foguete deveria consumir exatamente 1 (antes %d, depois %d)" % [rockets_before, rockets.ammo])


func _test_enemy_death() -> void:
	var game_state := root.get_node_or_null("/root/GameState")
	if game_state == null:
		_fail("Autoload GameState nao encontrado em /root/GameState")
		return

	var enemies := get_nodes_in_group("enemy")
	if enemies.is_empty():
		_fail("Sem inimigos para testar morte")
		return

	var victim: Node3D = enemies[0]
	var score_before: int = game_state.score
	var count_before := enemies.size()

	victim.take_damage(_make_damage(9999, victim.global_position, true))

	for _i in 3:
		await physics_frame

	_expect(game_state.score > score_before,
		"Score nao subiu apos abate (antes %d, agora %d)" % [score_before, game_state.score])
	_expect(get_nodes_in_group("enemy").size() == count_before - 1,
		"Inimigo morto continua no grupo enemy")
	_expect(is_equal_approx(Engine.time_scale, 1.0),
		"Hitstop nao restaurou time_scale (esta em %f)" % Engine.time_scale)


func _test_player_damage() -> void:
	var player := get_first_node_in_group("player")
	if player == null:
		return

	var health = player.get("health")
	if health == null:
		return

	var armor_before: int = health.hp
	player.take_damage(_make_damage(50, player.global_position, false))
	await physics_frame

	_expect(health.hp == armor_before - 50,
		"Jogador deveria perder 50 de blindagem (antes %d, depois %d)" % [armor_before, health.hp])


## Loop completo do jogador: mira assistida -> hitscan -> dano no inimigo.
## E o teste que mais importa: se este passar, o combate funciona de verdade.
func _test_hitscan_end_to_end() -> void:
	var player := get_first_node_in_group("player")
	if player == null:
		return

	var victim := _find_enemy_by_id("soldier_ak")
	if victim == null:
		_fail("Nenhum soldado disponivel para o teste de hitscan")
		return

	_place_player_facing(player, victim, 12.0)
	for _i in 3:
		await process_frame

	var targeting = player.get("targeting")
	_expect(targeting != null and targeting.current_target == victim,
		"Mira assistida nao travou no soldado a frente")

	var hp_before: int = victim.health.hp

	Input.action_press("fire_primary")
	for _i in 14:
		await physics_frame
	Input.action_release("fire_primary")
	await physics_frame

	if not is_instance_valid(victim):
		return

	_expect(victim.health.hp < hp_before,
		"Metralhadora nao causou dano no alvo travado (HP %d antes e depois)" % hp_before)


## O canhao AAA precisa ser uma ameaca real, nao um alvo estatico.
## Roda por ultimo porque remove os soldados para isolar a fonte do dano.
func _test_aaa_threat() -> void:
	var player := get_first_node_in_group("player")
	if player == null:
		return

	for enemy in get_nodes_in_group("enemy"):
		if enemy.get("definition") != null and enemy.definition.id == "soldier_ak":
			enemy.queue_free()
	await physics_frame

	var turret := _find_enemy_by_id("aaa_gun")
	if turret == null:
		_fail("Nenhum canhao AAA disponivel para o teste de ameaca")
		return

	_place_player_facing(player, turret, 26.0)
	await physics_frame

	var health = player.get("health")
	var armor_before: int = health.hp

	## Trava (0,7s) + cadencia (2,6s) + voo do projetil: 5s cobre uma rajada inteira.
	for _i in 300:
		await physics_frame

	_expect(health.hp < armor_before,
		"AAA nao acertou o jogador em 5s a 26m (blindagem seguiu em %d)" % health.hp)


func _find_enemy_by_id(enemy_id: String) -> Node3D:
	for enemy in get_nodes_in_group("enemy"):
		var definition = enemy.get("definition")
		if definition != null and definition.id == enemy_id:
			return enemy
	return null


func _place_player_facing(player: Node3D, target: Node3D, distance: float) -> void:
	var direction := Vector3(1.0, 0.0, 0.0)
	player.global_position = Vector3(
		target.global_position.x + direction.x * distance,
		player.global_position.y,
		target.global_position.z + direction.z * distance
	)
	player.look_at(
		Vector3(target.global_position.x, player.global_position.y, target.global_position.z),
		Vector3.UP
	)


func _make_damage(amount: int, impact_point: Vector3, from_player: bool):
	var types: Dictionary = _damage_event_script.get("Type")
	var damage_type: int = types["EXPLOSIVE"] if from_player else types["BULLET"]
	return _damage_event_script.create(amount, damage_type, Vector3.ZERO, impact_point, from_player, null)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Combat smoke test passed.")
		quit(0)
		return

	print("Combat smoke test FAILED com %d problema(s):" % _failures.size())
	for failure in _failures:
		print("  - %s" % failure)
	quit(1)
