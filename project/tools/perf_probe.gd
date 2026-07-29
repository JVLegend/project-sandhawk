extends Node

## Compara CUSTO e IMPACTO VISUAL dos efeitos caros: mede ms/frame e a diferenca
## media de pixel contra a imagem de referencia. Efeito caro que quase nao muda
## a imagem e candidato a corte.
## Uso: godot res://tools/perf_probe.tscn

const MAIN_SCENE := preload("res://game/main.tscn")
const WARMUP := 70
const SAMPLE := 200

var _env: Environment
var _reference: Image


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await _wait(6)
	main.skip_briefing()
	await _wait(60)

	var world := main.get_node("MissionWorld")
	_env = (world.get_node("WorldEnvironment") as WorldEnvironment).environment

	var base_ms := await _measure()
	_reference = await _grab()
	print("referencia (tudo ligado): %.2f ms" % base_ms)
	print("%-24s %8s %10s %12s" % ["config", "ms", "economia", "dif. visual"])

	await _variant("sem SDFGI", base_ms, func(): _env.sdfgi_enabled = false, func(): _env.sdfgi_enabled = true)
	await _variant("sem SSIL", base_ms, func(): _env.ssil_enabled = false, func(): _env.ssil_enabled = true)
	await _variant("sem volumetrica", base_ms, func(): _env.volumetric_fog_enabled = false, func(): _env.volumetric_fog_enabled = true)
	await _variant("sem SSAO", base_ms, func(): _env.ssao_enabled = false, func(): _env.ssao_enabled = true)
	await _variant("sem SDFGI+SSIL", base_ms,
		func():
			_env.sdfgi_enabled = false
			_env.ssil_enabled = false,
		func():
			_env.sdfgi_enabled = true
			_env.ssil_enabled = true)

	get_tree().quit(0)


func _variant(label: String, base_ms: float, disable: Callable, restore: Callable) -> void:
	disable.call()
	var ms := await _measure()
	var image := await _grab()
	var diff := _mean_difference(_reference, image)
	print("%-24s %7.2f %9.2f %11.2f%%" % [label, ms, base_ms - ms, diff * 100.0])
	restore.call()
	await _wait(20)


func _measure() -> float:
	await _wait(WARMUP)
	var start := Time.get_ticks_usec()
	await _wait(SAMPLE)
	return float(Time.get_ticks_usec() - start) / 1000.0 / float(SAMPLE)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## Diferenca media por canal, 0 a 1. Amostra em grade para nao varrer 1M pixels.
func _mean_difference(a: Image, b: Image) -> float:
	if a == null or b == null:
		return 0.0

	var total := 0.0
	var count := 0
	var step := 4

	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
			count += 1

	return total / maxf(1.0, float(count))


func _wait(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
