## Renders a few views of the stage to PNG files, for looking at the game without playing it.
## Needs a GPU (not headless):
##   godot --path godot res://debug/tools/screenshot_tour.tscn -- --out=C:/some/folder
extends Node


const STAGE_SCENE := preload("res://game/stage.tscn")
const MAIN_SCENE := preload("res://game/main.tscn")
const LOADING_SCREEN := preload("res://gui/front/loading_screen.tscn")
## The tour reads and writes its settings here (menus save when closed), never in the
## player's user://config, and always shows the default settings.
const TOUR_CONFIG_DIR := "user://screenshot_tour"

var _out_dir := "user://screenshots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_isolate_settings()
	await _front_end()

	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await _frames(30)
	var world := stage.world
	var curve := world.builder.driving_curve

	# 1. What the player sees on arrival: the tablet with the briefing.
	await _capture("01_player_spawn")
	stage.tablet.close()

	# 2. Player on the roadside, looking at the road.
	var road_point := curve.sample_baked(300.0)
	var side := (curve.sample_baked(305.0) - road_point).cross(Vector3.UP).normalized()
	var stand := road_point + side * 16.0
	stand.y = world.get_ground_height(stand)
	stage.player.global_position = stand
	stage.player.look_at(Vector3(road_point.x, stand.y, road_point.z), Vector3.UP)
	await _frames(10)
	await _capture("02_player_roadside")

	# 3. Drone deployed next to the case, seen by the player.
	var spot: Variant = stage.player.find_deploy_spot()
	if not spot is Transform3D:
		spot = Transform3D(stage.player.global_basis, stage.player.global_position - stage.player.global_basis.z * 1.5)
	stage.control.deploy(spot)
	await _frames(30)
	var head := stage.player.get_node("Head") as Node3D
	head.rotation.x = deg_to_rad(-25.0)
	await _frames(5)
	await _capture("03_drone_deployed")

	# 4. Drone camera above the road while the car passes, recording.
	var camera_spot := _find_clear_spot(world, stage.player.global_position)
	camera_spot.y = world.get_ground_height(camera_spot) + 7.0
	# Take off from the ground below that spot in Stabilized and climb to it.
	stage.control.toggle_pilot()
	# Ignore real controllers plugged into this machine: the tour drives the sticks itself.
	var radio := stage.get_node("RadioController") as RadioController
	radio.set_physics_process(false)
	stage.drone.flight_controller.input = FlightCommand.new()
	stage.drone.flight_controller.input.power = 0.5
	var below := camera_spot
	below.y = world.get_ground_height(camera_spot)
	stage.drone.reset_to(Transform3D(Basis.looking_at(-side, Vector3.UP), below))
	for _i in 30:
		await get_tree().physics_frame
	var fc := stage.drone.flight_controller
	fc._on_arm_input()
	fc.set_tracking_target(camera_spot)
	for _i in 400:
		await get_tree().physics_frame
	var gimbal := stage.drone.get_node("Gimbal") as Gimbal
	gimbal.tilt = deg_to_rad(-25.0)
	stage.phase = Stage.Phase.RACING
	world.car.start()
	world.car.distance = 285.0
	stage.recorder.start()
	await _frames(40)
	await _capture("04_drone_view_car")

	# 4b. Same moment through the pilot camera, then the pause menu over it.
	stage.control.change_camera()
	await _frames(10)
	await _capture("04b_pilot_view")
	stage.open_pause_menu()
	# Shown as with a PlayStation pad (the player's): focus ring and the pad's buttons.
	Controls.force_playstation = 1
	Controls.using_gamepad = true
	Controls.input_device_changed.emit(true)
	UI.set_input_kind(UI.InputKind.GAMEPAD)
	await _frames(30)
	var pause := stage.pause_menu
	pause.grab_initial_focus(true)
	await _frames(5)
	await _capture("08_pause_menu")
	# Restart asks first; Confirm is one D-pad press away.
	pause.button_restart.grab_focus()
	pause._on_restart_pressed()
	await _frames(20)
	var overlay := _find_confirm_overlay()
	if overlay:
		overlay.get("_button_ok").grab_focus()
		await _frames(5)
		await _capture("08b_confirm_overlay")
		overlay.call("_close", false)
		await _frames(20)
	pause._on_options_pressed()
	await _frames(20)
	var options := _find_screen(pause, "res://gui/options_menu/options_menu.gd")
	options.grab_initial_focus(true)
	await _frames(10)
	await _capture("09c_options_hub")
	options._on_controls_pressed()
	await _frames(40)
	await _capture("09_options_controls")
	var controls := _find_screen(pause, "res://gui/options_menu/controls_menu/controls_menu.gd")
	controls.request_back()
	await _frames(30)
	options._on_audio_pressed()
	await _frames(40)
	await _capture("09b_options_audio")
	_find_screen(pause, "res://gui/options_menu/audio_menu.gd").request_back()
	await _frames(30)
	options._on_game_settings_pressed()
	await _frames(40)
	var game := _find_screen(pause, "res://gui/options_menu/game_settings_menu.gd")
	var tabs := game.find_child("TabContainer", true, false) as TabContainer
	if tabs:
		tabs.current_tab = tabs.get_tab_count() - 1
	await _frames(20)
	await _capture("10_options_hud")
	game.request_back()
	await _frames(30)
	options.request_back()
	await _frames(30)
	pause._on_quad_settings_pressed()
	await _frames(40)
	await _capture("11_drone_settings")
	_find_screen(pause, "res://gui/quad_settings_menu.gd").request_back()
	await _frames(30)
	pause._on_help_pressed()
	await _frames(40)
	await _capture("12_help")
	# The controls reference, drawn with the pad's buttons.
	var help := _find_screen(pause, "res://gui/help_page.gd")
	var help_scroll := help.get_node("%HelpScroll") as ScrollContainer
	help_scroll.scroll_vertical = int((help.get_node("%Sections") as Control).get_child(1).position.y)
	await _frames(5)
	await _capture("12b_help_keycaps")
	help.request_back()
	await _frames(30)
	pause.unpause_game()
	await _frames(5)
	stage.control.change_camera()
	# Deliver the clip: the producer's summary shows up on the side.
	stage.recorder.stop()
	await _frames(20)
	await _capture("04c_clip_summary")

	# 4d. Every HUD element on (preset Completo) while recording.
	stage.summary.hide()
	GameSettings.apply_hud_preset(GameSettings.HudPreset.FULL)
	stage.recorder.start()
	await _frames(20)
	await _capture("04d_visor_full")
	# 4e. A crash that loses the clip: one alert on the message line.
	EventBus.drone_crashed.emit(stage.drone, 9.0)
	await _frames(10)
	await _capture("04e_visor_alert")
	GameSettings.reset_to_defaults()
	await _frames(5)

	# 5. High wide shot of the stage.
	var camera := Camera3D.new()
	camera.far = 4000.0
	add_child(camera)
	camera.global_position = Vector3(-250.0, 160.0, 320.0)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.make_current()
	await _frames(20)
	await _capture("05_stage_overview")

	# 6. Close to the car in a corner, to see the drift and the road.
	world.car.distance = 520.0
	await _frames(3)
	var car_xform := world.car.global_transform
	camera.global_position = car_xform.origin + car_xform.basis.x * 9.0 + Vector3.UP * 2.5 - car_xform.basis.z * 8.0
	camera.look_at(car_xform.origin + Vector3.UP * 0.8, Vector3.UP)
	await _frames(2)
	await _capture("06_car_close")

	# 7. Road edge up close, to check how the road meets the terrain.
	var edge_point := curve.sample_baked(700.0)
	var edge_next := curve.sample_baked(705.0)
	var edge_side := (edge_next - edge_point).cross(Vector3.UP).normalized()
	var edge := edge_point + edge_side * 3.5
	camera.global_position = edge + edge_side * 1.5 + Vector3.UP * 1.2 - (edge_next - edge_point).normalized() * 3.0
	camera.look_at(edge + (edge_next - edge_point).normalized() * 4.0, Vector3.UP)
	await _frames(2)
	await _capture("07_road_edge")

	# 13. End of the stage.
	stage.show_results()
	await _frames(30)
	await _capture("13_results")

	# 14. A better run: new record, stage 2 unlocked, Next stage offered first.
	var stage_two := StageCatalog.get_default().find(&"stage_02")
	var good_run: Array[ShotReport] = [_report(0.78), _report(0.6)]
	stage.results.show_results(world.car.driver_name, good_run,
			{"new_record": true, "unlocked": stage_two, "next": stage_two})
	stage.results.grab_initial_focus(true)
	await _frames(10)
	await _capture("14_results_next")

	print("Screenshots saved to %s" % ProjectSettings.globalize_path(_out_dir))
	get_tree().quit(0)


