extends Node

## Mixagem e disparo de som. Os buses sao criados em codigo (Master > Music /
## SFX / UI) e todos os streams sao sintetizados uma vez no boot por AudioSynth.
##
## Regra de mixagem: o rotor do jogador esta sempre presente mas nunca domina;
## explosao e tiro tem prioridade e a musica abaixa sozinha no combate.

const MAX_HEARING_DISTANCE := 90.0

enum Sfx {
	MACHINEGUN,
	ENEMY_SHOT,
	ROCKET,
	MISSILE,
	EXPLOSION_SMALL,
	EXPLOSION_BIG,
	IMPACT,
	ARMOR_HIT,
	PICKUP,
	RESCUE,
	OBJECTIVE,
	ALARM,
	UI_CLICK,
}

var _streams: Dictionary = {}
var _rotor_player: AudioStreamPlayer3D
var _turbine_player: AudioStreamPlayer3D
var _winch_player: AudioStreamPlayer3D
var _music_calm: AudioStreamPlayer
var _music_combat: AudioStreamPlayer
var _ui_player: AudioStreamPlayer

var _combat_heat := 0.0
var _carrier: Node3D
var _enabled := true
var _active_players: Array[Dictionary] = []
var _music_thread: Thread


func _ready() -> void:
	## Musica continua no menu de pausa: o resto da arvore congela, este nao.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_build_streams()
	_build_ui_player()
	_start_music_render()


## Os loops de rotor, turbina, guincho e trilha tocam ate o fim do processo.
## Sem soltar as referencias no desligamento, cada um aparece como instancia
## vazada no encerramento (AudioStreamWAV + AudioStreamPlaybackWAV).
func _exit_tree() -> void:
	release_all()


## Publico porque o smoke test roda em modo --script e encerra com quit(),
## que atropela a ordem normal de desligamento dos autoloads.
func release_all() -> void:
	_finish_music_render()

	var persistent := [_rotor_player, _turbine_player, _winch_player, _music_calm, _music_combat, _ui_player]

	for entry in _active_players:
		var player = entry["player"]
		if is_instance_valid(player):
			persistent.append(player)
	_active_players.clear()

	for player in persistent:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

	_streams.clear()


## Liga os loops presos ao helicoptero. Chamado quando o jogador nasce.
func attach_to_player(player: Node3D) -> void:
	_carrier = player

	_rotor_player = _make_3d_player(_streams["rotor"], "SFX", -6.0)
	_rotor_player.name = "RotorLoop"
	player.add_child(_rotor_player)
	_rotor_player.play()

	_turbine_player = _make_3d_player(_streams["turbine"], "SFX", -18.0)
	_turbine_player.name = "TurbineLoop"
	player.add_child(_turbine_player)
	_turbine_player.play()

	_winch_player = _make_3d_player(_streams["winch"], "SFX", -10.0)
	_winch_player.name = "WinchLoop"
	player.add_child(_winch_player)

	if player.winch != null:
		player.winch.state_changed.connect(_on_winch_state_changed)


func start_music() -> void:
	_finish_music_render()

	if _music_calm != null and not _music_calm.playing:
		_music_calm.play()
	if _music_combat != null and not _music_combat.playing:
		_music_combat.play()


## O tema e uma composicao inteira renderizada nota a nota: ~1,9 s de CPU. Feito
## no _ready isso viraria tela preta no boot, entao roda em thread enquanto o
## jogador le o briefing. start_music() so espera se ela ainda nao terminou.
func _start_music_render() -> void:
	_music_thread = Thread.new()
	_music_thread.start(_render_music_layers)


func _render_music_layers() -> Array:
	return [AudioSynth.music_layer(false), AudioSynth.music_layer(true)]


func _finish_music_render() -> void:
	if _music_thread == null:
		return

	var layers: Array = _music_thread.wait_to_finish()
	_music_thread = null
	_build_music(layers[0], layers[1])


func stop_music() -> void:
	if _music_calm != null:
		_music_calm.stop()
	if _music_combat != null:
		_music_combat.stop()


## Som posicional no mundo.
func play_at(sfx: int, position: Vector3, volume_db: float = 0.0, pitch_variation: float = 0.06) -> void:
	if not _enabled:
		return

	var stream := _stream_for(sfx)
	if stream == null:
		return

	var host := get_tree().current_scene
	if host == null:
		return

	var player := _make_3d_player(stream, "SFX", volume_db)
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	host.add_child(player)
	player.global_position = position
	player.play()

	## A limpeza e por varredura, nao por sinal "finished" com lambda: sem
	## dispositivo de audio (headless, CI) o sinal nunca chega, e uma lambda que
	## captura o no ainda dispara depois dele ser liberado.
	var lifetime := stream.get_length() / maxf(0.1, player.pitch_scale) + 0.4
	_active_players.append({
		"player": player,
		"deadline": Time.get_ticks_msec() + int(lifetime * 1000.0),
	})


## Som sem posicao (UI, alarmes de cabine).
func play_ui(sfx: int, volume_db: float = 0.0) -> void:
	if not _enabled or _ui_player == null:
		return

	var stream := _stream_for(sfx)
	if stream == null:
		return

	_ui_player.stream = stream
	_ui_player.volume_db = volume_db
	_ui_player.play()


