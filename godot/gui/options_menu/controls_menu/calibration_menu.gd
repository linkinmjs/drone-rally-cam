# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: no Global autoload,
# keeps the keyboard bindings, one axis per control.
extends MenuScreen


signal calibration_step_changed
signal calibration_done

@onready var title := %Title as Label
@onready var label_action := %LabelAction as Label
@onready var button_cancel := %ButtonCancel as Button

var calibration_step := -1
var device := 0
var axes := []
var throttle := []
var yaw := []
var pitch := []
var roll := []

var calibration_is_done := false
var display_popup := false
var _taken_notice_until := 0


func _ready() -> void:
	backdrop = Backdrop.NONE
	show_hints = false
	initial_focus = button_cancel
	super()
	# The sticks are what is being calibrated: they must not drive the menu meanwhile
	StickNavigation.suspended = true
	var _discard := button_cancel.pressed.connect(_on_cancel_pressed)
	button_cancel.set_meta(&"ui_silent", true)
	_discard = calibration_done.connect(_on_calibration_done)

	reset_calibration()


func _exit_tree() -> void:
	StickNavigation.suspended = false
	super()


func _process(_delta: float) -> void:
	# Check the axes detected in the first step, not fixed indices 0..3: radios and
	# gamepads often expose the sticks on other axes.
	var next_step_ready := true
	if calibration_step == 0 and axes.size() == 4:
		for axis: int in axes:
			if absf(Input.get_joy_axis(device, axis)) < 0.5:
				next_step_ready = false
				break
	elif calibration_step == 1 and axes.size() == 4:
		for axis: int in axes:
			if absf(Input.get_joy_axis(device, axis)) > 0.2:
				next_step_ready = false
				break
	else:
		next_step_ready = false
	if next_step_ready:
		go_to_next_step()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		if calibration_step == 0:
			if absf(event.axis_value) > 0.9:
				if axes.size() == 0:
					device = event.device
					title.text = tr("CAL_TITLE_DEVICE") % [Input.get_joy_name(device)]
				elif event.device != device:
					if not display_popup:
						display_popup = true
						await UI.alert(tr("CAL_WRONG_DEVICE") % [Input.get_joy_name(device)])
						display_popup = false
					return
				if axes.find(event.axis) < 0 and axes.size() < 4:
					axes.append(event.axis)
		elif calibration_step == 2:
			# Throttle axis
			if axes.find(event.axis) >= 0 and absf(event.axis_value) > 0.9:
				throttle.append(event.axis)
				throttle.append(event)
				go_to_next_step()
		elif calibration_step == 3:
			if event.axis == throttle[0]:
				if absf(event.axis_value + throttle[1].axis_value) < 0.2:
					throttle.append(event)
					go_to_next_step()
		elif calibration_step == 4:
			if event.axis == throttle[0] and absf(event.axis_value) < 0.2:
				go_to_next_step()
		elif calibration_step == 5:
			# Yaw axis
			if _reject_taken_axis(event):
				return
			if axes.find(event.axis) >= 0 and absf(event.axis_value) > 0.9:
				yaw.append(event.axis)
				yaw.append(event)
				go_to_next_step()
		elif calibration_step == 6:
			if event.axis == yaw[0]:
				if absf(event.axis_value + yaw[1].axis_value) < 0.2:
					yaw.append(event)
					go_to_next_step()
		elif calibration_step == 7:
			if event.axis == yaw[0] and absf(event.axis_value) < 0.2:
				go_to_next_step()
		elif calibration_step == 8:
			# Pitch axis
			if _reject_taken_axis(event):
				return
			if axes.find(event.axis) >= 0 and absf(event.axis_value) > 0.9:
				pitch.append(event.axis)
				pitch.append(event)
				go_to_next_step()
		elif calibration_step == 9:
			if event.axis == pitch[0]:
				if absf(event.axis_value + pitch[1].axis_value) < 0.2:
					pitch.append(event)
					go_to_next_step()
		elif calibration_step == 10:
			if event.axis == pitch[0] and absf(event.axis_value) < 0.2:
				go_to_next_step()
		elif calibration_step == 11:
			# Roll axis
			if _reject_taken_axis(event):
				return
			if axes.find(event.axis) >= 0 and absf(event.axis_value) > 0.9:
				roll.append(event.axis)
				roll.append(event)
				go_to_next_step()
		elif calibration_step == 12:
			if event.axis == roll[0]:
				if absf(event.axis_value + roll[1].axis_value) < 0.2:
					roll.append(event)
					go_to_next_step()
		elif calibration_step == 13:
			if event.axis == roll[0] and absf(event.axis_value) < 0.2:
				go_to_next_step()


## Axes already given to throttle, yaw or pitch cannot be picked again for another control.
func taken_axes() -> Dictionary:
	var taken := {}
	if throttle.size() > 0:
		taken[throttle[0]] = "CAL_AXIS_THROTTLE"
	if yaw.size() > 0:
		taken[yaw[0]] = "CAL_AXIS_YAW"
	if pitch.size() > 0:
		taken[pitch[0]] = "CAL_AXIS_PITCH"
	return taken


