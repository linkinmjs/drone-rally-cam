## Button names for on-screen hints. They are read from the input map, so they follow any
## remapping made in Options > Controls, for whichever device the player used last
## (Controls.using_gamepad), with Xbox or PlayStation names depending on the controller.
class_name InputHints
extends RefCounted


## Hints that stand for several actions.
const GROUPS := {
	"throttle_yaw": ["throttle_up", "throttle_down", "yaw_left", "yaw_right"],
	"pitch_roll": ["pitch_down", "pitch_up", "roll_left", "roll_right"],
	"gimbal": ["gimbal_up", "gimbal_down"],
}
const GAMEPAD_GROUPS := {
	"throttle_yaw": "Stick izq.",
	"pitch_roll": "Stick der.",
}

const XBOX_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Cruz ↑", JOY_BUTTON_DPAD_DOWN: "Cruz ↓",
	JOY_BUTTON_DPAD_LEFT: "Cruz ←", JOY_BUTTON_DPAD_RIGHT: "Cruz →", JOY_BUTTON_MISC1: "Share",
}
const PLAYSTATION_BUTTONS := {
	JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
	JOY_BUTTON_BACK: "Share", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_START: "Options",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "Cruz ↑", JOY_BUTTON_DPAD_DOWN: "Cruz ↓",
	JOY_BUTTON_DPAD_LEFT: "Cruz ←", JOY_BUTTON_DPAD_RIGHT: "Cruz →", JOY_BUTTON_MISC1: "Mic",
	JOY_BUTTON_TOUCHPAD: "Panel",
}
const KEY_NAMES := {
	KEY_SPACE: "Espacio", KEY_BACKSPACE: "Retroceso", KEY_ESCAPE: "Esc", KEY_ENTER: "Enter",
	KEY_TAB: "Tab", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt",
	KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
}
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Clic", MOUSE_BUTTON_RIGHT: "Clic der.", MOUSE_BUTTON_MIDDLE: "Clic medio",
	MOUSE_BUTTON_WHEEL_UP: "Rueda ↑", MOUSE_BUTTON_WHEEL_DOWN: "Rueda ↓",
}


## "[X]" for the action, on the device in use.
static func button(action: String) -> String:
	return "[%s]" % label(action)


static func label(action: String, gamepad: bool = Controls.using_gamepad) -> String:
	if gamepad and GAMEPAD_GROUPS.has(action):
		return GAMEPAD_GROUPS[action]
	if GROUPS.has(action):
		return _group_label(action, gamepad)
	var text := event_name(action, gamepad)
	if text.is_empty():
		# Not bound on this device: show the other device's binding rather than nothing.
		text = event_name(action, not gamepad)
	return text if not text.is_empty() else action


static func _group_label(group: String, gamepad: bool) -> String:
	var names: PackedStringArray = []
	for action: String in GROUPS[group]:
		names.append(event_name(action, gamepad))
	var text := ""
	if names.size() == 4:
		text = "%s/%s %s/%s" % [names[0], names[1], names[2], names[3]]
	else:
		text = "/".join(names)
	if not gamepad:
		if group == "pitch_roll":
			text += " o mouse"
		elif group == "gimbal":
			text += " o rueda"
	return text


## Name of the first binding of `action` on the gamepad or on keyboard and mouse.
static func event_name(action: String, gamepad: bool) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if gamepad and event is InputEventJoypadButton:
			return joy_button_name((event as InputEventJoypadButton).button_index)
		if gamepad and event is InputEventJoypadMotion:
			return joy_axis_name((event as InputEventJoypadMotion).axis)
		if not gamepad and event is InputEventKey:
			return key_name(event as InputEventKey)
		if not gamepad and event is InputEventMouseButton:
			return MOUSE_NAMES.get((event as InputEventMouseButton).button_index, "Mouse")
	return ""


static func joy_button_name(index: int) -> String:
	var table := PLAYSTATION_BUTTONS if Controls.is_playstation_pad() else XBOX_BUTTONS
	return table.get(index, "Botón %d" % index)


static func joy_axis_name(axis: int) -> String:
	var playstation := Controls.is_playstation_pad()
	match axis:
		JOY_AXIS_TRIGGER_LEFT:
			return "L2" if playstation else "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2" if playstation else "RT"
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return "Stick izq."
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
			return "Stick der."
	return "Eje %d" % axis


static func key_name(event: InputEventKey) -> String:
	var keycode := event.keycode
	if keycode == KEY_NONE:
		# The key printed on the player's keyboard layout (headless has no layout).
		if DisplayServer.get_name() != "headless":
			keycode = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
		if keycode == KEY_NONE:
			keycode = event.physical_keycode
	if KEY_NAMES.has(keycode):
		return KEY_NAMES[keycode]
	return OS.get_keycode_string(keycode)
