class_name AudioSynth
extends RefCounted

## Sintese de audio em codigo. Todo som do jogo nasce aqui, amostra por amostra,
## em vez de vir de arquivo. Duas razoes: o repo fica sem nenhum asset de audio
## de terceiro (politica do projeto) e o som pode ser afinado por parametro.
##
## Formato: PCM 16 bits mono. Os loops tem duracao escolhida para fechar em um
## numero inteiro de ciclos, senao estala na emenda.

const MIX_RATE := 22050


static func rotor_loop() -> AudioStreamWAV:
	## 20 passagens de pa por segundo (4 pas a ~5 rotacoes/s).
	var pulses_per_second := 20.0
	var samples := _samples_for(1.0)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	var filter_state := 0.0
	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var phase := fmod(t * pulses_per_second, 1.0)
		var thump_env: float = exp(-phase * 7.0)

		var body := sin(TAU * 52.0 * t) * 0.62 * thump_env
		body += sin(TAU * 104.0 * t) * 0.18 * thump_env

		## Ruido de ar filtrado, o "corpo" do rotor entre as batidas.
		var noise := randf_range(-1.0, 1.0)
		filter_state = lerpf(filter_state, noise, 0.06)
		body += filter_state * 0.22 * (0.35 + 0.65 * thump_env)

		buffer[index] = body * 0.75

	return _to_stream(buffer, true)


static func turbine_loop() -> AudioStreamWAV:
	var samples := _samples_for(1.0)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	var filter_state := 0.0
	for index in samples:
		var t := float(index) / float(MIX_RATE)

		var whine := sin(TAU * 430.0 * t) * 0.3
		whine += sin(TAU * 860.0 * t) * 0.14
		whine += sin(TAU * 1290.0 * t) * 0.06

		var noise := randf_range(-1.0, 1.0)
		filter_state = lerpf(filter_state, noise, 0.4)
		whine += filter_state * 0.1

		buffer[index] = whine * 0.55

	return _to_stream(buffer, true)


static func machinegun_shot() -> AudioStreamWAV:
	var samples := _samples_for(0.13)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	var filter_state := 0.0
	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var crack_env: float = exp(-t * 52.0)
		var body_env: float = exp(-t * 26.0)

		var noise := randf_range(-1.0, 1.0)
		filter_state = lerpf(filter_state, noise, 0.55)

		var signal_value := filter_state * 0.7 * crack_env
		signal_value += sin(TAU * 150.0 * t) * 0.45 * body_env
		signal_value += sin(TAU * 70.0 * t) * 0.3 * body_env

		buffer[index] = signal_value * 0.8

	return _to_stream(buffer)


static func enemy_shot() -> AudioStreamWAV:
	var samples := _samples_for(0.1)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	var filter_state := 0.0
	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var env: float = exp(-t * 60.0)

		var noise := randf_range(-1.0, 1.0)
		filter_state = lerpf(filter_state, noise, 0.72)

		buffer[index] = (filter_state * 0.75 + sin(TAU * 230.0 * t) * 0.25) * env * 0.7

	return _to_stream(buffer)


static func rocket_launch() -> AudioStreamWAV:
	var samples := _samples_for(0.55)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	var filter_state := 0.0
	for index in samples:
		var t := float(index) / float(MIX_RATE)
		## Ataque rapido e cauda longa: o "shhhh" do foguete saindo do trilho.
		var env: float = minf(1.0, t * 60.0) * exp(-t * 5.5)

		var noise := randf_range(-1.0, 1.0)
		## O filtro abre com o tempo, simulando o jato ganhando brilho.
		filter_state = lerpf(filter_state, noise, 0.18 + 0.5 * clampf(t * 3.0, 0.0, 1.0))

		var signal_value := filter_state * 0.85
		signal_value += sin(TAU * lerpf(120.0, 60.0, clampf(t * 2.5, 0.0, 1.0)) * t) * 0.35 * env

		buffer[index] = signal_value * env * 0.9

	return _to_stream(buffer)


static func missile_launch() -> AudioStreamWAV:
	var samples := _samples_for(0.8)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	var filter_state := 0.0
	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var env: float = minf(1.0, t * 40.0) * exp(-t * 3.4)

		var noise := randf_range(-1.0, 1.0)
		filter_state = lerpf(filter_state, noise, 0.12 + 0.35 * clampf(t * 2.0, 0.0, 1.0))

		var signal_value := filter_state * 0.8
		signal_value += sin(TAU * lerpf(95.0, 42.0, clampf(t * 1.6, 0.0, 1.0)) * t) * 0.5

		buffer[index] = signal_value * env * 0.95

	return _to_stream(buffer)


