## Menus with only a gamepad (plan 01): the pause keeps its focus when the cursor is released,
## one ✕ is enough, Confirm is reachable in the confirm dialog from every direction, the
## sticks only move the focus, resuming cannot hang, L1/R1 switch sections, the footer shows
## the pad's buttons and a calibration keeps the keyboard bindings.
extends HeadlessCheck


const STAGE_SCENE := preload("res://game/stage.tscn")
const CALIBRATION_MENU := preload("res://gui/options_menu/controls_menu/calibration_menu.tscn")
const UI_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down",
		&"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

var _saved_scheme := 0


func run() -> void:
	_saved_scheme = StickNavigation.scheme
	StickNavigation.assume_joypad = true
	StickNavigation.scheme = StickNavigation.Scheme.GAMEPAD

	_check_ui_actions()
	_check_stick_scheme()
	await _check_menus_on_stage()
	await _check_calibration_keeps_keyboard()

	StickNavigation.assume_joypad = false
	StickNavigation.scheme = _saved_scheme as StickNavigation.Scheme
	Controls.force_playstation = -1
	InputMap.load_from_project_settings()
	await _button(JOY_BUTTON_LEFT_STICK)  # leave the input kind on the pad, harmless
	UI.set_input_kind(UI.InputKind.KEYBOARD)


func _check_ui_actions() -> void:
	for action in UI_ACTIONS:
		expect(InputMap.has_action(action), "%s should be declared" % action)
		for event in InputMap.action_get_events(action):
			expect(not event is InputEventJoypadMotion,
					"%s must not have stick axes (StickNavigation drives the menus)" % action)
	var cross := InputEventJoypadButton.new()
	cross.button_index = JOY_BUTTON_A
	expect(InputMap.action_has_event(&"ui_accept", cross), "✕ accepts")
	var r1 := InputEventJoypadButton.new()
	r1.button_index = JOY_BUTTON_RIGHT_SHOULDER
	expect(InputMap.action_has_event(&"ui_focus_next", r1), "R1 is the next section")


func _check_stick_scheme() -> void:
	var nav := StickNavigation
	expect(GameSettings.STICK_NAV_DEFAULT == StickNavigation.Scheme.GAMEPAD,
			"the gamepad scheme is the default")
	for axis: String in ["pitch", "roll", "yaw", "throttle"]:
		for dir: int in [-1, 1]:
			var action := nav.action_for(axis, dir)
			expect(action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"],
					"gamepad scheme: %s %d only moves the focus (got %s)" % [axis, dir, action])
	expect(nav.action_for("roll", 1) == &"ui_right" and nav.action_for("pitch", 1) == &"ui_up",
			"roll right moves right and pitch up moves up")
	nav.scheme = StickNavigation.Scheme.BETAFLIGHT
	expect(nav.action_for("roll", 1) == &"ui_accept", "the radio scheme still accepts with roll")
	nav.scheme = StickNavigation.Scheme.GAMEPAD


func _check_menus_on_stage() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(20)

	# Options opens the pause; releasing the cursor must not steal the focus.
	await _button(JOY_BUTTON_START)
	await process_frames(4)
	var pause := stage.pause_menu
	expect(pause != null and get_tree().paused, "Options pauses")
	if not pause:
		return
	var jump := InputEventMouseMotion.new()
	jump.relative = Vector2(800, 0)
	Input.parse_input_event(jump)
	await process_frames(4)
	note("after the cursor jump: focus %s, input kind %d" % [focus_name(), UI.input_kind])
	expect(focus_name() == "ButtonResume", "the cursor jump keeps the focus on Continue")
	expect(UI.input_kind != UI.InputKind.MOUSE, "the cursor jump is not the player using the mouse")
	# A real mouse movement later still switches to the mouse.
	UI._mouse_shown_msec = -100000
	Input.parse_input_event(jump)
	await process_frames(2)
	expect(UI.input_kind == UI.InputKind.MOUSE, "moving the mouse later does switch to the mouse")
	await _button(JOY_BUTTON_DPAD_DOWN)
	expect(UI.input_kind == UI.InputKind.GAMEPAD, "a pad button switches back to the pad")

	# A single ✕ with nothing focused acts on the control it focuses.
	pause.initial_focus = pause.button_options
	get_viewport().gui_release_focus()
	await process_frames(1)
	await _button(JOY_BUTTON_A)
	await process_frames(20)
	var options := find_child_with_script(pause, "res://gui/options_menu/options_menu.gd")
	expect(options != null, "one ✕ with no focus opens Options")
	if options:
		await _check_game_tabs(pause, options)
		await _check_controls_menu(pause, options)
		await _button(JOY_BUTTON_B)
		await process_frames(25)
		expect(not is_instance_valid(options) or not options.is_inside_tree(), "○ closes Options")
	pause.initial_focus = pause.button_resume

	await _check_confirm_dialog(stage, pause)
	await _check_footer(pause)
	await _check_resume_timeout(stage)


