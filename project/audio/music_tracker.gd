class_name MusicTracker
extends RefCounted

## Tema militar no estilo dos consoles de 16 bits: onda quadrada, serra, ruido
## para percussao e nada de sample. E um tracker de verdade, com padroes de
## notas em grade de semicolcheia, nao um drone com filtro.
##
## Duas versoes do mesmo tema saem daqui:
##   patrulha  baixo + arpejo + caixa leve, para voar sem contato
##   combate   entra a melodia principal, contracanto e bateria cheia
## O AudioManager faz crossfade entre as duas conforme o "calor de combate",
## entao as duas PRECISAM ter a mesma duracao e o mesmo andamento para casar.
##
## Tom: re menor. Andamento de marcha, 132 BPM.

const MIX_RATE := 22050
const BPM := 132.0
const STEPS_PER_BEAT := 4
const BEATS_PER_BAR := 4
const BARS := 8

## Notas MIDI. 0 significa silencio; -1 significa "segura a nota anterior".
const REST := 0
const HOLD := -1

## Melodia principal, em pares [nota, duracao em semicolcheias].
## Frase de pergunta e resposta: quatro compassos sobem, quatro respondem grave.
const LEAD := [
	[74, 3], [REST, 1], [74, 2], [77, 2],
	[76, 3], [REST, 1], [74, 2], [69, 2],
	[72, 3], [REST, 1], [72, 2], [74, 2],
	[76, 6], [REST, 2],
	[77, 3], [REST, 1], [77, 2], [79, 2],
	[81, 3], [REST, 1], [79, 2], [77, 2],
	[76, 3], [REST, 1], [74, 2], [72, 2],
	[74, 8],
	[69, 3], [REST, 1], [69, 2], [72, 2],
	[74, 3], [REST, 1], [72, 2], [69, 2],
	[70, 3], [REST, 1], [70, 2], [72, 2],
	[74, 6], [REST, 2],
	[77, 2], [76, 2], [74, 2], [72, 2],
	[70, 3], [REST, 1], [69, 4],
	[67, 3], [REST, 1], [69, 2], [70, 2],
	[69, 8],
]

## Baixo em colcheias marcadas: o motor da marcha.
const BASS = [
	[38, 2], [38, 2], [38, 2], [45, 2],
	[38, 2], [38, 2], [41, 2], [43, 2],
	[36, 2], [36, 2], [36, 2], [43, 2],
	[36, 2], [36, 2], [40, 2], [41, 2],
	[41, 2], [41, 2], [41, 2], [48, 2],
	[41, 2], [41, 2], [45, 2], [46, 2],
	[38, 2], [38, 2], [38, 2], [45, 2],
	[38, 2], [38, 2], [41, 2], [43, 2],
	[34, 2], [34, 2], [34, 2], [41, 2],
	[34, 2], [34, 2], [38, 2], [39, 2],
	[35, 2], [35, 2], [35, 2], [42, 2],
	[35, 2], [35, 2], [38, 2], [40, 2],
	[38, 2], [38, 2], [41, 2], [43, 2],
	[34, 2], [34, 2], [37, 2], [38, 2],
	[31, 2], [31, 2], [34, 2], [36, 2],
	[33, 2], [33, 2], [33, 2], [33, 2],
]

## Contracanto em quintas, entra so no combate. Da o peso de metais.
const HARMONY = [
	[62, 4], [65, 4], [64, 4], [62, 4],
	[60, 4], [62, 4], [64, 8],
	[65, 4], [69, 4], [67, 4], [65, 4],
	[64, 4], [62, 4], [62, 8],
	[57, 4], [60, 4], [62, 4], [60, 4],
	[58, 4], [60, 4], [62, 8],
	[65, 4], [64, 4], [62, 4], [58, 4],
	[57, 4], [55, 4], [57, 8],
]

## Arpejo de acompanhamento, presente nas duas versoes.
const ARP = [
	[62, 1], [65, 1], [69, 1], [65, 1],
	[62, 1], [65, 1], [69, 1], [65, 1],
	[60, 1], [64, 1], [67, 1], [64, 1],
	[60, 1], [64, 1], [67, 1], [64, 1],
]