## 0. Title over its live backdrop, main menu, stages (one graded, one locked) and the loading
## screen, as with the player's PlayStation pad.
func _front_end() -> void:
	var first_run: Array[ShotReport] = [_report(0.35)]
	var _run := Progress.record_run(&"stage_01", first_run)
	var main := MAIN_SCENE.instantiate() as Main
	add_child(main)
	await _frames(40)
	await _capture("00_title")
	Controls.force_playstation = 1
	Controls.using_gamepad = true
	Controls.input_device_changed.emit(true)
	UI.set_input_kind(UI.InputKind.GAMEPAD)
	main.show_menu()
	await _frames(30)
	main.main_menu.grab_initial_focus(true)
	await _frames(5)
	await _capture("00b_main_menu")
	main.main_menu.button_stages.pressed.emit()
	await _frames(30)
	await _capture("00c_stage_select")
	main.queue_free()
	await _frames(5)

	var layer := CanvasLayer.new()
	add_child(layer)
	var loading := LOADING_SCREEN.instantiate() as LoadingScreen
	layer.add_child(loading)
	loading.show_stage(StageCatalog.get_default().find(&"stage_02"))
	loading.set_progress(0.62, "LOADING_FOREST")
	await _frames(10)
	await _capture("00d_loading")
	layer.queue_free()

	# The real thing: stage 2 built in steps behind the loading screen, then its start.
	SceneTransition.host = self
	SceneTransition.start_stage(StageCatalog.get_default().find(&"stage_02"))
	await get_tree().process_frame
	while SceneTransition.busy:
		await get_tree().process_frame
	await _frames(30)
	await _capture("00e_stage_two")
	SceneTransition.current.queue_free()
	SceneTransition.current = null
	SceneTransition.host = null
	await _frames(5)

	# The stage part starts as a keyboard player with no progress, like before.
	Controls.force_playstation = -1
	Controls.using_gamepad = false
	Controls.input_device_changed.emit(false)
	UI.set_input_kind(UI.InputKind.KEYBOARD)
	Progress.reset()
	await _frames(5)