func _check_game_tabs(pause: Node, options: Node) -> void:
	(options.find_child("ButtonGame", true, false) as Button).grab_focus()
	await _button(JOY_BUTTON_A)
	await process_frames(25)
	var game := find_child_with_script(pause, "res://gui/options_menu/game_settings_menu.gd") as MenuScreen
	expect(game != null, "Game and HUD opens")
	if not game:
		return
	var tabs := game.section_tabs
	expect(tabs != null and tabs.current_tab == 0, "Game and HUD starts on its first tab")
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frames(3)
	expect(tabs.current_tab == 1, "R1 switches to the HUD tab")
	var focus := get_viewport().gui_get_focus_owner()
	expect(focus != null and tabs.get_current_tab_control().is_ancestor_of(focus),
			"the focus moves into the HUD tab (%s)" % focus_name())
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	await process_frames(3)
	expect(tabs.current_tab == 0, "L1 goes back to the first tab")
	await _button(JOY_BUTTON_B)
	await process_frames(25)


func _check_controls_menu(pause: Node, options: Node) -> void:
	(options.find_child("ButtonControls", true, false) as Button).grab_focus()
	await _button(JOY_BUTTON_A)
	await process_frames(25)
	var controls := find_child_with_script(pause,
			"res://gui/options_menu/controls_menu/controls_menu.gd") as MenuScreen
	expect(controls != null, "Controls opens")
	if not controls:
		return
	var first := focus_name()
	await _button(JOY_BUTTON_DPAD_DOWN)
	note("controls: D-pad down moved the focus from %s to %s" % [first, focus_name()])
	expect(focus_name() != first, "D-pad down moves the focus in Controls")
	expect(controls.get("binding_popup") == null, "D-pad down does not open the binding popup")
	var list := controls.find_child("ControllerList", true, false) as OptionButton
	expect(not list.get_popup().visible, "the controller list stays closed")

	var groups: Array[Control] = controls.focus_groups
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frames(2)
	var focus := get_viewport().gui_get_focus_owner()
	expect(focus != null and groups[1].is_ancestor_of(focus), "R1 moves to the center column (%s)" % focus_name())
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frames(2)
	focus = get_viewport().gui_get_focus_owner()
	expect(focus != null and groups[2].is_ancestor_of(focus), "R1 moves to the bindings (%s)" % focus_name())

	# Assigning a button: the pause button cancels while the popup listens.
	if focus is GUIControllerBinding:
		await _button(JOY_BUTTON_A)
		await process_frames(3)
		var popup := controls.get("binding_popup") as BindingPopup
		expect(popup != null and popup.is_listening(), "✕ on an action opens the binding popup")
		await _button(JOY_BUTTON_START)
		await process_frames(15)
		expect(controls.get("binding_popup") == null, "Options cancels the binding popup")
	await _button(JOY_BUTTON_B)
	await process_frames(25)


func _check_confirm_dialog(stage: Stage, pause: PauseMenu) -> void:
	# Restarting would reload the scene of the checks: record the request instead.
	for connection in pause.restart_requested.get_connections():
		pause.restart_requested.disconnect(connection["callable"])
	var restarts := [0]
	var _discard := pause.restart_requested.connect(func() -> void: restarts[0] += 1)

	var ways: Array = [
		[JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A, 1, "D-pad right + ✕ confirms"],
		[JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_A, 2, "D-pad down + ✕ confirms"],
		[JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_B, 2, "○ cancels"],
		[-1, JOY_BUTTON_A, 3, "the right stick reaches Confirm"],
	]
	for way: Array in ways:
		pause.button_restart.grab_focus()
		await _button(JOY_BUTTON_A)
		await process_frames(6)
		expect(UI.has_modal(), "Restart asks first (%s)" % way[3])
		note("confirm dialog opens with the focus on %s" % focus_name())
		if way[0] >= 0:
			await _button(way[0])
		else:
			Input.action_press(&"roll_right", 1.0)
			await process_frames(3)
			Input.action_release(&"roll_right")
			await process_frames(3)
		var focus := get_viewport().gui_get_focus_owner() as Button
		if way[1] == JOY_BUTTON_A:
			expect(focus != null and focus.text == "MENU_RESTART_STAGE",
					"%s: the focus is on Confirm (%s)" % [way[3], focus.text if focus else "none"])
		await _button(way[1])
		await process_frames(20)
		expect(not UI.has_modal(), "%s: the dialog closes" % way[3])
		expect(restarts[0] == way[2], "%s (restart requests: %d)" % [way[3], restarts[0]])
	_discard = pause.restart_requested.connect(stage.restart)


