# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: no Global autoload,
# rebinding a joypad button keeps the keyboard and mouse bindings, stick deadzone row, L1/R1
# columns, controller auto-detection only when the list is opened with the mouse.
extends MenuScreen


signal controller_detected

var packed_calibration_menu := preload("res://gui/options_menu/controls_menu/calibration_menu.tscn")
var binding_popup: BindingPopup = null

@onready var controller_list := %ControllerList as OptionButton
@onready var controller_checkbutton := %ControllerCheckButton as CheckButton
@onready var axes_list := %AxesList as VBoxContainer
@onready var button_grid := %ButtonGrid as GridContainer

@onready var button_calibrate := %ButtonCalibrate as Button
@onready var button_reset := %ButtonReset as Button
@onready var button_back := %ButtonBack as Button
@onready var menu_panel := %MenuPanel as Control
@onready var radio_transmitter := %RadioTransmitter

@onready var actions_list := %ActionsVBox as VBoxContainer
@onready var deadzone_slider := %DeadzoneSlider as HSlider
@onready var deadzone_value := %DeadzoneValue as Label
var show_binding_popup := false
var binding_popup_clear := false
var binding_event: InputEvent = null
var binding_target: GUIControllerBinding = null

var connected_joypads: Array[int] = []
var auto_detect_controller := false
var active_controller := -1
var default_controller := -1

var calibrating_axes := false


func _ready() -> void:
	initial_focus = controller_list
	focus_groups = [$Columns/ControllerPanel as Control, menu_panel,
			$Columns/BindingsPanel as Control]
	super()
	var _discard := controller_detected.connect(_on_controller_autodetected)
	_discard = Input.joy_connection_changed.connect(_on_joypad_connection_changed)

	_discard = button_calibrate.pressed.connect(_on_calibrate_pressed)
	_discard = button_reset.pressed.connect(_on_reset_pressed)
	bind_back_button(button_back)

	_discard = controller_list.pressed.connect(_on_controller_list_pressed)
	_discard = controller_list.get_popup().id_pressed.connect(_on_controller_selected)
	_discard = controller_list.get_popup().popup_hide.connect(_on_controller_select_aborted)
	controller_list.clip_text = true

	_discard = controller_checkbutton.toggled.connect(_on_checkbutton_toggled)

	deadzone_slider.value = GameSettings.get_stick_deadzone()
	_update_deadzone_label(deadzone_slider.value)
	_discard = deadzone_slider.value_changed.connect(_on_deadzone_changed)

	# Controller selector, axes and buttons
	for _i in 8:
		var axis := GUIControllerAxis.new()
		axis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		axes_list.add_child(axis)

	for _i in 16:
		var button := GUIControllerButton.new()
		button.size_flags_horizontal = SIZE_SHRINK_CENTER
		button_grid.add_child(button)
		button.custom_minimum_size = Vector2(36, 24)

	var active_controller_found := false
	var active_device := -1
	connected_joypads = Input.get_connected_joypads()
	for joypad in connected_joypads:
		if Input.get_joy_guid(joypad) == Controls.active_controller_guid:
			active_controller_found = true
			active_device = joypad
			break
	if !active_controller_found:
		var default_controller_found := false
		if default_controller >= 0:
			for joypad in connected_joypads:
				if Input.get_joy_guid(joypad) == Controls.default_controller_guid:
					default_controller_found = true
					default_controller = joypad
					active_device = joypad
		if !default_controller_found:
			if connected_joypads.is_empty():
				active_device = -1
			else:
				active_device = connected_joypads[0]
	update_controller_list()
	controller_list.get_popup().id_pressed.emit(connected_joypads.find(active_device))

	# Actions bindings
	for action in Controls.action_list:
		var binding := GUIControllerBinding.new()
		actions_list.add_child(binding)
		binding.action = action.action_name
		binding.label.text = tr(action.action_label)
		_discard = binding.clicked.connect(_on_binding_clicked.bind(binding))
		_discard = binding.binding_updated.connect(_on_binding_updated)


func _before_back() -> void:
	Controls.restore_keyboard_shortcuts()


