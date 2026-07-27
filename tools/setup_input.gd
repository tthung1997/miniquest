## One-shot tool: writes the input map into project.godot.
## Run with:
##   & $env:GODOT --headless --path . --script res://tools/setup_input.gd
## Hand-writing InputEventKey entries in project.godot is error-prone, so we let
## the engine serialise them. Safe to re-run; it overwrites the same actions.
extends SceneTree


func _init() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("pause", [KEY_ESCAPE, KEY_P])

	var err := ProjectSettings.save()
	if err == OK:
		print("Input map written to project.godot")
	else:
		printerr("Failed to save project settings: %d" % err)
	quit()


func _add_action(action_name: String, physical_keycodes: Array) -> void:
	var events: Array[InputEvent] = []
	for keycode in physical_keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		events.append(event)
	ProjectSettings.set_setting("input/" + action_name, {
		"deadzone": 0.2,
		"events": events,
	})
