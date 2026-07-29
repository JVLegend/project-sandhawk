extends SceneTree


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var scene: PackedScene = load("res://game/main.tscn") as PackedScene
	if scene == null:
		push_error("Failed to load main scene.")
		quit(1)
		return

	root.add_child(scene.instantiate())
	await process_frame
	await process_frame
	print("Smoke test passed.")
	quit()