func _reject_taken_axis(event: InputEventJoypadMotion) -> bool:
	var taken := taken_axes()
	if not taken.has(event.axis):
		return false
	if absf(event.axis_value) > 0.9 and Time.get_ticks_msec() > _taken_notice_until:
		_taken_notice_until = Time.get_ticks_msec() + 1500
		UI.play("error")
		title.text = tr("CAL_AXIS_TAKEN") % [tr(taken[event.axis])]
	return true


func go_to_next_step() -> void:
	if calibration_step >= 0 and device >= 0:
		title.text = tr("CAL_TITLE_DEVICE") % [Input.get_joy_name(device)]
	calibration_step += 1
	calibration_step_changed.emit(calibration_step)

	match calibration_step:
		0:
			label_action.text = "CAL_STEP_CORNERS"
		1:
			label_action.text = "CAL_STEP_CENTER"
		2:
			label_action.text = "CAL_STEP_THROTTLE_UP"
		3:
			label_action.text = "CAL_STEP_THROTTLE_DOWN"
		4:
			label_action.text = "CAL_STEP_THROTTLE_CENTER"
		5:
			label_action.text = "CAL_STEP_YAW_LEFT"
		6:
			label_action.text = "CAL_STEP_YAW_RIGHT"
		7:
			label_action.text = "CAL_STEP_YAW_CENTER"
		8:
			label_action.text = "CAL_STEP_PITCH_UP"
		9:
			label_action.text = "CAL_STEP_PITCH_DOWN"
		10:
			label_action.text = "CAL_STEP_PITCH_CENTER"
		11:
			label_action.text = "CAL_STEP_ROLL_LEFT"
		12:
			label_action.text = "CAL_STEP_ROLL_RIGHT"
		13:
			label_action.text = "CAL_STEP_ROLL_CENTER"
		_:
			label_action.text = "CAL_SUCCESS"
			calibration_done.emit()


func _on_calibration_done() -> void:
	calibration_is_done = true
	apply_calibration()
	var err := save_input_map()
	if err != OK:
		await UI.alert("CAL_SAVE_ERROR")

	await get_tree().create_timer(2.0).timeout
	request_back()


## Replaces only the joypad events of the stick actions: W/S/A/D and the arrows must keep
## flying the drone after a calibration.
func apply_calibration() -> void:
	var pairs := [["throttle_up", throttle[1]], ["throttle_down", throttle[2]],
			["yaw_left", yaw[1]], ["yaw_right", yaw[2]],
			["pitch_down", pitch[1]], ["pitch_up", pitch[2]],
			["roll_left", roll[1]], ["roll_right", roll[2]]]
	for pair: Array in pairs:
		Controls.erase_joypad_events(pair[0])
	for pair: Array in pairs:
		InputMap.action_add_event(pair[0], pair[1])


func save_input_map() -> Error:
	var _dir_err := DirAccess.make_dir_recursive_absolute(Controls.CONFIG_DIR)
	var config := ConfigFile.new()
	var err := config.load(Controls.input_map_path)
	if err == OK or err == ERR_FILE_NOT_FOUND:
		var guid := Input.get_joy_guid(device)
		config.set_value("controls", "active_controller_guid", guid)
		config.set_value("controls", "active_controller_name", Input.get_joy_name(device))

		config.set_value("controls_%s" % [guid], "throttle_up", throttle[1].axis)
		var inverted := false
		if sign(throttle[2].axis_value) < 0:
			inverted = true
		config.set_value("controls_%s" % [guid], "throttle_inverted", inverted)
		config.set_value("controls_%s" % [guid], "yaw_left", yaw[1].axis)
		inverted = false
		if sign(yaw[2].axis_value) < 0:
			inverted = true
		config.set_value("controls_%s" % [guid], "yaw_inverted", inverted)
		config.set_value("controls_%s" % [guid], "pitch_up", pitch[1].axis)
		inverted = false
		if sign(pitch[2].axis_value) > 0:
			inverted = true
		config.set_value("controls_%s" % [guid], "pitch_inverted", inverted)
		config.set_value("controls_%s" % [guid], "roll_left", roll[1].axis)
		inverted = false
		if sign(roll[2].axis_value) < 0:
			inverted = true
		config.set_value("controls_%s" % [guid], "roll_inverted", inverted)
		err = config.save(Controls.input_map_path)
		if err != OK:
			push_error("Could not save calibration data to file: %s" % [error_string(err)])
	else:
		push_error("Could not save calibration data to file: %s" % [error_string(err)])
	return err


func reset_calibration() -> void:
	calibration_is_done = false
	calibration_step = -1
	axes.clear()
	throttle.clear()
	yaw.clear()
	pitch.clear()
	roll.clear()
	go_to_next_step()


func _on_cancel_pressed() -> void:
	reset_calibration()
	request_back()
