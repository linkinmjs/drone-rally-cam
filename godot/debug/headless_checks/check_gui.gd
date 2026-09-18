## Menus brought from drone-simulator: autoloads, translations and theme, and the pause flow
## on the real stage (pause, Options and every sub screen, confirm overlay, resume).
extends HeadlessCheck


const STAGE_SCENE := preload("res://game/stage.tscn")
const AUTOLOADS: Array[String] = ["Controls", "EventBus", "Audio", "GameSettings", "QuadSettings",
		"UI", "StickNavigation"]
const OPTION_SCREENS := {
	"ButtonGame": "res://gui/options_menu/game_settings_menu.gd",
	"ButtonAudio": "res://gui/options_menu/audio_menu.gd",
	"ButtonControls": "res://gui/options_menu/controls_menu/controls_menu.gd",
}
const PAUSE_SCREENS := {
	"ButtonQuad": "res://gui/quad_settings_menu.gd",
	"ButtonHelp": "res://gui/help_page.gd",
}


func run() -> void:
	var root := get_tree().root
	for autoload in AUTOLOADS:
		expect(root.has_node(autoload), "autoload %s should exist" % autoload)
	note("locale %s, MENU_RESUME = %s" % [TranslationServer.get_locale(), tr("MENU_RESUME")])
	expect(tr("MENU_RESUME") != "MENU_RESUME", "menu texts should be translated")
	expect(TranslationServer.get_locale().begins_with("es"), "the game runs in Spanish")
	expect(ThemeDB.get_project_theme() != null, "the project theme should be loaded")

	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(30)
	UI.set_input_kind(UI.InputKind.KEYBOARD)

	await action(&"pause_menu")
	await process_frames(10)
	expect(get_tree().paused, "pause_menu should pause the game")
	var pause := stage.pause_menu
	expect(pause != null and pause.is_visible_in_tree(), "the pause menu should be shown")
	if not pause:
		return
	expect(focus_name() == "ButtonResume", "the pause menu focuses Resume (got %s)" % focus_name())

	pause.button_options.grab_focus()
	await action(&"ui_accept")
	await process_frames(25)
	var options := find_child_with_script(pause, "res://gui/options_menu/options_menu.gd")
	expect(options != null and options.is_visible_in_tree(), "ui_accept on Options opens it")
	if options:
		for button_name: String in OPTION_SCREENS:
			await _open_and_close(pause, options, button_name, OPTION_SCREENS[button_name])
		await action(&"ui_cancel")
		await process_frames(25)
		expect(not is_instance_valid(options) or not options.is_inside_tree(), "ui_cancel closes Options")
		expect(focus_name() == "ButtonOptions", "focus returns to Options (got %s)" % focus_name())
	for button_name: String in PAUSE_SCREENS:
		await _open_and_close(pause, pause, button_name, PAUSE_SCREENS[button_name])

	# Restart asks first; cancelling keeps the pause menu.
	pause.button_restart.grab_focus()
	await action(&"ui_accept")
	await process_frames(10)
	expect(UI.has_modal(), "Restart asks for confirmation")
	await action(&"ui_cancel")
	await process_frames(20)
	expect(not UI.has_modal(), "ui_cancel closes the confirmation")
	expect(get_tree().paused and is_instance_valid(stage.pause_menu), "cancelling keeps the game paused")

	# Back on the pause menu resumes.
	await action(&"ui_cancel")
	await process_frames(6)
	expect(not get_tree().paused, "back on the pause menu resumes")
	expect(stage.pause_menu == null, "the pause menu is freed on resume")

	# Resuming waits until the button is released, so it cannot reach the drone.
	await action(&"pause_menu")
	await process_frames(10)
	pause = stage.pause_menu
	expect(pause != null, "the pause menu opens again")
	if not pause:
		return
	Input.action_press(&"ui_accept")
	pause.button_resume.pressed.emit()
	await process_frames(6)
	expect(get_tree().paused, "the game stays paused while the button is held")
	Input.action_release(&"ui_accept")
	await process_frames(4)
	expect(not get_tree().paused, "releasing the button resumes")


func _open_and_close(pause: Node, parent: Node, button_name: String, script_path: String) -> void:
	var button := parent.find_child(button_name, true, false) as Button
	expect(button != null, "%s should exist" % button_name)
	if not button:
		return
	button.grab_focus()
	await action(&"ui_accept")
	await process_frames(25)
	var screen := find_child_with_script(pause, script_path)
	expect(screen != null and screen.is_visible_in_tree(), "%s opens its screen" % button_name)
	expect(get_viewport().gui_get_focus_owner() != null, "%s screen has focus" % button_name)
	await action(&"ui_cancel")
	await process_frames(25)
	expect(not is_instance_valid(screen) or not screen.is_inside_tree(), "ui_cancel closes %s" % button_name)
	expect(focus_name() == button_name, "focus returns to %s (got %s)" % [button_name, focus_name()])
