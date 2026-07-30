extends SceneTree

## Teste de fumaca do jogo inteiro. Roda headless e exercita o caminho real:
## missao carregada, mundo montado, combate, recursos, resgate e objetivos.
## Uso: godot --headless --script tools/combat_smoke_test.gd
##
## IMPORTANTE: em modo --script este arquivo vira o main loop e compila ANTES de
## os autoloads existirem. Por isso nada aqui referencia classes do jogo nem
## autoloads de forma estatica: tudo e resolvido em runtime, com load() e por
## grupo/duck typing. Referenciar PlayerHelicopter ou Vfx diretamente
## quebraria a compilacao deste script, nao o jogo.

const EXPECTED_ARMOR := 600
const EXPECTED_SOLDIERS := 15
const EXPECTED_TURRETS := 4
const EXPECTED_SAMS := 2
const EXPECTED_STRUCTURES := 4
const EXPECTED_POWS := 4
const EXPECTED_TECHNICALS := 4
const EXPECTED_TANKS := 3
const EXPECTED_ATTACK_HELIS := 2

var _failures: Array[String] = []
var _damage_event_script: GDScript
var _world: Node


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

	var game_state := _game_state()
	if game_state != null and game_state.has_method("set_current_mission_index"):
		game_state.set_current_mission_index(0)

	_world = scene.instantiate()
	root.add_child(_world)
	current_scene = _world

	await physics_frame
	_world.skip_briefing()

	for _i in 6:
		await physics_frame

	await _test_mission_loaded()
	await _test_campaign_state()
	await _test_spawns()
	await _test_player_setup()
	await _test_weapon_fire()
	await _test_enemy_death()
	await _test_player_damage()
	await _test_pause()
	await _test_hitscan_end_to_end()
	await _test_fuel_drain()
	await _test_pickup()
	await _test_neutral_penalty()
	await _test_rescue_and_delivery()
	await _test_objective_flow()
	await _test_audio()
	await _test_aaa_threat()

	_finish()


func _mission() -> Node:
	return root.get_node_or_null("/root/MissionManager")


func _game_state() -> Node:
	return root.get_node_or_null("/root/GameState")


func _test_mission_loaded() -> void:
	var mission := _mission()
	if mission == null:
		_fail("Autoload MissionManager nao encontrado")
		return

	_expect(mission.running, "Missao deveria estar rodando apos o briefing")
	_expect(mission.objectives.size() == 4, "Missao deveria ter 4 objetivos, tem %d" % mission.objectives.size())
	_expect(not mission.get_title().is_empty(), "Missao sem titulo")

	## O objetivo do QG comeca travado pelos radares.
	var visible: Array = mission.get_visible_objectives()
	var visible_ids: Array = []
	for objective in visible:
		visible_ids.append(objective["id"])
	_expect(not visible_ids.has("hq"), "Objetivo do QG deveria comecar travado pelos radares")


func _test_campaign_state() -> void:
	var game_state := _game_state()
	if game_state == null:
		_fail("Autoload GameState nao encontrado")
		return

	_expect(game_state.get_mission_count() >= 2, "Campanha deveria ter pelo menos 2 missoes")
	_expect(game_state.get_current_mission_path().ends_with("slice_01.json"),
		"Smoke test deveria iniciar na primeira missao")


