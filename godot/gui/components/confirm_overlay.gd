# Modified from drone-simulator (GPL-3.0), 2026: every direction moves between the buttons,
# explicit accept handling and a hint row with the buttons of the device in use.
class_name ConfirmOverlay
extends Control
## Modal question drawn inside the interface (no OS window), navigable with
## mouse, keyboard, gamepad and radio sticks. Created through UI.confirm() / UI.alert().


signal closed(confirmed: bool)

var _text := ""
var _ok_text := "UI_OK"
var _cancel_text := ""
var _danger := false
var _done := false
var _card: PanelContainer = null
var _button_ok: Button = null
var _button_cancel: Button = null
var _hint: Label = null


func setup(text: String, ok_text: String, cancel_text: String, danger: bool) -> void:
	_text = text
	_ok_text = ok_text
	_cancel_text = cancel_text
	_danger = danger


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	_card = PanelContainer.new()
	_card.theme_type_variation = &"Card"
	_card.custom_minimum_size = Vector2(560, 0)
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 28)
	_card.add_child(vbox)

	var label := Label.new()
	label.text = _text
	label.theme_type_variation = &"HeadingLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(480, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 12)
	vbox.add_child(buttons)

	if not _cancel_text.is_empty():
		_button_cancel = Button.new()
		_button_cancel.text = _cancel_text
		_button_cancel.custom_minimum_size = Vector2(150, 0)
		_button_cancel.set_meta(&"ui_back", true)
		buttons.add_child(_button_cancel)
		var _discard := _button_cancel.pressed.connect(_close.bind(false))

	_button_ok = Button.new()
	_button_ok.text = _ok_text
	_button_ok.custom_minimum_size = Vector2(150, 0)
	_button_ok.theme_type_variation = &"DangerButton" if _danger else &"PrimaryButton"
	buttons.add_child(_button_ok)
	var _discard := _button_ok.pressed.connect(_close.bind(true))

	_hint = Label.new()
	_hint.theme_type_variation = &"HintLabel"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_hint)
	_update_hint()
	_discard = UI.input_kind_changed.connect(_update_hint.unbind(1))
	_discard = Controls.input_device_changed.connect(_update_hint.unbind(1))

	# Keep keyboard/gamepad focus inside the dialog. Every direction moves to the other
	# button: with two buttons side by side, up and down (stick or D-pad) must reach
	# Confirm too.
	var focusables: Array[Button] = []
	if _button_cancel:
		focusables.append(_button_cancel)
	focusables.append(_button_ok)
	for i in focusables.size():
		var b := focusables[i]
		var prev := focusables[wrapi(i - 1, 0, focusables.size())]
		var next := focusables[wrapi(i + 1, 0, focusables.size())]
		b.focus_neighbor_left = b.get_path_to(prev)
		b.focus_neighbor_right = b.get_path_to(next)
		b.focus_neighbor_top = b.get_path_to(prev)
		b.focus_neighbor_bottom = b.get_path_to(next)
		b.focus_previous = b.get_path_to(prev)
		b.focus_next = b.get_path_to(next)

	UI.register_context(self)
	modulate.a = 0.0
	_card.pivot_offset = Vector2(280, 80)
	_card.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var _step1 := tween.tween_property(self, "modulate:a", 1.0, 0.14)
	var _step2 := tween.tween_property(_card, "scale", Vector2.ONE, 0.18)
	grab_initial_focus.call_deferred(true)


func _exit_tree() -> void:
	UI.unregister_context(self)


## The safe choice gets the focus: Cancel when there is one.
func grab_initial_focus(force := false) -> void:
	if not force and not UI.wants_focus():
		return
	UI.mute_for(0.1)
	if _button_cancel:
		_button_cancel.grab_focus()
	elif _button_ok:
		_button_ok.grab_focus()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"ui_accept", false, true) and not _owns_focus():
		# Accept with the focus somewhere else (or nowhere): show the choice first, never
		# answer blindly.
		get_viewport().set_input_as_handled()
		grab_initial_focus(true)
	elif event.is_action_pressed(&"ui_cancel", false, true):
		get_viewport().set_input_as_handled()
		UI.play("back")
		_close(false)
	elif event.is_action_pressed(&"pause_menu", false, true):
		# Do not let the pause menu react underneath the dialog
		get_viewport().set_input_as_handled()


func _owns_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus != null and (focus == _button_ok or focus == _button_cancel)


func _update_hint() -> void:
	if not is_instance_valid(_hint):
		return
	var parts := PackedStringArray()
	parts.append("%s  %s" % [InputHints.menu_key(&"ui_accept"), tr("UI_HINT_ACCEPT")])
	if _button_cancel:
		parts.append("%s  %s" % [InputHints.menu_key(&"ui_cancel"), tr("UI_HINT_BACK")])
	_hint.text = "      ".join(parts)


func _close(confirmed: bool) -> void:
	if _done:
		return
	_done = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	var _step3 := tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	closed.emit(confirmed)
	queue_free()