func play_ui_click() -> void:
	play_ui(Sfx.UI_CLICK, -6.0)


## Sobe o "calor" de combate, que controla o crossfade da trilha.
func report_combat() -> void:
	_combat_heat = 1.0


func _process(delta: float) -> void:
	_combat_heat = maxf(0.0, _combat_heat - delta * 0.35)
	_update_music_mix()
	_update_rotor_pitch()
	_sweep_players()


func _sweep_players() -> void:
	var now := Time.get_ticks_msec()

	for index in range(_active_players.size() - 1, -1, -1):
		var entry := _active_players[index]
		var player = entry["player"]

		if not is_instance_valid(player):
			_active_players.remove_at(index)
			continue

		if player.playing and now < int(entry["deadline"]):
			continue

		_active_players.remove_at(index)
		player.queue_free()


func _update_music_mix() -> void:
	if _music_calm == null or _music_combat == null:
		return

	var heat := clampf(_combat_heat, 0.0, 1.0)
	_music_calm.volume_db = linear_to_db(clampf(1.0 - heat * 0.75, 0.001, 1.0)) - 16.0
	_music_combat.volume_db = linear_to_db(clampf(heat, 0.001, 1.0)) - 13.0


## Rotor acompanha a velocidade: acelerar muda o tom, e o que da sensacao de peso.
func _update_rotor_pitch() -> void:
	if _rotor_player == null or _carrier == null or not is_instance_valid(_carrier):
		return

	var ratio := 0.0
	if _carrier.has_method("get_speed_ratio"):
		ratio = _carrier.get_speed_ratio()

	_rotor_player.pitch_scale = lerpf(_rotor_player.pitch_scale, 0.92 + ratio * 0.22, 0.08)
	if _turbine_player != null:
		_turbine_player.pitch_scale = lerpf(_turbine_player.pitch_scale, 0.96 + ratio * 0.14, 0.06)


func _on_winch_state_changed(state: int) -> void:
	if _winch_player == null:
		return

	if state == WinchSystem.State.IDLE:
		_winch_player.stop()
	elif not _winch_player.playing:
		_winch_player.play()


func _stream_for(sfx: int) -> AudioStream:
	match sfx:
		Sfx.MACHINEGUN:
			return _streams["machinegun"]
		Sfx.ENEMY_SHOT:
			return _streams["enemy_shot"]
		Sfx.ROCKET:
			return _streams["rocket"]
		Sfx.MISSILE:
			return _streams["missile"]
		Sfx.EXPLOSION_SMALL:
			return _streams["explosion_small"]
		Sfx.EXPLOSION_BIG:
			return _streams["explosion_big"]
		Sfx.IMPACT:
			return _streams["impact"]
		Sfx.ARMOR_HIT:
			return _streams["armor_hit"]
		Sfx.PICKUP:
			return _streams["pickup"]
		Sfx.RESCUE:
			return _streams["rescue"]
		Sfx.OBJECTIVE:
			return _streams["objective"]
		Sfx.ALARM:
			return _streams["alarm"]
		Sfx.UI_CLICK:
			return _streams["ui_click"]
	return null


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")

	## Compressor leve no Master segura os picos de explosao sem achatar o resto.
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var compressor := AudioEffectCompressor.new()
		compressor.threshold = -14.0
		compressor.ratio = 3.5
		compressor.attack_us = 12.0
		compressor.release_ms = 180.0
		AudioServer.add_bus_effect(master, compressor)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -4.0)


func _build_streams() -> void:
	_streams["rotor"] = AudioSynth.rotor_loop()
	_streams["turbine"] = AudioSynth.turbine_loop()
	_streams["winch"] = AudioSynth.winch_loop()
	_streams["machinegun"] = AudioSynth.machinegun_shot()
	_streams["enemy_shot"] = AudioSynth.enemy_shot()
	_streams["rocket"] = AudioSynth.rocket_launch()
	_streams["missile"] = AudioSynth.missile_launch()
	_streams["explosion_small"] = AudioSynth.explosion(0.7)
	_streams["explosion_big"] = AudioSynth.explosion(1.6)
	_streams["impact"] = AudioSynth.impact()
	_streams["armor_hit"] = AudioSynth.armor_hit()
	_streams["pickup"] = AudioSynth.pickup()
	_streams["rescue"] = AudioSynth.rescue_complete()
	_streams["objective"] = AudioSynth.objective_complete()
	_streams["alarm"] = AudioSynth.alarm()
	_streams["ui_click"] = AudioSynth.ui_click()


func _build_music(calm_stream: AudioStream, combat_stream: AudioStream) -> void:
	_music_calm = AudioStreamPlayer.new()
	_music_calm.name = "MusicCalm"
	_music_calm.stream = calm_stream
	_music_calm.bus = "Music"
	_music_calm.volume_db = -16.0
	add_child(_music_calm)

	_music_combat = AudioStreamPlayer.new()
	_music_combat.name = "MusicCombat"
	_music_combat.stream = combat_stream
	_music_combat.bus = "Music"
	_music_combat.volume_db = -60.0
	add_child(_music_combat)


func _build_ui_player() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiPlayer"
	_ui_player.bus = "UI"
	add_child(_ui_player)


func _make_3d_player(stream: AudioStream, bus: String, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.max_distance = MAX_HEARING_DISTANCE
	player.unit_size = 14.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	return player