func _check_footer(pause: PauseMenu) -> void:
	var hints := pause.get("_hints") as ControlHints
	expect(hints != null, "the pause menu has a footer")
	if not hints:
		return
	UI.set_input_kind(UI.InputKind.GAMEPAD)
	Controls.force_playstation = 1
	var text := _hints_text(hints)
	note("footer with a PlayStation pad: %s" % text)
	expect(text.contains("✕") and text.contains("○"), "PlayStation glyphs in the footer")
	Controls.force_playstation = 0
	text = _hints_text(hints)
	expect(text.contains("A ") and text.contains("B "), "Xbox names with an Xbox pad (%s)" % text)
	Controls.force_playstation = 1


func _hints_text(hints: ControlHints) -> String:
	var parts := PackedStringArray()
	for hint: Array in hints.hint_list():
		parts.append("%s %s" % [hint[0], hint[1]])
	return " | ".join(parts)


func _check_resume_timeout(stage: Stage) -> void:
	# A stick that does not come back to the center must not keep the game paused.
	Input.action_press(&"roll_right", 0.9)
	var start := Time.get_ticks_msec()
	await _button(JOY_BUTTON_B)
	while get_tree().paused and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	var elapsed := Time.get_ticks_msec() - start
	Input.action_release(&"roll_right")
	note("resumed %d ms after ○ with a stick held" % elapsed)
	expect(not get_tree().paused, "the game resumes with a stick held")
	expect(elapsed < 800, "resuming with a stick held takes at most about half a second")
	expect(stage.pause_menu == null, "the pause menu is gone")


func _check_calibration_keeps_keyboard() -> void:
	InputMap.load_from_project_settings()
	var menu := CALIBRATION_MENU.instantiate()
	add_child(menu)
	await process_frames(2)
	var axis_event := func(axis: int, value: float) -> InputEventJoypadMotion:
		var event := InputEventJoypadMotion.new()
		event.axis = axis as JoyAxis
		event.axis_value = value
		return event
	menu.set("throttle", [1, axis_event.call(1, -1.0), axis_event.call(1, 1.0)])
	menu.set("yaw", [0, axis_event.call(0, -1.0), axis_event.call(0, 1.0)])
	menu.set("pitch", [3, axis_event.call(3, -1.0), axis_event.call(3, 1.0)])
	menu.set("roll", [2, axis_event.call(2, -1.0), axis_event.call(2, 1.0)])
	var taken: Dictionary = menu.call("taken_axes")
	expect(taken.has(1) and taken.has(0) and taken.has(3), "used axes are reported as taken")
	menu.call("apply_calibration")
	var w_key := InputEventKey.new()
	w_key.physical_keycode = KEY_W
	expect(InputMap.action_has_event(&"throttle_up", w_key), "W still climbs after a calibration")
	var up_key := InputEventKey.new()
	up_key.physical_keycode = KEY_UP
	expect(InputMap.action_has_event(&"pitch_down", up_key), "the up arrow still flies forward")
	var axes := 0
	for event in InputMap.action_get_events(&"throttle_up"):
		if event is InputEventJoypadMotion:
			axes += 1
	expect(axes == 1, "throttle up has exactly one stick axis (%d)" % axes)
	menu.queue_free()
	await process_frames(2)
	InputMap.load_from_project_settings()


## Presses and releases a gamepad button through the input pipeline.
func _button(index: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = index
	press.pressed = true
	Input.parse_input_event(press)
	await process_frames(1)
	var release := InputEventJoypadButton.new()
	release.button_index = index
	release.pressed = false
	Input.parse_input_event(release)
	await process_frames(3)
