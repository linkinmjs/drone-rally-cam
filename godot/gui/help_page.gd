# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: game help sections
# with section headers, and the controls drawn as the buttons of the device in use.
extends MenuScreen


## Sections of the help page, in order. Each one is a translation key with BBCode whose first
## line is the title in bold. HELP_CONTROLS only gives its title: its body is the controls
## reference below, drawn with KeyCaps.
const SECTIONS: Array[String] = ["HELP_GOAL", "HELP_CONTROLS", "HELP_ARMING",
		"HELP_FLIGHT_MODES", "HELP_SCORING", "HELP_BATTERY_CRASH", "HELP_DEVICE",
		"HELP_MENU_NAVIGATION"]
## Controls reference: [actions, label, text shown on keyboard and mouse instead of the first
## binding].
const WALKING := [
	[[&"move_forward"], "HELP_KEY_WALK", "W A S D"],
	[[&"look_up"], "HELP_KEY_LOOK", "Mouse"],
	[[&"sprint"], "HELP_KEY_SPRINT", ""],
	[[&"interact"], "HELP_KEY_INTERACT", ""],
	[[&"pilot_toggle"], "CTRL_ACTION_PILOT_TOGGLE", ""],
	[[&"show_map"], "CTRL_ACTION_SHOW_MAP", ""],
]
const FLYING := [
	[[&"throttle_up"], "HELP_KEY_THROTTLE_YAW", "W A S D"],
	[[&"pitch_up"], "HELP_KEY_PITCH_ROLL", "↑ ↓ ← →"],
	[[&"toggle_arm"], "CTRL_ACTION_ARM_TOGGLE", ""],
	[[&"cycle_flight_modes"], "CTRL_ACTION_CYCLE_MODES", ""],
	[[&"rec_toggle"], "CTRL_ACTION_REC", ""],
	[[&"change_camera"], "CTRL_ACTION_CHANGE_CAMERA", ""],
	[[&"gimbal_up", &"gimbal_down"], "HELP_KEY_GIMBAL", ""],
	[[&"respawn"], "CTRL_ACTION_RESPAWN", ""],
	[[&"pause_menu"], "HELP_KEY_PAUSE", ""],
]
## Pixels scrolled by each up or down press (D-pad, right stick, arrows).
const SCROLL_STEP := 110.0

@onready var scroll := %HelpScroll as ScrollContainer
@onready var sections := %Sections as VBoxContainer
@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	initial_focus = scroll
	super()
	bind_back_button(button_back)
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_build()


## Up and down scroll the page while it has the focus; past the end, down moves on to Back.
func _input(event: InputEvent) -> void:
	super(event)
	if get_viewport().is_input_handled() or not is_visible_in_tree() or UI.get_active_context() != self:
		return
	if get_viewport().gui_get_focus_owner() != scroll:
		return
	var up := event.is_action_pressed(&"ui_up", true, true)
	var down := event.is_action_pressed(&"ui_down", true, true)
	if not (up or down):
		return
	var bar := scroll.get_v_scroll_bar()
	var at_end := scroll.scroll_vertical >= int(bar.max_value - bar.page) - 1
	if down and at_end:
		return
	accept_event()
	scroll.scroll_vertical += int(SCROLL_STEP * (1.0 if down else -1.0))


## Number of KeyCaps in the controls reference (for the checks).
func key_cap_count() -> int:
	return sections.find_children("*", "KeyCap", true, false).size()


func _build() -> void:
	for child in sections.get_children():
		sections.remove_child(child)
		child.queue_free()
	for key in SECTIONS:
		var text := tr(key).replace("{accent}", UIPalette.ACCENT.to_html(false))
		var title := ""
		var body := text
		if text.begins_with("[b]") and text.contains("[/b]"):
			var end := text.find("[/b]")
			title = text.substr(3, end - 3)
			body = text.substr(end + 4).strip_edges()
		var section := VBoxContainer.new()
		section.add_theme_constant_override(&"separation", 12)
		var header := Label.new()
		header.theme_type_variation = &"SectionHeader"
		header.uppercase = true
		header.text = title
		section.add_child(header)
		if key == "HELP_CONTROLS":
			section.add_child(_controls_reference())
		elif not body.is_empty():
			var label := RichTextLabel.new()
			label.theme_type_variation = &"BodyText"
			label.bbcode_enabled = true
			label.fit_content = true
			label.scroll_active = false
			label.selection_enabled = false
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			label.text = body
			var _discard := label.meta_clicked.connect(_on_url_clicked)
			section.add_child(label)
		sections.add_child(section)


func _controls_reference() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 56)
	box.add_child(columns)
	for column: Array in [["HELP_WALKING", WALKING], ["HELP_FLYING", FLYING]]:
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"InsetPanel"
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(panel)
		var content := VBoxContainer.new()
		content.add_theme_constant_override(&"separation", 14)
		panel.add_child(content)
		var heading := Label.new()
		heading.theme_type_variation = &"HeadingLabel"
		heading.text = column[0]
		content.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 16)
		grid.add_theme_constant_override(&"v_separation", 10)
		content.add_child(grid)
		for row: Array in column[1]:
			var keys := HBoxContainer.new()
			keys.add_theme_constant_override(&"separation", 6)
			keys.alignment = BoxContainer.ALIGNMENT_END
			keys.custom_minimum_size.x = 150
			for action: StringName in row[0]:
				var cap := KeyCap.new()
				cap.action = action
				cap.menu = false
				cap.keyboard_text = row[2]
				keys.add_child(cap)
			grid.add_child(keys)
			var label := Label.new()
			label.text = row[1]
			label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(label)
	var note := Label.new()
	note.theme_type_variation = &"CaptionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "HELP_CONTROLS_NOTE"
	box.add_child(note)
	return box


func _on_url_clicked(meta: Variant) -> void:
	var _discard := OS.shell_open(str(meta))
