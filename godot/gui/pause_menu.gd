# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: Restart stage and
# Back to the main menu (through the stage and SceneTransition); a context card with the stage,
# the clips delivered and the main controls.
class_name PauseMenu
extends MenuScreen


signal resumed
signal restart_requested
## The player confirmed going back to the main menu.
signal menu_requested

var packed_quad_settings_menu := preload("res://gui/quad_settings_menu.tscn")
var packed_help_page := preload("res://gui/help_page.tscn")
var packed_options_menu := preload("res://gui/options_menu/options_menu.tscn")

## Controls shown in the context card: [action, label].
const CONTROLS := [
	[&"toggle_arm", "CTRL_ACTION_ARM_TOGGLE"],
	[&"cycle_flight_modes", "CTRL_ACTION_CYCLE_MODES"],
	[&"rec_toggle", "CTRL_ACTION_REC"],
	[&"change_camera", "CTRL_ACTION_CHANGE_CAMERA"],
	[&"pilot_toggle", "CTRL_ACTION_PILOT_TOGGLE"],
	[&"respawn", "CTRL_ACTION_RESPAWN"],
]

var can_resume := true

@onready var button_resume := %ButtonResume as Button
@onready var button_quad := %ButtonQuad as Button
@onready var button_help := %ButtonHelp as Button
@onready var button_options := %ButtonOptions as Button
@onready var button_restart := %ButtonRestart as Button
@onready var button_quit := %ButtonQuit as Button
## Everything of this screen but the backdrop: hidden while a sub screen is open.
@onready var menu_container := %Layout as Control
@onready var stage_name := %StageName as Label
@onready var stage_status := %StageStatus as Label
@onready var clip_list := %ClipList as HFlowContainer
@onready var controls_grid := %ControlsGrid as GridContainer


func _ready() -> void:
	backdrop = Backdrop.SCRIM
	initial_focus = button_resume
	super()
	var _discard := button_resume.pressed.connect(_on_resume_pressed)
	_discard = button_quad.pressed.connect(_on_quad_settings_pressed)
	_discard = button_help.pressed.connect(_on_help_pressed)
	_discard = button_options.pressed.connect(_on_options_pressed)
	_discard = button_restart.pressed.connect(_on_restart_pressed)
	_discard = button_quit.pressed.connect(_on_quit_pressed)
	_build_controls()
	show_stage({}, [])


## Fills the context card: `summary` from Stage.stage_summary() and the clips delivered.
func show_stage(summary: Dictionary, clips: Array[ShotReport]) -> void:
	stage_name.text = String(summary.get("stage", ""))
	stage_status.text = String(summary.get("status", ""))
	stage_status.visible = not stage_status.text.is_empty()
	for child in clip_list.get_children():
		child.queue_free()
	if clips.is_empty():
		var none := Label.new()
		none.theme_type_variation = &"CaptionLabel"
		none.text = "PAUSE_NO_CLIPS"
		clip_list.add_child(none)
		return
	for clip in clips:
		clip_list.add_child(_clip_chip(clip))


## Number of clip chips shown (for the checks).
func clip_chip_count() -> int:
	var count := 0
	for child in clip_list.get_children():
		if child is PanelContainer and not child.is_queued_for_deletion():
			count += 1
	return count


func _clip_chip(clip: ShotReport) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"StatChip"
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	chip.add_child(row)
	var grade := Label.new()
	grade.theme_type_variation = &"GradeLabel"
	grade.add_theme_font_size_override(&"font_size", 30)
	grade.add_theme_color_override(&"font_color", UIPalette.grade_color(clip.grade))
	grade.text = clip.grade
	row.add_child(grade)
	var length := Label.new()
	length.theme_type_variation = &"ValueLabel"
	length.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	length.text = HudStyle.format_duration(clip.duration)
	row.add_child(length)
	return chip


func _build_controls() -> void:
	for control: Array in CONTROLS:
		var key := KeyCap.new()
		key.action = control[0]
		key.menu = false
		key.size_flags_horizontal = Control.SIZE_SHRINK_END
		controls_grid.add_child(key)
		var label := Label.new()
		label.text = control[1]
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		controls_grid.add_child(label)


func _input(event: InputEvent) -> void:
	if UI.has_modal():
		return
	if event.is_action("pause_menu") and event.is_pressed() and not event.is_echo():
		if get_tree().paused and can_resume and menu_container.visible:
			accept_event()
			unpause_game()
		return
	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_F2:
		if get_tree().paused and can_resume:
			toggle_menu_visibility()
		return
	super(event)


## Back (Esc / B / stick gesture) on the pause menu resumes the flight.
func request_back() -> void:
	if can_resume and menu_container.visible:
		unpause_game()


func set_menu_visibility(show_menu: bool) -> void:
	visible = show_menu
	StickNavigation.suspended = not show_menu
	if visible:
		UI.show_mouse()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func toggle_menu_visibility() -> void:
	set_menu_visibility(not visible)


func _exit_tree() -> void:
	StickNavigation.suspended = false
	super()


func _on_resume_pressed() -> void:
	unpause_game()


func _open(packed: PackedScene) -> void:
	can_resume = false
	await open_submenu(packed, menu_container)
	can_resume = true


func _on_quad_settings_pressed() -> void:
	_open(packed_quad_settings_menu)


func _on_help_pressed() -> void:
	_open(packed_help_page)


func _on_options_pressed() -> void:
	_open(packed_options_menu)


func _on_restart_pressed() -> void:
	can_resume = false
	var confirmed: bool = await UI.confirm("MENU_RESTART_CONFIRM", "MENU_RESTART_STAGE", "UI_CANCEL", true)
	can_resume = true
	if confirmed:
		restart_requested.emit()


func _on_quit_pressed() -> void:
	can_resume = false
	var confirmed: bool = await UI.confirm("MENU_BACK_TO_MENU_CONFIRM", "MENU_BACK_TO_MENU", "UI_CANCEL", true)
	can_resume = true
	if confirmed:
		menu_requested.emit()


func unpause_game() -> void:
	set_menu_visibility(false)
	resumed.emit()