# Joypad events are read in _input: with a focused control the GUI would otherwise consume
# the buttons that are also ui_* actions (A, B, D-pad) before this menu could see them.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if auto_detect_controller:
			if event is InputEventJoypadMotion and absf(event.axis_value) > 0.8 \
					or event is InputEventJoypadButton:
				get_viewport().set_input_as_handled()
				controller_detected.emit(event.device)
				return
		elif Input.get_joy_name(event.device) == controller_list.text:
			if event is InputEventJoypadMotion and event.axis < 8:
				update_axis_value(event.axis, event.axis_value)
			elif event is InputEventJoypadButton and event.button_index < 16:
				update_button_value(event.button_index, event.is_pressed())
			if show_binding_popup and binding_popup and binding_popup.is_listening():
				var binding_text := ""
				if event is InputEventJoypadMotion and absf(event.axis_value) > 0.8:
					binding_text = tr("CTRL_AXIS_N") % [event.axis]
				elif event is InputEventJoypadButton and event.is_pressed() \
						and event.button_index < JOY_BUTTON_MAX:
					binding_text = tr("CTRL_BUTTON_N") % [event.button_index]
				if event is InputEventJoypadButton:
					# Never let a button reach the GUI while listening
					get_viewport().set_input_as_handled()
				if not binding_text.is_empty():
					binding_event = event
					binding_popup_clear = false
					binding_popup.set_captured(binding_text)
				return
	super(event)


func _on_deadzone_changed(value: float) -> void:
	_update_deadzone_label(value)
	GameSettings.set_stick_deadzone(value)


func _update_deadzone_label(value: float) -> void:
	deadzone_value.text = "%d %%" % [roundi(value * 100.0)]


func _on_calibrate_pressed() -> void:
	if not packed_calibration_menu.can_instantiate():
		return
	var calibration_menu := packed_calibration_menu.instantiate()
	add_child(calibration_menu)
	var _discard := calibration_menu.connect("calibration_step_changed",
			radio_transmitter._on_calibration_step_changed)
	calibration_menu.calibration_step_changed.emit(calibration_menu.calibration_step)
	menu_panel.visible = false
	radio_transmitter.accept_input = false
	await calibration_menu.back
	radio_transmitter.accept_input = true
	calibration_menu.queue_free()
	menu_panel.visible = true
	await get_tree().process_frame
	if UI.wants_focus():
		button_calibrate.grab_focus()


func _on_reset_pressed() -> void:
	if Controls.active_controller_guid.is_empty():
		return
	var confirmed: bool = await UI.confirm("CTRL_RESET_CONFIRM", "CTRL_RESET", "UI_CANCEL", true)
	if not confirmed:
		return
	for binding in actions_list.get_children():
		(binding as GUIControllerBinding).remove_binding()
	Controls.reset_controller_bindings()
	update_input_map()
	if UI.wants_focus():
		button_reset.grab_focus()


func update_controller_list() -> void:
	connected_joypads = Input.get_connected_joypads()
	controller_list.get_popup().clear()
	if connected_joypads.is_empty():
		controller_list.get_popup().add_item("CTRL_NO_CONTROLLER")
		controller_list.text = "CTRL_NO_CONTROLLER"
		active_controller = -1
		controller_checkbutton.disabled = true
		controller_checkbutton.button_pressed = false
	else:
		for joypad in connected_joypads:
			controller_list.get_popup().add_item(Input.get_joy_name(joypad))
		controller_checkbutton.disabled = false


func _on_joypad_connection_changed(_device: int, _connected: bool) -> void:
	update_controller_list()
	var active_controller_found := false
	for joypad in connected_joypads:
		if Input.get_joy_name(joypad) == controller_list.text:
			active_controller_found = true
			break
	if !active_controller_found:
		active_controller = -1
		controller_list.get_popup().id_pressed.emit(active_controller)


## Opened with a click, the list also picks the controller whose button is pressed next.
## Opened with a gamepad or the keyboard it is a normal list: the pad's own buttons have to
## navigate it.
func _on_controller_list_pressed() -> void:
	update_controller_list()
	auto_detect_controller = UI.is_using_mouse()


func _on_controller_select_aborted() -> void:
	auto_detect_controller = false


func _on_controller_autodetected(device: int) -> void:
	active_controller = device
	controller_list.get_popup().id_pressed.emit(connected_joypads.find(device))


func _on_controller_selected(id: int) -> void:
	if controller_list.get_popup().visible:
		controller_list.get_popup().hide()
	auto_detect_controller = false
	if connected_joypads.is_empty() or id < 0 or id >= connected_joypads.size():
		return
	if connected_joypads[id] != active_controller:
		active_controller = connected_joypads[id]
		var checkbutton_pressed: bool = (Input.get_joy_guid(active_controller) \
				== Controls.default_controller_guid)
		controller_checkbutton.button_pressed = checkbutton_pressed
		var _discard := Controls.update_active_device(active_controller)
		update_input_map.call_deferred()
		update_axes_and_buttons.call_deferred(active_controller)


func _on_checkbutton_toggled(pressed: bool) -> void:
	if (!pressed and active_controller != default_controller) \
			or (pressed and active_controller == default_controller):
		return
	default_controller = active_controller if pressed else -1
	var err := Controls.update_default_device(default_controller)
	if err != OK:
		push_error("Error while saving default controller settings: %s" % [error_string(err)])


