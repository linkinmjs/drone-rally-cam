# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: shows the name of
# the bound gamepad button.
class_name GUIControllerBinding
extends VBoxContainer


signal clicked
signal binding_updated


var action_idx := -1
var action := ""
var label := Label.new()
var controller_button := GUIControllerButton.new()
## Name of the gamepad button or axis bound to the action, read from the input map.
var binding_name := Label.new()
var axis_range: GUIControllerAxisRange = null
var device := -1
var button := -1
var axis := -1
var axis_value := 0.0

var highlight := false
var pressed := false


func _ready() -> void:
	add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(row)
	row.add_child(controller_button)
	binding_name.theme_type_variation = &"CaptionLabel"
	binding_name.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(binding_name)
	refresh_binding_name.call_deferred()
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	controller_button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	controller_button.size_flags_vertical = SIZE_SHRINK_CENTER
	controller_button.custom_minimum_size = Vector2(controller_button.custom_minimum_size.x, 16)
	controller_button.set_range(0, 1, 1)
	controller_button.value = 0
	controller_button.set_color_on(UIPalette.SUCCESS, true)

	label.mouse_filter = Control.MOUSE_FILTER_PASS
	controller_button.mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override(&"separation", 6)

	# Navigable with keyboard, gamepad and sticks: the row behaves like a button
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var _discard := mouse_entered.connect(_on_mouse_entered)
	_discard = mouse_exited.connect(_on_mouse_exited)
	_discard = focus_entered.connect(queue_redraw)
	_discard = focus_exited.connect(queue_redraw)


func _draw() -> void:
	var style := &"normal"
	if has_focus():
		style = &"focus"
	elif highlight:
		style = &"hover"
	var box := get_theme_stylebox(style, &"RowPanel")
	if box:
		draw_style_box(box, Rect2(Vector2(-10, -6), size + Vector2(20, 12)))


func _on_mouse_entered() -> void:
	highlight = true
	queue_redraw()
	UI.play("hover")


func _on_mouse_exited() -> void:
	highlight = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept", false, true):
		accept_event()
		UI.play("click")
		clicked.emit()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressed = true
			elif pressed and !event.pressed:
				pressed = false
				var pos: Vector2 = event.position
				var rmax := size
				if pos.x >= 0 and pos.x <= rmax.x and pos.y >= 0 and pos.y <= rmax.y:
					clicked.emit()
				else:
					mouse_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		if event.device == device and event.axis == axis:
			axis_range.axis_monitor.value = event.axis_value
			axis_value = event.axis_value
			check_action_state()
	elif InputMap.has_action(action):
		if event.is_action(action):
			if event.pressed:
				controller_button.value = 1
			else:
				controller_button.value = 0


func update_binding(event: InputEvent) -> void:
	if event:
		var act: ControllerAction = Controls.action_list[action_idx]
		act.bound = true
		if event is InputEventJoypadButton:
			remove_axis_range()
			InputMap.action_add_event(action, event)
			device = event.device
			button = event.button_index
			act.type = ControllerAction.Type.BUTTON
			act.button = event.button_index
		elif event is InputEventJoypadMotion:
			act.button = -1
			remove_axis_range()
			add_axis_range(event)
			act.type = ControllerAction.Type.AXIS
			act.axis = axis
			axis_range.set_bounds.call_deferred(act.axis_min, act.axis_max)
	else:
		remove_binding()
	refresh_binding_name()
	binding_updated.emit()
	check_action_state()


## Shows which gamepad button or axis the action is on now.
func refresh_binding_name() -> void:
	var text := InputHints.event_name(action, true)
	binding_name.text = text if not text.is_empty() else tr("CTRL_UNBOUND")


func remove_binding() -> void:
	remove_axis_range()
	button = -1
	device = -1
	Input.parse_input_event(simulate_action_event(action, false))
	Controls.action_list[action_idx].unbind()
	refresh_binding_name()


func add_axis_range(event: InputEventJoypadMotion) -> void:
	axis_range = GUIControllerAxisRange.new()
	add_child(axis_range)
	var _discard := axis_range.range_updated.connect(_on_axis_range_updated)
	_discard = axis_range.range_released.connect(_on_axis_range_released)
	device = event.device
	axis = event.axis
	axis_value = Input.get_joy_axis(device, axis)


func remove_axis_range() -> void:
	if axis_range:
		remove_child(axis_range)
		axis_range.queue_free()
		axis_range = null
		axis = -1
		axis_value = 0.0


func _on_axis_range_updated() -> void:
	check_action_state()


func _on_axis_range_released() -> void:
	var act: ControllerAction = Controls.action_list[action_idx]
	if act.bound and act.type == ControllerAction.Type.AXIS:
		act.axis_min = axis_range.bound_low
		act.axis_max = axis_range.bound_high
		binding_updated.emit()


func check_action_state() -> void:
	var act: ControllerAction = Controls.action_list[action_idx]
	if act.bound == false:
		Input.parse_input_event(simulate_action_event(action, false))
	else:
		if act.type == ControllerAction.Type.BUTTON:
			Input.parse_input_event(simulate_action_event(
					action, Input.is_joy_button_pressed(device, button)))
		else:
			axis_range.axis_monitor.value = axis_value
			var bound_low := axis_range.bound_low
			var bound_high := axis_range.bound_high
			if !Input.is_action_pressed(action) and axis_value >= bound_low and axis_value <= bound_high:
				Input.parse_input_event(simulate_action_event(action, true))
			elif Input.is_action_pressed(action) and (axis_value < bound_low or axis_value > bound_high):
				Input.parse_input_event(simulate_action_event(action, false))


func simulate_action_event(action_name: String, action_pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = action_pressed
	return event
