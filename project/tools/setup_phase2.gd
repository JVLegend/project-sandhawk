extends SceneTree

const DEADZONE := 0.2


func _init() -> void:
	_configure_project_settings()
	_configure_input_map()
	var save_result := ProjectSettings.save()
	if save_result != OK:
		push_error("Failed to save project settings: %s" % save_result)
		quit(save_result)
		return

	print("Phase 2 project settings saved.")
	quit()


func _configure_project_settings() -> void:
	ProjectSettings.set_setting("application/config/name", "Project Sandhawk")
	ProjectSettings.set_setting("application/run/main_scene", "res://game/main.tscn")
	ProjectSettings.set_setting("display/window/size/viewport_width", 1280)
	ProjectSettings.set_setting("display/window/size/viewport_height", 720)
	ProjectSettings.set_setting("display/window/vsync/vsync_mode", 1)
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", 60)
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "forward_plus")
	ProjectSettings.set_setting("rendering/driver/threads/thread_model", 1)
	ProjectSettings.set_setting("rendering/textures/vram_compression/import_etc2_astc", true)
	ProjectSettings.set_setting("autoload/GameState", "*res://game/autoload/game_state.gd")
	ProjectSettings.set_setting("autoload/MissionManager", "*res://game/autoload/mission_manager.gd")
	ProjectSettings.set_setting("autoload/AudioManager", "*res://game/autoload/audio_manager.gd")


func _configure_input_map() -> void:
	_reset_action("move_forward")
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_UP)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)

	_reset_action("move_back")
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)

	_reset_action("move_left")
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)

	_reset_action("move_right")
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)

	_reset_action("turn_left")
	_add_key("turn_left", KEY_Q)
	_add_joy_axis("turn_left", JOY_AXIS_RIGHT_X, -1.0)

	_reset_action("turn_right")
	_add_key("turn_right", KEY_E)
	_add_joy_axis("turn_right", JOY_AXIS_RIGHT_X, 1.0)

	_reset_action("fire_primary")
	_add_key("fire_primary", KEY_J)
	_add_mouse_button("fire_primary", MOUSE_BUTTON_LEFT)
	_add_joy_button("fire_primary", JOY_BUTTON_RIGHT_SHOULDER)

	_reset_action("fire_secondary")
	_add_key("fire_secondary", KEY_K)
	_add_mouse_button("fire_secondary", MOUSE_BUTTON_RIGHT)
	_add_joy_button("fire_secondary", JOY_BUTTON_LEFT_SHOULDER)

	_reset_action("fire_special")
	_add_key("fire_special", KEY_L)
	_add_joy_button("fire_special", JOY_BUTTON_X)

	_reset_action("winch")
	_add_key("winch", KEY_SPACE)
	_add_joy_button("winch", JOY_BUTTON_A)

	_reset_action("pause")
	_add_key("pause", KEY_ESCAPE)
	_add_key("pause", KEY_P)
	_add_joy_button("pause", JOY_BUTTON_START)


func _reset_action(action_name: String) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	InputMap.add_action(action_name, DEADZONE)


func _add_key(action_name: String, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _add_mouse_button(action_name: String, button_index: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func _add_joy_button(action_name: String, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func _add_joy_axis(action_name: String, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)
