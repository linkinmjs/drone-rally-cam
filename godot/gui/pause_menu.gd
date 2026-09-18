# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: Restart stage and
# Quit instead of Return to main menu.
class_name PauseMenu
extends MenuScreen


signal resumed
signal restart_requested

var packed_quad_settings_menu := preload("res://gui/quad_settings_menu.tscn")
var packed_help_page := preload("res://gui/help_page.tscn")
var packed_options_menu := preload("res://gui/options_menu/options_menu.tscn")

var can_resume := true

@onready var button_resume := %ButtonResume as Button
@onready var button_quad := %ButtonQuad as Button
@onready var button_help := %ButtonHelp as Button
@onready var button_options := %ButtonOptions as Button
@onready var button_restart := %ButtonRestart as Button
@onready var button_quit := %ButtonQuit as Button
@onready var menu_container := %MenuColumn as Control


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
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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
	var confirmed: bool = await UI.confirm("MENU_QUIT_CONFIRM", "MENU_QUIT", "UI_CANCEL", true)
	can_resume = true
	if confirmed:
		get_tree().quit()


func unpause_game() -> void:
	set_menu_visibility(false)
	resumed.emit()
