extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	await process_frame
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	var enter := InputEventKey.new()
	enter.device = InputEvent.DEVICE_ID_KEYBOARD
	enter.keycode = KEY_ENTER
	var south := InputEventJoypadButton.new()
	south.button_index = JOY_BUTTON_A
	var click := InputEventMouseButton.new()
	click.device = InputEvent.DEVICE_ID_MOUSE
	click.button_index = MOUSE_BUTTON_LEFT

	for input: InputEvent in [enter, south, click]:
		await _test_start(main_scene, input)
	quit(1 if _failures > 0 else 0)


func _test_start(main_scene: String, input: InputEvent) -> void:
	if change_scene_to_file(main_scene) != OK:
		_expect(false, "Could not load the configured main scene.")
		return
	await process_frame

	if current_scene == null or current_scene.get_child_count() != 1:
		_expect(false, "The game must start with one active screen.")
		return
	var title: Node = current_scene.get_child(0)
	if title is not TitleScreen:
		_expect(false, "The game must open on the title screen, not hero selection.")
		return

	var start_button: Button = title.get_node_or_null("%StartButton")
	if start_button == null:
		_expect(false, "The title screen is missing its Start button.")
		return
	_expect(root.gui_get_focus_owner() == start_button, "Start should have initial focus.")

	if input is InputEventMouseButton:
		input.position = start_button.get_global_rect().get_center()
	input.pressed = true
	root.push_input(input, true)
	input.pressed = false
	root.push_input(input, true)
	await process_frame

	_expect(current_scene.get_child_count() == 1, "Only one screen should be active after Start.")
	var slots: Node = current_scene.get_child(0) if current_scene.get_child_count() > 0 else null
	if slots is CharacterSelect:
		var focus: Control = root.gui_get_focus_owner()
		_expect(focus != null and slots.is_ancestor_of(focus), "Focus should move to a hero slot.")
	else:
		_expect(false, "%s should open the hero selection screen." % input.get_class())


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
