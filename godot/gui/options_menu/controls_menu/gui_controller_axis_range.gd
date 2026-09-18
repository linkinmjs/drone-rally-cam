class_name GUIControllerAxisRange
extends Container


signal range_updated
signal range_released

var axis_monitor := GUIControllerAxis.new()
var axis_range := TextureProgressBar.new()
var button_low := Button.new()
var button_high := Button.new()
var bound_low := 0.0
var bound_high := 1.0

var dragging := 0
## Handle moved with keyboard / gamepad / sticks: 1 = low bound, 2 = high bound.
var active_handle := 1

const KEYBOARD_STEP := 0.05


func _ready() -> void:
	add_child(axis_monitor)
	add_child(axis_range)
	add_child(button_low)
	add_child(button_high)

	axis_range.size = axis_monitor.custom_minimum_size
	axis_range.texture_progress = ThemeBuilder.bar_texture()
	axis_range.tint_progress = Color(UIPalette.ACCENT, 0.35)
	axis_range.nine_patch_stretch = true
	axis_range.stretch_margin_top = 3
	axis_range.stretch_margin_bottom = 3
	axis_range.stretch_margin_left = 3
	axis_range.stretch_margin_right = 3
	axis_range.min_value = 0
	axis_range.max_value = 1
	axis_range.step = 0.1
	axis_range.value = 1

	var axis_size: Vector2 = axis_monitor.custom_minimum_size as Vector2
	button_low.custom_minimum_size = Vector2(20, axis_size.y + 20)
	var button_low_pos := (axis_size - (button_low.custom_minimum_size as Vector2) \
			+ bound_low * Vector2(axis_size.x, 0)) / 2
	button_low.position = button_low_pos
	button_high.custom_minimum_size = Vector2(20, axis_size.y + 20)
	var button_high_pos := (axis_size - (button_high.custom_minimum_size as Vector2) \
			+ bound_high * Vector2(axis_size.x, 0)) / 2
	button_high.position = button_high_pos
	button_low.focus_mode = Control.FOCUS_NONE
	button_high.focus_mode = Control.FOCUS_NONE
	# The range itself takes the focus: accept switches handle, left/right moves it
	focus_mode = Control.FOCUS_ALL
	set_meta(&"stick_value_control", true)
	var _focus := focus_entered.connect(_update_handle_highlight)
	_focus = focus_exited.connect(_update_handle_highlight)

	update_pos.call_deferred()

	var _discard := button_low.button_down.connect(_on_button_pressed.bind(1))
	_discard = button_high.button_down.connect(_on_button_pressed.bind(2))
	_discard = button_low.button_up.connect(_on_button_released)
	_discard = button_high.button_up.connect(_on_button_released)

	update_bounds.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and dragging > 0:
		var delta := (event as InputEventMouseMotion).relative.x
		var axis_size := axis_monitor.size
		if dragging == 1:
			var button_pos := button_low.position
			var button_size := button_low.size
			var xmin := -button_size.x / 2
			var xmax := button_high.position.x - button_size.x
			var posx := clampf(button_pos.x + delta, xmin, xmax - 1)
			button_low.position = Vector2(posx, button_pos.y)
		elif dragging == 2:
			var button_pos := button_high.position
			var button_size := button_high.size
			var xmin := button_low.position.x + button_low.size.x
			var xmax := axis_size.x - button_size.x / 2
			var posx := clampf(button_pos.x + delta, xmin + 1, xmax)
			button_high.position = Vector2(posx, button_pos.y)
		update_bounds()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept", false, true):
		active_handle = 2 if active_handle == 1 else 1
		_update_handle_highlight()
		UI.play("click")
		accept_event()
	elif event.is_action_pressed(&"ui_left", true, true) or event.is_action_pressed(&"ui_right", true, true):
		var step := KEYBOARD_STEP if event.is_action(&"ui_right", true) else -KEYBOARD_STEP
		var low := bound_low
		var high := bound_high
		if active_handle == 1:
			low = clampf(low + step, -1.0, high - KEYBOARD_STEP)
		else:
			high = clampf(high + step, low + KEYBOARD_STEP, 1.0)
		set_bounds(low, high)
		UI.play("tick")
		range_released.emit()
		accept_event()


func _update_handle_highlight() -> void:
	var focused := has_focus()
	button_low.theme_type_variation = &"PrimaryButton" if focused and active_handle == 1 else &""
	button_high.theme_type_variation = &"PrimaryButton" if focused and active_handle == 2 else &""
	queue_redraw()


func _draw() -> void:
	if has_focus():
		var ring := get_theme_stylebox(&"focus", &"Button")
		if ring:
			draw_style_box(ring, Rect2(Vector2(-6, -2), size + Vector2(12, 4)))


func update_pos() -> void:
	custom_minimum_size.y = button_high.size.y as int
	size_flags_vertical = SIZE_EXPAND
	grow_vertical = Control.GROW_DIRECTION_BOTH
	position = size / 2
	for child in get_children():
		child.position.y = (size - child.size).y / 2


func update_bounds() -> void:
	bound_low = (button_low.position.x + button_low.size.x / 2) / axis_monitor.size.x * 2 - 1
	bound_high = (button_high.position.x + button_high.size.x / 2) / axis_monitor.size.x * 2 - 1
	axis_range.size.x = button_high.position.x - button_low.position.x
	axis_range.position.x = button_low.position.x + button_low.size.x / 2
	range_updated.emit()


func set_bounds(low: float, high: float) -> void:
	button_low.position.x = (low + 1) * axis_monitor.size.x / 2 - button_low.size.x / 2
	button_high.position.x = (high + 1) * axis_monitor.size.x / 2 - button_high.size.x / 2
	update_bounds()


func _on_button_pressed(id: int) -> void:
	dragging = id


func _on_button_released() -> void:
	dragging = 0
	range_released.emit()
