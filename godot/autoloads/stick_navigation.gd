extends Node
## Lets the sticks drive the menus. It reads the already calibrated flight actions and
## injects the matching ui_* actions, with a controlled repeat (the ui_* actions have no
## stick axes of their own, so this is the only analog source of menu navigation).
##
## Schemes:
## - GAMEPAD (default): both sticks only move the focus; the buttons accept and go back.
## - BETAFLIGHT: for a radio without buttons, like the Betaflight OSD menu: pitch moves,
##   roll right accepts and roll left goes back (on a value control roll adjusts it).
## - YAW_SELECT: for a radio, pitch moves, roll adjusts, yaw accepts and goes back.
## On a radio the throttle rests at the bottom, so it only navigates in GAMEPAD.


enum Scheme {BETAFLIGHT, YAW_SELECT, GAMEPAD}

const THRESHOLD := 0.6
const RELEASE := 0.4
const INITIAL_DELAY := 0.35
const REPEAT := 0.12
const AXES: Array[String] = ["pitch", "roll", "yaw", "throttle"]

var scheme := Scheme.GAMEPAD
## Set while an action binding or the calibration is listening to the sticks.
var suspended := false:
	set(value):
		suspended = value
		_reset_axes()

## Tests only: behave as if a joypad were connected.
var assume_joypad := false

var _dir := {"pitch": 0, "roll": 0, "yaw": 0, "throttle": 0}
var _timer := {"pitch": 0.0, "roll": 0.0, "yaw": 0.0, "throttle": 0.0}
var _was_active := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	scheme = GameSettings.get_nav_scheme() as Scheme


func _process(delta: float) -> void:
	var active := not suspended and UI.sticks_allowed() \
			and (assume_joypad or not Input.get_connected_joypads().is_empty())
	if not active:
		_was_active = false
		return
	if not _was_active:
		# A menu just opened: ignore sticks that are already deflected (e.g. the gesture
		# that opened it) until they come back to the center.
		_was_active = true
		_prime_axes()
		return
	for axis in AXES:
		if axis == "throttle" and scheme != Scheme.GAMEPAD:
			continue
		_update(axis, axis_value(axis), delta)


## Current deflection of a stick axis. Positive is "up" for pitch and throttle (the stick
## pushed away from the player) and "right" for roll and yaw.
static func axis_value(axis: String) -> float:
	match axis:
		"pitch":
			# Pushing the stick up is "pitch down" (nose down, fly forward): it moves the focus up
			return Input.get_axis(&"pitch_up", &"pitch_down")
		"roll":
			return Input.get_axis(&"roll_left", &"roll_right")
		"yaw":
			return Input.get_axis(&"yaw_left", &"yaw_right")
		"throttle":
			return Input.get_axis(&"throttle_down", &"throttle_up")
	return 0.0


func _update(axis: String, value: float, delta: float) -> void:
	var prev: int = _dir[axis]
	var dir := prev
	if prev == 0 and absf(value) > THRESHOLD:
		dir = signi(value) if value != 0.0 else 0
	elif prev != 0 and (absf(value) < RELEASE or signf(value) != float(prev)):
		dir = 0
	if dir != prev:
		_dir[axis] = dir
		if dir != 0:
			_fire(axis, dir)
			_timer[axis] = INITIAL_DELAY
	elif dir != 0 and _repeats(axis):
		_timer[axis] -= delta
		if _timer[axis] <= 0.0:
			_fire(axis, dir)
			_timer[axis] = REPEAT


## Only movement repeats while the stick is held; accept / back fire once per gesture.
func _repeats(axis: String) -> bool:
	return action_for(axis, 1) in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]


func _fire(axis: String, dir: int) -> void:
	var action := action_for(axis, dir)
	if action == &"":
		return
	UI.set_input_kind(UI.InputKind.STICKS)
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func action_for(axis: String, dir: int) -> StringName:
	match axis:
		"pitch":
			return &"ui_up" if dir > 0 else &"ui_down"
		"throttle":
			if scheme == Scheme.GAMEPAD:
				return &"ui_up" if dir > 0 else &"ui_down"
		"roll":
			if scheme != Scheme.BETAFLIGHT or _focus_is_value_control():
				return &"ui_right" if dir > 0 else &"ui_left"
			return &"ui_accept" if dir > 0 else &"ui_cancel"
		"yaw":
			if scheme == Scheme.GAMEPAD:
				return &"ui_right" if dir > 0 else &"ui_left"
			if scheme == Scheme.YAW_SELECT:
				return &"ui_accept" if dir > 0 else &"ui_cancel"
	return &""


func _focus_is_value_control() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null:
		return false
	return focus is Range or focus is OptionButton or focus is TabBar \
			or focus is CheckButton or focus is CheckBox or focus.has_meta(&"stick_value_control")


## True while pitch, roll or yaw is clearly away from the center, taking the player's stick
## dead zone into account (a worn stick resting at 0.3 must not count). Throttle is left out:
## on a radio it rests at the bottom.
func any_axis_deflected() -> bool:
	var threshold := maxf(RELEASE, GameSettings.get_stick_deadzone() + 0.15)
	for axis: String in ["pitch", "roll", "yaw"]:
		if absf(axis_value(axis)) > threshold:
			return true
	return false


func _prime_axes() -> void:
	for axis in AXES:
		var value := axis_value(axis)
		_dir[axis] = signi(value) if absf(value) > RELEASE else 0
		_timer[axis] = 1000.0


func _reset_axes() -> void:
	_was_active = false