## A clip whose samples all score `score`.
func _report(score: float) -> ShotReport:
	var report := ShotReport.new()
	for _i in 80:
		report.add_sample(score, score, score, 1.0, score)
	report.duration = 4.0
	report.finalize()
	return report


func _isolate_settings() -> void:
	DirAccess.make_dir_recursive_absolute(TOUR_CONFIG_DIR)
	for file in DirAccess.get_files_at(TOUR_CONFIG_DIR):
		DirAccess.remove_absolute(TOUR_CONFIG_DIR.path_join(file))
	Controls.input_map_path = TOUR_CONFIG_DIR.path_join("InputMap.cfg")
	Audio.audio_settings_path = TOUR_CONFIG_DIR.path_join("Audio.cfg")
	GameSettings.game_settings_path = TOUR_CONFIG_DIR.path_join("GameSettings.cfg")
	QuadSettings.quad_settings_path = TOUR_CONFIG_DIR.path_join("Quad.cfg")
	Progress.save_path = TOUR_CONFIG_DIR.path_join("progress.tres")
	Progress.reset()
	InputMap.load_from_project_settings()
	GameSettings.reset_to_defaults()
	QuadSettings.reset_quad()
	QuadSettings.control_profile = ControlProfile.new()
	QuadSettings.settings_updated.emit()


func _find_confirm_overlay() -> ConfirmOverlay:
	for node in get_tree().root.find_children("*", "Control", true, false):
		if node is ConfirmOverlay:
			return node as ConfirmOverlay
	return null


func _find_screen(root: Node, script_path: String) -> MenuScreen:
	for child in root.get_children():
		var script := child.get_script() as Script
		if script and script.resource_path == script_path:
			return child as MenuScreen
		var found := _find_screen(child, script_path)
		if found:
			return found
	return null


## A flat point 12 m from the road, near `near`, with no tree within 7 m.
func _find_clear_spot(world: StageWorld, near: Vector3) -> Vector3:
	var curve := world.builder.driving_curve
	var best := near
	var best_distance := INF
	for step in range(0, int(curve.get_baked_length()), 10):
		var point := curve.sample_baked(step)
		var side := (curve.sample_baked(step + 5.0) - point).cross(Vector3.UP).normalized()
		for sign: float in [1.0, -1.0]:
			var candidate := point + side * 12.0 * sign
			# Flat ground only, like the case needs.
			var ground := world.get_ground_height(candidate)
			var clear := true
			for offset: Vector3 in [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]:
				if absf(world.get_ground_height(candidate + offset) - ground) > 0.3:
					clear = false
			for tree in world.builder.tree_positions:
				if Vector2(tree.x - candidate.x, tree.z - candidate.z).length() < 7.0:
					clear = false
					break
			var distance := candidate.distance_to(near)
			if clear and distance < best_distance:
				best = candidate
				best_distance = distance
	return best


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(file_name + ".png")
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save %s: %s" % [path, error_string(err)])