func _test_spawns() -> void:
	var counts := {}
	for enemy in get_nodes_in_group("enemy"):
		var definition = enemy.get("definition")
		if definition == null:
			continue
		counts[definition.id] = int(counts.get(definition.id, 0)) + 1

	var soldiers: int = counts.get("soldier_ak", 0)
	var turrets: int = counts.get("aaa_gun", 0)
	var sams: int = counts.get("sam_launcher", 0)

	_expect(counts.get("technical", 0) == EXPECTED_TECHNICALS,
		"Esperado %d picapes, achou %d" % [EXPECTED_TECHNICALS, counts.get("technical", 0)])
	_expect(counts.get("tank", 0) == EXPECTED_TANKS,
		"Esperado %d tanques, achou %d" % [EXPECTED_TANKS, counts.get("tank", 0)])
	_expect(counts.get("enemy_helicopter", 0) == EXPECTED_ATTACK_HELIS,
		"Esperado %d helicopteros inimigos, achou %d" % [EXPECTED_ATTACK_HELIS, counts.get("enemy_helicopter", 0)])

	## O aereo tem de nascer no ar, senao ele vira um tanque estranho no chao.
	for enemy in get_nodes_in_group("enemy"):
		var definition = enemy.get("definition")
		if definition != null and definition.id == "enemy_helicopter":
			_expect(enemy.global_position.y > 8.0,
				"Helicoptero inimigo deveria nascer no ar, nasceu em y=%.1f" % enemy.global_position.y)
			break

	_expect(soldiers == EXPECTED_SOLDIERS, "Esperado %d soldados, achou %d" % [EXPECTED_SOLDIERS, soldiers])
	_expect(turrets == EXPECTED_TURRETS, "Esperado %d canhoes AAA, achou %d" % [EXPECTED_TURRETS, turrets])
	_expect(sams == EXPECTED_SAMS, "Esperado %d lancadores SAM, achou %d" % [EXPECTED_SAMS, sams])

	var structures := get_nodes_in_group("structure")
	_expect(structures.size() == EXPECTED_STRUCTURES,
		"Esperado %d estruturas, achou %d" % [EXPECTED_STRUCTURES, structures.size()])

	var pows := get_nodes_in_group("pow")
	_expect(pows.size() == EXPECTED_POWS, "Esperado %d resgatados, achou %d" % [EXPECTED_POWS, pows.size()])

	_expect(not get_nodes_in_group("pickup").is_empty(), "Nenhum pickup no mapa")
	_expect(get_first_node_in_group("friendly_base") != null, "Base amiga nao foi criada")


func _test_player_setup() -> void:
	var player := get_first_node_in_group("player")
	_expect(player != null, "Helicoptero do jogador nao entrou no grupo player")
	if player == null:
		return

	var health = player.get("health")
	_expect(health != null, "Jogador sem componente Health")
	if health != null:
		_expect(health.max_hp == EXPECTED_ARMOR,
			"Blindagem maxima deveria ser %d, e %d" % [EXPECTED_ARMOR, health.max_hp])

	var weapons = player.get("weapons")
	_expect(weapons != null and weapons.runtimes.size() == 3, "Jogador deveria ter 3 armas carregadas")
	_expect(player.get("targeting") != null, "Sistema de mira nao foi criado")
	_expect(player.get("fuel") != null, "Sistema de combustivel nao foi criado")
	_expect(player.get("winch") != null, "Guincho de resgate nao foi criado")
	_expect(_world.get_node_or_null("Hud") != null, "HUD nao foi criado")
	_expect(_world.get_node_or_null("MissionWorld") != null, "Mundo da missao nao foi montado")


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
	var game_state := _game_state()
	if game_state == null:
		_fail("Autoload GameState nao encontrado")
		return

	var victim := _find_enemy_by_id("soldier_ak")
	if victim == null:
		_fail("Sem soldados para testar morte")
		return

	var score_before: int = game_state.score
	var count_before := get_nodes_in_group("enemy").size()

	victim.take_damage(_make_damage(9999, victim.global_position, true))

	## Espera em tempo real: durante o hitstop o relogio do jogo esta parado.
	await _wait_real(0.25)

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

	var flash := _world.find_child("DamageFlash", true, false)
	_expect(flash != null and flash.modulate.a > 0.0,
		"HUD deveria acender o flash vermelho ao levar dano")


## Pausa por evento: ESC congela a arvore, escolher CONTINUAR descongela.
## Input.action_press nao passa por _unhandled_input; e preciso injetar o
## evento de verdade com parse_input_event.
func _test_pause() -> void:
	_press_action_event("pause")
	await process_frame
	await process_frame

	_expect(root.get_tree().paused, "ESC deveria pausar o jogo")
	_expect(_world.find_child("PauseScreen", true, false) != null, "Menu de pausa nao apareceu")

	## Segundo ESC = CONTINUAR (opcao 0).
	_press_action_event("pause")
	await process_frame
	await process_frame

	_expect(not root.get_tree().paused, "Segundo ESC deveria despausar")
	await physics_frame


