## Identity of the menus (plan 03): the theme is built from the "rally at sunset" palette with
## all its variations and readable contrasts, main_theme.tres is regenerated, KeyCap draws the
## buttons of the device in use, the interface sounds exist, and the menus over the stage hide
## the viewfinder and blur the scene behind a single scrim.
extends HeadlessCheck


const STAGE_SCENE := preload("res://game/stage.tscn")
const HELP_PAGE := preload("res://gui/help_page.tscn")
const THEME_PATH := "res://gui/theme/main_theme.tres"
## Styleboxes whose background color must match between the saved theme and build().
const SAVED_STYLES := [["normal", "Button"], ["panel", "Card"], ["focus", "MenuItemButton"],
		["panel", "OverlayScrim"], ["normal", "PrimaryButton"]]


func run() -> void:
	_check_theme()
	_check_key_caps()
	_check_sounds()
	_check_components()
	await _check_help_page()
	await _check_stage_menus()
	Controls.force_playstation = -1
	UI.set_input_kind(UI.InputKind.KEYBOARD)
	GameSettings.reset_to_defaults()


func _check_theme() -> void:
	var built := ThemeBuilder.build()
	var missing: PackedStringArray = []
	for variation in ThemeBuilder.VARIATIONS:
		if built.get_type_variation_base(variation) == &"":
			missing.append(variation)
	expect(missing.is_empty(), "the theme has every variation (missing: %s)" % ", ".join(missing))
	expect(built.has_stylebox("focus", "RowPanel"), "the binding rows have their own styles (RowPanel)")

	var contrasts := [
		[UIPalette.TEXT, UIPalette.SURFACE, 7.0, "TEXT on SURFACE"],
		[UIPalette.TEXT_2, UIPalette.SURFACE, 4.5, "TEXT_2 on SURFACE"],
		[UIPalette.TEXT_ON_ACCENT, UIPalette.ACCENT, 4.5, "TEXT_ON_ACCENT on ACCENT"],
		[UIPalette.TEXT, UIPalette.BG, 7.0, "TEXT on BG"],
	]
	for pair: Array in contrasts:
		var ratio := UIPalette.contrast(pair[0], pair[1])
		note("contrast %s: %.1f" % [pair[3], ratio])
		expect(ratio >= pair[2], "%s contrast %.1f ≥ %.1f" % [pair[3], ratio, pair[2]])

	var saved := load(THEME_PATH) as Theme
	expect(saved != null, "main_theme.tres loads")
	if saved:
		for style: Array in SAVED_STYLES:
			var a := saved.get_stylebox(style[0], style[1]) as StyleBoxFlat
			var b := built.get_stylebox(style[0], style[1]) as StyleBoxFlat
			expect(a != null and b != null and a.bg_color.is_equal_approx(b.bg_color),
					"main_theme.tres is regenerated: %s/%s matches build()" % [style[1], style[0]])
		expect(saved.get_color("font_color", "Label").is_equal_approx(UIPalette.TEXT),
				"the saved theme uses the cream text of the palette")
	expect(ThemeDB.get_project_theme() != null and ThemeDB.get_project_theme().resource_path == THEME_PATH,
			"the project uses main_theme.tres")


func _check_key_caps() -> void:
	expect(KeyCap.shape_for(&"interact", true, true)["text"] == "□",
			"interact on a PlayStation pad is □ (%s)" % KeyCap.shape_for(&"interact", true, true)["text"])
	expect(KeyCap.shape_for(&"interact", true, false)["text"] == "X", "interact on an Xbox pad is X")
	expect(KeyCap.shape_for(&"interact", false, true)["kind"] == KeyCap.Kind.KEY, "interact on keyboard is a key")
	expect(KeyCap.shape_for(&"gimbal_up", true, true)["text"] == "R2", "a trigger is drawn as R2")

	# A KeyCap follows the device in use by itself.
	var cap := KeyCap.new()
	cap.action = &"ui_accept"
	add_child(cap)
	Controls.force_playstation = 1
	UI.set_input_kind(UI.InputKind.GAMEPAD)
	cap.refresh()
	expect(cap.get_text() == "✕" and cap.shape["kind"] == KeyCap.Kind.FACE,
			"ui_accept with a PlayStation pad is the ✕ button (%s)" % cap.get_text())
	# The player picks up the keyboard: the pad is no longer the last device used.
	Controls.using_gamepad = false
	Controls.input_device_changed.emit(false)
	UI.set_input_kind(UI.InputKind.KEYBOARD)
	expect(cap.get_text() == "Enter", "switching to the keyboard redraws it as Enter (%s)" % cap.get_text())
	expect(cap.get_combined_minimum_size().x > cap.cap_height, "a key is as wide as its text")
	cap.queue_free()