static func explosion(scale_factor: float = 1.0) -> AudioStreamWAV:
	var duration := clampf(1.1 * scale_factor, 0.5, 2.2)
	var samples := _samples_for(duration)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	var low_state := 0.0
	var mid_state := 0.0

	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var crack_env: float = exp(-t * 18.0)
		var body_env: float = exp(-t * (3.6 / scale_factor))

		var noise := randf_range(-1.0, 1.0)

		## Duas camadas de ruido: o estalo brilhante e o corpo grave que rola.
		mid_state = lerpf(mid_state, noise, 0.45)
		low_state = lerpf(low_state, noise, 0.035)

		var signal_value := mid_state * 0.55 * crack_env
		signal_value += low_state * 0.9 * body_env

		## Sub que desce: e o que da peso fisico a explosao.
		var sub_freq := lerpf(88.0, 32.0, clampf(t * 1.4, 0.0, 1.0))
		signal_value += sin(TAU * sub_freq * t) * 0.75 * body_env

		buffer[index] = clampf(signal_value * 0.85, -1.0, 1.0)

	return _to_stream(buffer)


static func impact() -> AudioStreamWAV:
	var samples := _samples_for(0.09)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	var filter_state := 0.0
	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var env: float = exp(-t * 70.0)
		var noise := randf_range(-1.0, 1.0)
		filter_state = lerpf(filter_state, noise, 0.5)
		buffer[index] = filter_state * env * 0.55

	return _to_stream(buffer)


static func armor_hit() -> AudioStreamWAV:
	var samples := _samples_for(0.28)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var env: float = exp(-t * 16.0)
		## Metal batendo em metal: harmonicos inarmonicos.
		var signal_value := sin(TAU * 320.0 * t) * 0.4
		signal_value += sin(TAU * 517.0 * t) * 0.3
		signal_value += sin(TAU * 913.0 * t) * 0.18
		signal_value += randf_range(-1.0, 1.0) * 0.25 * exp(-t * 60.0)
		buffer[index] = signal_value * env * 0.7

	return _to_stream(buffer)


static func pickup() -> AudioStreamWAV:
	return _tone_sequence([660.0, 880.0, 1320.0], 0.075, 0.42)


static func rescue_complete() -> AudioStreamWAV:
	return _tone_sequence([523.0, 659.0, 784.0, 1047.0], 0.11, 0.45)


static func objective_complete() -> AudioStreamWAV:
	return _tone_sequence([392.0, 523.0, 659.0], 0.16, 0.5)


static func alarm() -> AudioStreamWAV:
	var samples := _samples_for(0.34)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var env: float = minf(1.0, t * 90.0) * exp(-t * 5.0)
		## Onda quadrada suave: mais urgente que uma senoide pura.
		var square := signf(sin(TAU * 880.0 * t)) * 0.35 + sin(TAU * 880.0 * t) * 0.4
		buffer[index] = square * env * 0.5

	return _to_stream(buffer)


static func ui_click() -> AudioStreamWAV:
	var samples := _samples_for(0.05)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var env: float = exp(-t * 110.0)
		buffer[index] = (sin(TAU * 1200.0 * t) * 0.5 + randf_range(-1.0, 1.0) * 0.2) * env * 0.4

	return _to_stream(buffer)


static func winch_loop() -> AudioStreamWAV:
	var samples := _samples_for(0.5)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	for index in samples:
		var t := float(index) / float(MIX_RATE)
		## Motor de guincho: dentes de serra a 24 Hz.
		var ratchet := fmod(t * 24.0, 1.0)
		var env: float = 0.35 + 0.65 * exp(-ratchet * 6.0)
		var signal_value := sin(TAU * 190.0 * t) * 0.3 + randf_range(-1.0, 1.0) * 0.12
		buffer[index] = signal_value * env * 0.45

	return _to_stream(buffer, true)


## Tema militar de 16 bits. A composicao mora em MusicTracker; aqui fica so a
## porta de entrada, para o AudioManager nao precisar saber de tracker nenhum.
static func music_layer(intense: bool) -> AudioStreamWAV:
	return MusicTracker.render(intense)


## ---------------------------------------------------------------- internos

static func _tone_sequence(frequencies: Array, note_duration: float, gain: float) -> AudioStreamWAV:
	var total := note_duration * float(frequencies.size())
	var samples := _samples_for(total)
	var buffer := PackedFloat32Array()
	buffer.resize(samples)

	for index in samples:
		var t := float(index) / float(MIX_RATE)
		var note_index := int(t / note_duration)
		if note_index >= frequencies.size():
			note_index = frequencies.size() - 1

		var local_time := t - float(note_index) * note_duration
		var env: float = minf(1.0, local_time * 120.0) * exp(-local_time * 9.0)
		var frequency: float = frequencies[note_index]

		var signal_value := sin(TAU * frequency * local_time) * 0.7
		signal_value += sin(TAU * frequency * 2.0 * local_time) * 0.2

		buffer[index] = signal_value * env * gain

	return _to_stream(buffer)


static func _samples_for(seconds: float) -> int:
	return int(round(seconds * float(MIX_RATE)))


static func _to_stream(buffer: PackedFloat32Array, looping: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)

	for index in buffer.size():
		var value := int(clampf(buffer[index], -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data

	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buffer.size()

	return stream