## Bateria por compasso, 16 passos: K bumbo, S caixa, h chimbal, . silencio.
const DRUMS_FULL := [
	"K.hhS.hhK.hKS.hh",
	"K.hhS.hhK.hKS.hS",
	"K.hhS.hhK.hKS.hh",
	"K.hhS.hhKShKSSSS",
	"K.hhS.hhK.hKS.hh",
	"K.hhS.hhK.hKS.hS",
	"K.hhS.hhK.hKS.hh",
	"KShKSShKSShKSSSS",
]

## Na patrulha so a caixa marcando, sem bumbo pesado: tensao, nao ataque.
const DRUMS_PATROL := [
	"..h...h...h...h.",
	"..h...h...h...hS",
	"..h...h...h...h.",
	"..h...h...h.S.hS",
	"..h...h...h...h.",
	"..h...h...h...hS",
	"..h...h...h...h.",
	"..h.S.h...h.SShS",
]


static func total_steps() -> int:
	return BARS * BEATS_PER_BAR * STEPS_PER_BEAT


static func step_seconds() -> float:
	return 60.0 / BPM / float(STEPS_PER_BEAT)


static func duration() -> float:
	return float(total_steps()) * step_seconds()


## Renderiza o tema. `intense` liga melodia, contracanto e bateria cheia.
static func render(intense: bool) -> AudioStreamWAV:
	var steps := total_steps()
	var samples := int(round(duration() * float(MIX_RATE)))
	var buffer := PackedFloat32Array()
	buffer.resize(samples)
	buffer.fill(0.0)

	_render_voice(buffer, _expand(BASS, steps), 0.30, "saw", 0.02, 0.55)
	_render_voice(buffer, _expand(ARP, steps), 0.10 if intense else 0.13, "square25", 0.005, 0.16)

	if intense:
		_render_voice(buffer, _expand(LEAD, steps), 0.26, "square50", 0.008, 0.75)
		_render_voice(buffer, _expand(HARMONY, steps), 0.13, "square25", 0.02, 0.7)

	_render_drums(buffer, DRUMS_FULL if intense else DRUMS_PATROL, 1.0 if intense else 0.55)

	_normalize(buffer, 0.82)
	return _to_stream(buffer)


## ---------------------------------------------------------------- vozes

## Expande [nota, duracao] para uma grade de passos, repetindo ate encher.
static func _expand(pattern: Array, steps: int) -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(steps)
	grid.fill(REST)

	var cursor := 0
	while cursor < steps:
		for entry in pattern:
			var note: int = entry[0]
			var length: int = entry[1]
			for offset in length:
				if cursor + offset >= steps:
					break
				grid[cursor + offset] = note if offset == 0 else HOLD
			cursor += length
			if cursor >= steps:
				break

	return grid


static func _render_voice(
	buffer: PackedFloat32Array,
	grid: PackedInt32Array,
	gain: float,
	wave: String,
	attack: float,
	release: float
) -> void:
	var step_len := step_seconds()
	var index := 0

	while index < grid.size():
		var note := grid[index]
		if note <= REST:
			index += 1
			continue

		## Conta quantos passos a nota se sustenta (HOLD prolonga).
		var length := 1
		while index + length < grid.size() and grid[index + length] == HOLD:
			length += 1

		var start_sample := int(float(index) * step_len * float(MIX_RATE))
		var note_seconds := float(length) * step_len
		_render_note(buffer, start_sample, note_seconds, _frequency(note), gain, wave, attack, release)
		index += length


static func _render_note(
	buffer: PackedFloat32Array,
	start_sample: int,
	note_seconds: float,
	frequency: float,
	gain: float,
	wave: String,
	attack: float,
	release: float
) -> void:
	var total := int((note_seconds + release) * float(MIX_RATE))
	var phase := 0.0
	var phase_step := frequency / float(MIX_RATE)

	for offset in total:
		var target := start_sample + offset
		if target < 0:
			continue
		## O rabo da nota que passa do fim do loop volta para o comeco, senao
		## a emenda do loop corta o som no meio.
		target = target % buffer.size()

		var t := float(offset) / float(MIX_RATE)
		var envelope := _envelope(t, note_seconds, attack, release)
		if envelope <= 0.0001:
			continue

		var value := 0.0
		match wave:
			"saw":
				value = _saw(phase)
			"square25":
				value = _square(phase, 0.25)
			_:
				value = _square(phase, 0.5)

		buffer[target] += value * envelope * gain
		phase = fmod(phase + phase_step, 1.0)