func _check_sounds() -> void:
	for sound: String in UI.SOUNDS:
		var stream := load(UI.SOUNDS[sound]) as AudioStream
		var length := stream.get_length() if stream else 0.0
		expect(length > 0.02 and length < 0.4, "the %s sound lasts 20–400 ms (%.3f s)" % [sound, length])


func _check_components() -> void:
	var parts := ConfirmOverlay.split_question("¿Reiniciar la etapa? Se pierden las tomas de esta pasada.")
	expect(parts[0] == "¿Reiniciar la etapa?" and parts[1] == "Se pierden las tomas de esta pasada.",
			"the confirm dialog shows the question as title and the rest as text (%s)" % parts)
	expect(ConfirmOverlay.split_question("¿Querés salir del juego?")[1].is_empty(), "a lone question is only a title")
	var logo := Logo.new()
	add_child(logo)
	expect(logo.get_combined_minimum_size().x > logo.logo_height * 1.5, "the wordmark is wider than tall")
	logo.queue_free()
	expect(UIPalette.grade_color("S") == UIPalette.GRADE_S and UIPalette.grade_color("C") == UIPalette.GRADE_C,
			"grades have their colors")


func _check_help_page() -> void:
	var help := HELP_PAGE.instantiate() as MenuScreen
	add_child(help)
	await process_frames(4)
	var caps: int = help.call(&"key_cap_count")
	note("help page: %d button glyphs" % caps)
	expect(caps >= 15, "the help page draws the controls as buttons (%d)" % caps)
	var scroll := help.get_node("%HelpScroll") as ScrollContainer
	UI.set_input_kind(UI.InputKind.GAMEPAD)
	help.grab_initial_focus(true)
	await process_frames(2)
	expect(get_viewport().gui_get_focus_owner() == scroll, "the help page opens focused on its text")
	await action(&"ui_down")
	await process_frames(2)
	expect(scroll.scroll_vertical > 0, "down scrolls the help page (%d)" % scroll.scroll_vertical)
	help.queue_free()
	await process_frames(2)


func _check_stage_menus() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(20)
	var ui_layer := stage.get_node("UI") as CanvasLayer
	var report := ShotReport.new()
	for i in 40:
		report.add_sample(0.9, 0.9, 0.9, 1.0, 0.9)
	report.duration = 4.0
	report.finalize()
	stage.clips.append(report)

	stage.open_pause_menu()
	await process_frames(10)
	var pause := stage.pause_menu
	expect(not ui_layer.visible, "the viewfinder and on-foot overlay hide behind the pause menu")
	expect(pause.material == Scrim.blur_material(), "the pause menu blurs the stage behind it")
	expect(pause.clip_chip_count() == 1, "the pause menu lists the clips delivered")
	expect(pause.controls_grid.find_children("*", "KeyCap", true, false).size() == PauseMenu.CONTROLS.size(),
			"the pause menu shows the main controls as buttons")
	pause._on_options_pressed()
	await process_frames(20)
	var options := find_child_with_script(pause, "res://gui/options_menu/options_menu.gd") as MenuScreen
	expect(options != null and options.material == null and not pause.menu_container.visible,
			"a sub screen adds no second scrim and hides the pause content")
	if options:
		options.request_back()
		await process_frames(20)
	GameSettings.set_menu_blur(false)
	await process_frames(2)
	expect(pause.material == null, "without blur the scrim is the plain dark color")
	GameSettings.set_menu_blur(true)

	pause.unpause_game()
	await process_frames(10)
	expect(ui_layer.visible, "resuming shows the viewfinder again")
	stage.show_results()
	await process_frames(10)
	expect(not ui_layer.visible, "the results hide the viewfinder")
	stage.queue_free()
	get_tree().paused = false
	await process_frames(2)