func _press_action_event(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


## Loop completo do jogador: mira assistida -> hitscan -> dano no inimigo.
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


func _test_fuel_drain() -> void:
	var player := get_first_node_in_group("player")
	if player == null:
		return

	var fuel = player.get("fuel")
	if fuel == null:
		return

	var before: float = fuel.fuel
	for _i in 90:
		await physics_frame

	_expect(fuel.fuel < before, "Combustivel deveria drenar em voo (seguiu em %.2f)" % fuel.fuel)


func _test_pickup() -> void:
	var player := get_first_node_in_group("player")
	if player == null:
		return

	var fuel_crate: Node3D = null
	for node in get_nodes_in_group("pickup"):
		if node.type == 0:
			fuel_crate = node
			break

	if fuel_crate == null:
		_fail("Nenhum pickup de combustivel no mapa")
		return

	var fuel = player.get("fuel")
	fuel.fuel = 20.0

	player.global_position = Vector3(fuel_crate.global_position.x, player.global_position.y, fuel_crate.global_position.z)
	for _i in 6:
		await process_frame

	_expect(fuel.fuel > 20.0, "Pickup de combustivel nao reabasteceu (seguiu em %.2f)" % fuel.fuel)
	_expect(not is_instance_valid(fuel_crate), "Pickup coletado deveria sumir do mapa")


func _test_neutral_penalty() -> void:
	var mission := _mission()
	var game_state := _game_state()
	if mission == null or game_state == null:
		return

	var house = get_first_node_in_group("neutral_structure")
	if house == null:
		_fail("Nenhuma estrutura neutra encontrada na vila")
		return

	var hits_before: int = mission.civilian_hits
	var score_before: int = game_state.score

	house.take_damage(_make_damage(9999, house.global_position, true))
	await physics_frame

	_expect(mission.civilian_hits == hits_before + 1,
		"Atingir a vila neutra deveria aumentar civilian_hits")
	_expect(game_state.score < score_before,
		"Atingir a vila neutra deveria aplicar penalidade de score")


## Resgate no guincho e entrega na base, que e o que fecha o objetivo de resgate.
func _test_rescue_and_delivery() -> void:
	var player := get_first_node_in_group("player")
	var base := get_first_node_in_group("friendly_base") as Node3D
	var mission := _mission()
	if player == null or base == null or mission == null:
		return

	var pows := get_nodes_in_group("pow")
	if pows.is_empty():
		_fail("Nenhum resgatado no mapa")
		return

	var pow_node: Node3D = pows[0]
	var winch = player.get("winch")
	var fuel = player.get("fuel")

	player.global_position = Vector3(pow_node.global_position.x, player.global_position.y, pow_node.global_position.z)
	await physics_frame

	Input.action_press("winch")
	for _i in 320:
		await physics_frame
	Input.action_release("winch")
	await physics_frame

	_expect(winch.passengers == 1, "Guincho deveria ter 1 resgatado a bordo, tem %d" % winch.passengers)
	_expect(not is_instance_valid(pow_node), "Resgatado deveria sair do mapa apos a subida")

	## Entrega na base: pairar sobre o pad reabastece e desembarca.
	fuel.fuel = 15.0
	player.global_position = Vector3(base.global_position.x, player.global_position.y, base.global_position.z)

	for _i in 300:
		await physics_frame

	_expect(fuel.fuel > 15.0, "Base nao reabasteceu (combustivel seguiu em %.2f)" % fuel.fuel)
	_expect(winch.passengers == 0, "Base deveria receber os resgatados (ainda tem %d)" % winch.passengers)
	_expect(mission.rescued_delivered >= 1,
		"Missao nao registrou a entrega (rescued_delivered=%d)" % mission.rescued_delivered)


## Destruir os dois radares fecha um objetivo e destrava o do QG.
func _test_objective_flow() -> void:
	var mission := _mission()
	if mission == null:
		return

	for node in get_nodes_in_group("structure"):
		if node.structure_id == "radar_1" or node.structure_id == "radar_2":
			node.take_damage(_make_damage(9999, node.global_position, true))
			await physics_frame

	for _i in 4:
		await physics_frame

	var radar_objective = _find_objective(mission, "radar")
	_expect(radar_objective != null and radar_objective["done"],
		"Objetivo dos radares deveria estar concluido apos destruir os dois")

	var visible_ids: Array = []
	for objective in mission.get_visible_objectives():
		visible_ids.append(objective["id"])
	_expect(visible_ids.has("hq"), "Objetivo do QG deveria destravar apos os radares")


## Audio sintetizado: buses criados, loops presos ao jogador e streams validos.
func _test_audio() -> void:
	var audio := root.get_node_or_null("/root/AudioManager")
	if audio == null:
		_fail("Autoload AudioManager nao encontrado")
		return

	for bus_name in ["Music", "SFX", "UI"]:
		_expect(AudioServer.get_bus_index(bus_name) != -1, "Bus de audio %s nao foi criado" % bus_name)

	var player := get_first_node_in_group("player")
	if player == null:
		return

	var rotor := player.get_node_or_null("RotorLoop") as AudioStreamPlayer3D
	_expect(rotor != null, "Loop do rotor nao foi preso ao helicoptero")
	if rotor != null:
		_expect(rotor.playing, "Loop do rotor deveria estar tocando")
		var stream := rotor.stream as AudioStreamWAV
		_expect(stream != null and stream.data.size() > 0, "Stream do rotor esta vazio")
		_expect(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"Rotor precisa estar em loop, senao o som some depois de 1s")

	_expect(player.get_node_or_null("TurbineLoop") != null, "Loop da turbina nao foi criado")

	## Disparar nao pode gerar erro nem stream nulo.
	audio.play_at(0, player.global_position, -20.0)
	audio.play_ui(12, -30.0)
	await physics_frame


## O canhao AAA precisa ser uma ameaca real, nao um alvo estatico.
## Roda por ultimo porque remove os soldados para isolar a fonte do dano.
func _test_aaa_threat() -> void:
	var player := get_first_node_in_group("player")
	if player == null:
		return

	for enemy in get_nodes_in_group("enemy"):
		var definition = enemy.get("definition")
		if definition != null and definition.id != "aaa_gun":
			enemy.queue_free()
	await physics_frame

	var turret := _find_enemy_by_id("aaa_gun")
	if turret == null:
		_fail("Nenhum canhao AAA disponivel para o teste de ameaca")
		return

	_place_player_facing(player, turret, 26.0)
	await physics_frame

	var health = player.get("health")
	health.revive()
	var armor_before: int = health.hp

	## Trava (0,7s) + cadencia (2,6s) + voo do projetil: 5s cobre uma rajada inteira.
	for _i in 300:
		await physics_frame

	_expect(health.hp < armor_before,
		"AAA nao acertou o jogador em 5s a 26m (blindagem seguiu em %d)" % health.hp)


func _find_objective(mission: Node, objective_id: String):
	for objective in mission.objectives:
		if objective["id"] == objective_id:
			return objective
	return null


func _find_enemy_by_id(enemy_id: String) -> Node3D:
	for enemy in get_nodes_in_group("enemy"):
		var definition = enemy.get("definition")
		if definition != null and definition.id == enemy_id:
			return enemy
	return null


func _place_player_facing(player: Node3D, target: Node3D, distance: float) -> void:
	player.global_position = Vector3(
		target.global_position.x + distance,
		player.global_position.y,
		target.global_position.z
	)
	player.look_at(
		Vector3(target.global_position.x, player.global_position.y, target.global_position.z),
		Vector3.UP
	)


func _make_damage(amount: int, impact_point: Vector3, from_player: bool):
	var types: Dictionary = _damage_event_script.get("Type")
	var damage_type: int = types["EXPLOSIVE"] if from_player else types["BULLET"]
	return _damage_event_script.create(amount, damage_type, Vector3.ZERO, impact_point, from_player, null)


## Espera em tempo real, imune a time_scale (necessario durante o hitstop).
func _wait_real(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


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
