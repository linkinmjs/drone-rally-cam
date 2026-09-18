class_name BindingPopup
extends Control
## Assigns a controller input to an action. Two states:
## LISTENING waits for a button or a switch (the controls menu feeds it the event),
## CAPTURED shows what was detected and lets the user confirm with any device.


signal confirm_pressed
signal cancel_pressed
signal clear_pressed
signal listen_pressed

enum State {LISTENING, CAPTURED}

var action_label := ""
var current_binding := ""
var state := State.LISTENING

var _title: Label = null
var _message: Label = null
var _detected: Label = null
var button_confirm := Button.new()
var button_cancel := Button.new()
var button_clear := Button.new()
var button_listen := Button.new()
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := Panel.new()
	scrim.theme_type_variation = &"OverlayScrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 14)
	card.add_child(vbox)

	_title = Label.new()
	_title.theme_type_variation = &"HeadingLabel"
	_title.text = action_label
	vbox.add_child(_title)

	_message = Label.new()
	_message.theme_type_variation = &"CaptionLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_message)

	_detected = Label.new()
	_detected.theme_type_variation = &"TitleLabel"
	_detected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detected.custom_minimum_size = Vector2(0, 90)
	_detected.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_detected)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 10)
	vbox.add_child(buttons)

	button_clear.text = "CTRL_CLEAR"
	button_clear.theme_type_variation = &"GhostButton"
	button_listen.text = "CTRL_LISTEN_AGAIN"
	button_cancel.text = "UI_CANCEL"
	button_cancel.set_meta(&"ui_back", true)
	button_confirm.text = "UI_CONFIRM"
	button_confirm.theme_type_variation = &"PrimaryButton"
	for button: Button in [button_clear, button_listen, button_cancel, button_confirm]:
		button.custom_minimum_size = Vector2(120, 0)
		buttons.add_child(button)

	var _discard := button_confirm.pressed.connect(func() -> void: confirm_pressed.emit())
	_discard = button_cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	_discard = button_clear.pressed.connect(func() -> void: clear_pressed.emit())
	_discard = button_listen.pressed.connect(_on_listen_pressed)

	UI.register_context(self)
	_set_state(State.LISTENING)
	_detected.text = current_binding
	modulate.a = 0.0
	var tween := create_tween()
	var _step1 := tween.tween_property(self, "modulate:a", 1.0, 0.14)


func _exit_tree() -> void:
	StickNavigation.suspended = false
	UI.unregister_context(self)


func is_listening() -> bool:
	return state == State.LISTENING and not _closing


func set_text(text: String) -> void:
	_message.text = text


func set_captured(binding_text: String) -> void:
	_detected.text = binding_text
	_set_state(State.CAPTURED)


func _on_listen_pressed() -> void:
	_detected.text = "…"
	listen_pressed.emit()
	_set_state(State.LISTENING)


func _set_state(new_state: State) -> void:
	state = new_state
	var listening := state == State.LISTENING
	# While listening the sticks and switches are the input being assigned
	StickNavigation.suspended = listening
	_message.text = tr("CTRL_BINDING_LISTENING") if listening else tr("CTRL_BINDING_CAPTURED")
	button_confirm.visible = not listening
	button_listen.visible = not listening
	_detected.add_theme_color_override(&"font_color",
			UIPalette.TEXT_2 if listening else UIPalette.ACCENT)
	var visible_buttons: Array[Button] = []
	for button: Button in [button_clear, button_listen, button_cancel, button_confirm]:
		if button.visible:
			visible_buttons.append(button)
	for i in visible_buttons.size():
		var b := visible_buttons[i]
		var prev := visible_buttons[wrapi(i - 1, 0, visible_buttons.size())]
		var next := visible_buttons[wrapi(i + 1, 0, visible_buttons.size())]
		b.focus_neighbor_left = b.get_path_to(prev)
		b.focus_neighbor_right = b.get_path_to(next)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_previous = b.get_path_to(prev)
		b.focus_next = b.get_path_to(next)
	grab_initial_focus.call_deferred(true)


func grab_initial_focus(force := false) -> void:
	if not is_inside_tree() or (not force and UI.is_using_mouse()):
		return
	UI.mute_for(0.1)
	if state == State.CAPTURED:
		button_confirm.grab_focus()
	else:
		button_cancel.grab_focus()


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if state == State.LISTENING:
		# Joypad buttons are candidates for the binding, so only the keyboard can cancel here
		if event is InputEventKey and event.is_action_pressed(&"ui_cancel", false, true):
			get_viewport().set_input_as_handled()
			UI.play("back")
			cancel_pressed.emit()
	elif event.is_action_pressed(&"ui_cancel", false, true):
		get_viewport().set_input_as_handled()
		UI.play("back")
		cancel_pressed.emit()


func close() -> void:
	if _closing:
		return
	_closing = true
	StickNavigation.suspended = false
	var tween := create_tween()
	var _step2 := tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()