func update_axes_and_buttons(device: int) -> void:
	controller_list.text = Input.get_joy_name(device)
	for i in 8:
		update_axis_value(i, Input.get_joy_axis(device, i))
	for i in 16:
		update_button_value(i, Input.is_joy_button_pressed(device, i))


func update_axis_value(id: int, value: float) -> void:
	axes_list.get_children()[id].value = value


func update_button_value(id: int, pressed: bool) -> void:
	var button := button_grid.get_children()[id] as GUIControllerButton
	button.value = pressed as int


func update_input_map() -> void:
	for binding in actions_list.get_children():
		(binding as GUIControllerBinding).remove_binding()
	var _discard := Controls.load_input_map()
	var act_list := Controls.action_list
	for i in act_list.size():
		var act := act_list[i] as ControllerAction
		var binding := actions_list.get_child(i)
		if act.bound:
			if act.type == ControllerAction.Type.BUTTON:
				var event := InputEventJoypadButton.new()
				event.button_index = act.button as JoyButton
				event.device = active_controller
				update_binding.call_deferred(binding, event)
			elif act.type == ControllerAction.Type.AXIS:
				var event := InputEventJoypadMotion.new()
				event.axis = act.axis as JoyAxis
				event.device = active_controller
				update_binding.call_deferred(binding, event)


func save_input_map() -> void:
	var section := "controls_" + Controls.active_controller_guid
	var config := ConfigFile.new()
	var err := config.load(Controls.input_map_path)
	if err == OK or err == ERR_FILE_NOT_FOUND:
		for action in Controls.action_list:
			var action_name: String = action.action_name
			if config.has_section_key(section, action_name):
				config.erase_section_key(section, action_name)
				for key: String in ["_button", "_axis", "_min", "_max"]:
					if config.has_section_key(section, action_name + key):
						config.erase_section_key(section, action_name + key)
			if action.bound:
				config.set_value(section, action_name, action.type)
				if action.type == ControllerAction.Type.BUTTON:
					config.set_value(section, action_name + "_button", action.button)
				elif action.type == ControllerAction.Type.AXIS:
					config.set_value(section, action_name + "_axis", action.axis)
					config.set_value(section, action_name + "_min", action.axis_min)
					config.set_value(section, action_name + "_max", action.axis_max)
		err = config.save(Controls.input_map_path)
		if err != OK:
			push_error("Error while saving input map: %s" % [error_string(err)])
	else:
		push_error("Error while saving input map: %s" % [error_string(err)])


func update_binding(binding: GUIControllerBinding, event: InputEvent) -> void:
	var action := binding.action
	binding.action_idx = actions_list.get_children().find(binding)
	if InputMap.has_action(action):
		# Only the joypad events: the keyboard and mouse bindings of the game stay.
		Controls.erase_joypad_events(action)
		binding.update_binding(event)


func _current_binding_text(binding: GUIControllerBinding) -> String:
	var action_events := InputMap.action_get_events(binding.action)
	for event in action_events:
		if event is InputEventJoypadMotion:
			return tr("CTRL_AXIS_N") % [event.axis]
		elif event is InputEventJoypadButton:
			return tr("CTRL_BUTTON_N") % [event.button_index]
	if binding.device >= 0 and binding.axis >= 0:
		return tr("CTRL_AXIS_N") % [binding.axis]
	return tr("CTRL_UNBOUND")


func _on_binding_clicked(binding: GUIControllerBinding) -> void:
	if show_binding_popup:
		return
	binding_target = binding
	binding_event = null
	binding_popup_clear = false
	binding_popup = BindingPopup.new()
	binding_popup.action_label = binding.label.text
	binding_popup.current_binding = _current_binding_text(binding)
	add_child(binding_popup)
	show_binding_popup = true

	var _discard := binding_popup.confirm_pressed.connect(_on_binding_confirmed)
	_discard = binding_popup.cancel_pressed.connect(_close_binding_popup)
	_discard = binding_popup.clear_pressed.connect(
		func _on_clear_pressed() -> void:
			binding_event = null
			binding_popup_clear = true
			binding_popup.set_captured(tr("CTRL_UNBOUND"))
	)
	_discard = binding_popup.listen_pressed.connect(
		func _on_listen_pressed() -> void:
			binding_event = null
			binding_popup_clear = false
	)


func _on_binding_confirmed() -> void:
	if binding_event or binding_popup_clear:
		update_binding(binding_target, binding_event)
	_close_binding_popup()


func _close_binding_popup() -> void:
	var target := binding_target
	binding_event = null
	binding_popup_clear = false
	binding_target = null
	show_binding_popup = false
	if binding_popup:
		binding_popup.close()
		binding_popup = null
	await get_tree().process_frame
	if is_instance_valid(target) and UI.wants_focus():
		target.grab_focus()


func _on_binding_updated() -> void:
	save_input_map()