static func _render_drums(buffer: PackedFloat32Array, bars: Array, gain: float) -> void:
	var step_len := step_seconds()
	var steps_per_bar := BEATS_PER_BAR * STEPS_PER_BEAT

	for bar_index in bars.size():
		var line: String = bars[bar_index]
		for step in mini(line.length(), steps_per_bar):
			var symbol := line[step]
			if symbol == ".":
				continue

			var absolute := bar_index * steps_per_bar + step
			var start := int(float(absolute) * step_len * float(MIX_RATE))

			match symbol:
				"K":
					_render_kick(buffer, start, gain)
				"S":
					_render_snare(buffer, start, gain)
				"h":
					_render_hat(buffer, start, gain * 0.5)


static func _render_kick(buffer: PackedFloat32Array, start: int, gain: float) -> void:
	var total := int(0.22 * float(MIX_RATE))
	var phase := 0.0

	for offset in total:
		var t := float(offset) / float(MIX_RATE)
		var envelope: float = exp(-t * 24.0)
		## Varredura de frequencia para baixo: o "thump" classico.
		var frequency := lerpf(148.0, 46.0, clampf(t * 22.0, 0.0, 1.0))
		phase = fmod(phase + frequency / float(MIX_RATE), 1.0)
		buffer[(start + offset) % buffer.size()] += sin(phase * TAU) * envelope * gain * 0.85


static func _render_snare(buffer: PackedFloat32Array, start: int, gain: float) -> void:
	var total := int(0.19 * float(MIX_RATE))
	var filter_state := 0.0
	var phase := 0.0

	for offset in total:
		var t := float(offset) / float(MIX_RATE)
		var envelope: float = exp(-t * 27.0)
		var noise := randf_range(-1.0, 1.0)
		filter_state = lerpf(filter_state, noise, 0.6)
		phase = fmod(phase + 196.0 / float(MIX_RATE), 1.0)
		var value := filter_state * 0.75 + sin(phase * TAU) * 0.3
		buffer[(start + offset) % buffer.size()] += value * envelope * gain * 0.6


static func _render_hat(buffer: PackedFloat32Array, start: int, gain: float) -> void:
	var total := int(0.06 * float(MIX_RATE))
	var filter_state := 0.0

	for offset in total:
		var t := float(offset) / float(MIX_RATE)
		var envelope: float = exp(-t * 80.0)
		var noise := randf_range(-1.0, 1.0)
		## Passa-alta barato: ruido menos sua propria media.
		filter_state = lerpf(filter_state, noise, 0.85)
		buffer[(start + offset) % buffer.size()] += (noise - filter_state) * envelope * gain * 0.5


## ---------------------------------------------------------------- utilidades

static func _frequency(midi_note: int) -> float:
	return 440.0 * pow(2.0, (float(midi_note) - 69.0) / 12.0)


static func _envelope(t: float, note_seconds: float, attack: float, release: float) -> float:
	if t < 0.0:
		return 0.0
	if t < attack:
		return t / maxf(attack, 0.0001)
	if t < note_seconds:
		## Leve queda durante a sustentacao, para a nota nao soar travada.
		return lerpf(1.0, 0.78, (t - attack) / maxf(note_seconds - attack, 0.0001))
	var tail := (t - note_seconds) / maxf(release, 0.0001)
	return maxf(0.0, 0.78 * (1.0 - tail))


static func _saw(phase: float) -> float:
	return phase * 2.0 - 1.0


static func _square(phase: float, duty: float) -> float:
	return 1.0 if phase < duty else -1.0


static func _normalize(buffer: PackedFloat32Array, peak: float) -> void:
	var maximum := 0.0
	for value in buffer:
		maximum = maxf(maximum, absf(value))

	if maximum < 0.0001:
		return

	var scale := peak / maximum
	for index in buffer.size():
		buffer[index] *= scale


static func _to_stream(buffer: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)

	for index in buffer.size():
		data.encode_s16(index * 2, int(clampf(buffer[index], -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = buffer.size()

	return stream
