## Keyboard and mouse reach the drone through the RadioController, and a disabled radio
## sends a neutral "hold" command. The gamepad layout matches drone-simulator, the mouse
## stays out of the way while a gamepad is in use, and the hints follow the input map.
extends HeadlessCheck


const DRONE_SCENE := preload("res://drone/drones/rally_drone.tscn")


func run() -> void:
	add_floor()
	var drone := DRONE_SCENE.instantiate() as Drone
	drone.name = "Drone"
	add_child(drone)
	var radio := RadioController.new()
	radio.target_path = NodePath("../Drone")
	add_child(radio)
	radio.mouse_requires_capture = false
	await physics_frames(5)

	await _press_key(KEY_W, true)
	note("W pressed: throttle command %.2f" % radio.input.power)
	expect(radio.input.power > 0.95, "W should push the throttle up (got %.2f)" % radio.input.power)
	await _press_key(KEY_W, false)
	expect(absf(radio.input.power - 0.5) < 0.01, "releasing W should centre the throttle")

	await _press_key(KEY_UP, true)
	expect(radio.input.pitch < -0.9, "the up arrow should pitch forward (got %.2f)" % radio.input.pitch)
	await _press_key(KEY_UP, false)

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0.0, -120.0)
	Input.parse_input_event(motion)
	await physics_frames(2)
	note("mouse moved up: pitch command %.2f" % radio.input.pitch)
	expect(radio.input.pitch < -0.2, "moving the mouse up should pitch forward")
	await physics_frames(100)
	note("one second later: pitch command %.3f" % radio.input.pitch)
	expect(absf(radio.input.pitch) < 0.05, "the mouse stick should spring back to the centre")

	await _check_bindings_and_hints()
	await _check_gamepad_blocks_mouse(radio)
	await _check_acro_mouse_recenters(radio, drone)
	_check_deadzone(radio)

	radio.enabled = false
	await _press_key(KEY_W, true)
	expect(absf(radio.input.power - drone.flight_controller.flight_mode.idle_power()) < 0.001,
			"a disabled radio must ignore the sticks and send the idle throttle")
	await _press_key(KEY_W, false)


func _check_bindings_and_hints() -> void:
	var pad := {
		"toggle_arm": JOY_BUTTON_LEFT_SHOULDER, "cycle_flight_modes": JOY_BUTTON_A,
		"rec_toggle": JOY_BUTTON_RIGHT_SHOULDER, "change_camera": JOY_BUTTON_X,
		"pilot_toggle": JOY_BUTTON_Y, "respawn": JOY_BUTTON_BACK, "pause_menu": JOY_BUTTON_START,
		"show_map": JOY_BUTTON_DPAD_UP, "interact": JOY_BUTTON_X, "crouch": JOY_BUTTON_B,
	}
	for action: String in pad:
		var event := InputEventJoypadButton.new()
		event.button_index = pad[action]
		expect(InputMap.action_has_event(action, event), "%s should be on joypad button %d" % [action, pad[action]])
	var keys := {"change_camera": KEY_C, "pause_menu": KEY_ESCAPE, "show_map": KEY_M, "crouch": KEY_CTRL}
	for action: String in keys:
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		expect(InputMap.action_has_event(action, key), "%s should be on key %s" % [action, OS.get_keycode_string(keys[action])])
	var c_key := InputEventKey.new()
	c_key.physical_keycode = KEY_C
	expect(not InputMap.action_has_event("crouch", c_key), "C no longer crouches (it switches the camera)")

	var hints := {
		["cycle_flight_modes", true]: "A", ["rec_toggle", true]: "RB", ["toggle_arm", true]: "LB",
		["pause_menu", true]: "Start", ["rec_toggle", false]: "Clic", ["change_camera", false]: "C",
		["pause_menu", false]: "Esc", ["respawn", false]: "Retroceso", ["gimbal", true]: "RT/LT",
	}
	for key: Array in hints:
		var text := InputHints.label(key[0], key[1])
		expect(text == hints[key], "hint for %s (%s) should be %s, got %s" % [key[0],
				"gamepad" if key[1] else "keyboard", hints[key], text])
	# Remapping in Options > Controls changes the hint.
	var events := InputMap.action_get_events("rec_toggle")
	InputMap.action_erase_events("rec_toggle")
	var remapped := InputEventJoypadButton.new()
	remapped.button_index = JOY_BUTTON_B
	InputMap.action_add_event("rec_toggle", remapped)
	expect(InputHints.label("rec_toggle", true) == "B", "the hint follows a remapped button")
	InputMap.action_erase_events("rec_toggle")
	for event in events:
		InputMap.action_add_event("rec_toggle", event)


func _check_gamepad_blocks_mouse(radio: RadioController) -> void:
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.9
	Input.parse_input_event(stick)
	await physics_frames(2)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await physics_frames(2)
	expect(Controls.using_gamepad, "moving a gamepad stick switches to the gamepad")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0.0, -120.0)
	Input.parse_input_event(motion)
	await physics_frames(2)
	note("mouse moved while on the gamepad: pitch command %.2f" % radio.input.pitch)
	expect(absf(radio.input.pitch) < 0.01, "the mouse must not move the drone while a gamepad is in use")
	await _press_key(KEY_W, true)
	await _press_key(KEY_W, false)
	expect(not Controls.using_gamepad, "a key press switches back to keyboard and mouse")


func _check_acro_mouse_recenters(radio: RadioController, drone: Drone) -> void:
	drone.flight_controller.select_flight_mode(FlightMode.Type.ACRO)
	await physics_frames(2)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0.0, -120.0)
	Input.parse_input_event(motion)
	await physics_frames(2)
	var flick := radio.input.pitch
	await physics_frames(50)
	note("Acro: mouse flick pitch %.2f, half a second later %.3f" % [flick, radio.input.pitch])
	expect(flick < -0.2 and absf(radio.input.pitch) < 0.05, "in Acro the mouse stick springs back too")
	drone.flight_controller.select_flight_mode(FlightMode.Type.TRACK)


func _check_deadzone(radio: RadioController) -> void:
	GameSettings.set_stick_deadzone(0.2)
	expect(is_equal_approx(radio.stick_deadzone, 0.2), "the radio takes the dead zone from Options")
	expect(radio.apply_deadzone(Vector2(0.15, 0.0)) == Vector2.ZERO, "a 15 % stick is inside a 20 % dead zone")
	expect(radio.apply_deadzone(Vector2(1.0, 0.0)).x > 0.99, "a full stick still gives a full command")
	GameSettings.set_stick_deadzone(0.08)


func _press_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	await physics_frames(2)
