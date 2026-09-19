## Front-end and flow (plan 04): the title leads to the main menu, the catalog of stages, a
## stage built in steps is the same stage as one built at once, progress is saved and unlocks
## the next stage, stage 2 can be driven, a stage started through SceneTransition ends up
## ready and unpaused (also when restarted and on the way back to the menu), and the results
## show a record and the next stage.
extends HeadlessCheck


const MAIN := preload("res://game/main.tscn")
const RESULTS := preload("res://ui/results_screen.tscn")
const STAGE_01 := "res://world/stages/stage_01.tscn"
const TRANSITION_TIMEOUT_MSEC := 20000


func run() -> void:
	Progress.reset()
	await _check_title_and_menu()
	_check_catalog()
	await _check_async_build()
	_check_progress()
	await _check_stage_two()
	await _check_transitions()
	await _check_results()
	Progress.reset()
	UI.set_input_kind(UI.InputKind.KEYBOARD)


func _check_title_and_menu() -> void:
	var main := MAIN.instantiate() as Main
	add_child(main)
	await process_frames(5)
	expect(is_instance_valid(main.title_screen) and main.title_screen.is_visible_in_tree(),
			"the game starts on the title screen")
	Controls.using_gamepad = false
	UI.set_input_kind(UI.InputKind.KEYBOARD)
	await action(&"ui_accept")
	await process_frames(10)
	expect(main.main_menu != null and main.main_menu.is_visible_in_tree(), "accept on the title opens the main menu")
	expect(focus_name() == "ButtonPlay", "the main menu focuses Play (got %s)" % focus_name())
	if main.main_menu:
		main.main_menu.button_stages.grab_focus()
		await action(&"ui_accept")
		await process_frames(20)
		var select := find_child_with_script(main, "res://gui/front/stage_select.gd") as StageSelect
		expect(select != null and select.cards.size() >= 2, "Stages lists the stages as cards")
		if select:
			expect(not select.cards[&"stage_01"].get_meta(&"locked"), "stage 1 is open from the start")
			expect(select.cards[&"stage_02"].get_meta(&"locked"), "stage 2 starts locked")
			expect(focus_name() == "Card_stage_01", "the card of the current stage has the focus (%s)" % focus_name())
	main.queue_free()
	await process_frames(2)


func _check_catalog() -> void:
	var catalog := StageCatalog.get_default()
	expect(catalog.stages.size() >= 2, "the catalog has at least two stages")
	for info in catalog.stages:
		var packed := load(info.scene) as PackedScene
		var node := packed.instantiate() if packed else null
		expect(node is StageWorld, "%s opens a stage world (%s)" % [info.id, info.scene])
		expect(info.road_points().size() >= 4, "%s has a road for the menus' map" % info.id)
		if node:
			node.free()
	expect(catalog.next_after(&"stage_01") == catalog.find(&"stage_02"), "stage 2 follows stage 1")
	expect(catalog.find_by_scene(STAGE_01).id == &"stage_01", "a stage opened on its own finds its entry")


## The same seed and road give the same stage whether it is built at once or in steps.
func _check_async_build() -> void:
	var packed := load(STAGE_01) as PackedScene
	var at_once := packed.instantiate() as StageWorld
	add_child(at_once)
	var in_steps := packed.instantiate() as StageWorld
	in_steps.defer_build()
	add_child(in_steps)
	expect(not in_steps.builder.is_built(), "a deferred world waits for build_ready()")
	var fractions: Array[float] = []
	var _discard := in_steps.builder.build_progress.connect(
			func(fraction: float, _label: String) -> void: fractions.append(fraction))
	var first_frame := Engine.get_process_frames()
	await in_steps.build_ready()
	var frames := Engine.get_process_frames() - first_frame
	note("built in steps over %d frames, %d progress reports" % [frames, fractions.size()])
	var monotonic := fractions.size() > 2 and is_zero_approx(fractions[0]) and is_equal_approx(fractions[-1], 1.0)
	for i in range(1, fractions.size()):
		monotonic = monotonic and fractions[i] >= fractions[i - 1]
	expect(monotonic, "the build progress goes from 0 to 1 without going back")
	expect(frames > 5, "the build is spread over several frames (%d)" % frames)
	var same_heights := true
	for point: Vector2 in [Vector2(0, 0), Vector2(-150, -95), Vector2(120, 210), Vector2(-300, 250), Vector2(33, -77)]:
		same_heights = same_heights and is_equal_approx(at_once.builder.get_height(point.x, point.y),
				in_steps.builder.get_height(point.x, point.y))
	expect(same_heights, "same heights")
	expect(at_once.builder.road_samples == in_steps.builder.road_samples, "same road")
	expect(at_once.builder.tree_positions == in_steps.builder.tree_positions, "same trees")
	expect(in_steps.is_ready and in_steps.car.profile != null, "the world in steps hands the road to the car")
	at_once.queue_free()
	in_steps.queue_free()
	await process_frames(2)


func _check_progress() -> void:
	Progress.reset()
	var catalog := StageCatalog.get_default()
	var stage_two := catalog.find(&"stage_02")
	expect(Progress.is_unlocked(&"stage_01") and not Progress.is_unlocked(&"stage_02"), "only stage 1 is open at first")
	var run_c := Progress.record_run(&"stage_01", _clips([0.3]))
	expect(run_c["new_record"] and run_c["first"] and run_c["unlocked"] == null and run_c["next"] == null,
			"a C clip is the first grade but does not unlock stage 2")
	var run_a := Progress.record_run(&"stage_01", _clips([0.3, 0.75]))
	expect(run_a["new_record"] and not run_a["first"] and run_a["best_grade"] == "A", "an A clip is a new record")
	expect(run_a["unlocked"] == stage_two and run_a["next"] == stage_two, "an A clip unlocks stage 2")
	var run_b := Progress.record_run(&"stage_01", _clips([0.55]))
	expect(not run_b["new_record"] and run_b["unlocked"] == null and run_b["next"] == stage_two,
			"a worse run is no record, and stage 2 stays open")
	Progress.data = SaveData.new()
	Progress.load_progress()
	var saved := Progress.stage_progress(&"stage_01")
	expect(saved != null and saved.best_grade == "A" and saved.runs == 3 and saved.clips_delivered == 4,
			"the progress is saved and loaded back")
	expect(saved != null and saved.last_clips.size() == 1 and saved.last_clips[0].grade == "B",
			"the clips of the last run are saved")
	expect(Progress.current_stage() == stage_two, "Play leads to the last unlocked stage")
	# A broken save starts from scratch instead of breaking the game.
	var file := FileAccess.open(Progress.save_path, FileAccess.WRITE)
	file.store_string("not a resource")
	file.close()
	Progress.load_progress()
	expect(Progress.best_grade(&"stage_01").is_empty(), "a broken save starts from scratch")
	Progress.reset()


## Stage 2 is drivable: road inside the terrain, never crossing itself, a sane speed profile,
## the player off the road and the car on the ground to the finish.
func _check_stage_two() -> void:
	var info := StageCatalog.get_default().find(&"stage_02")
	var world := (load(info.scene) as PackedScene).instantiate() as StageWorld
	add_child(world)
	var builder := world.builder
	var car := world.car
	var length := builder.get_road_length()
	note("stage 2: road %.0f m, %d trees, stage time %.0f s" % [length, builder.tree_positions.size(),
			car.expected_time_at(length)])
	expect(length > 1000.0 and length < 2500.0, "stage 2 road length %.0f m" % length)
	var limit := builder.size * 0.5 - builder.edge_falloff * 0.5
	var inside := true
	for sample in builder.road_samples:
		inside = inside and absf(sample.x) < limit and absf(sample.z) < limit
	expect(inside, "the road of stage 2 stays on the terrain")
	var closest := INF
	var samples := builder.road_samples
	for i in range(0, samples.size(), 3):
		for j in range(i + 30, samples.size(), 3):
			closest = minf(closest, Vector2(samples[i].x, samples[i].z).distance_to(Vector2(samples[j].x, samples[j].z)))
	expect(closest > builder.road_width * 3.0, "the road of stage 2 never runs into itself (%.0f m)" % closest)
	var profile := car.profile
	var worst_decel := 0.0
	var increasing := true
	for i in range(1, profile.speeds.size()):
		worst_decel = maxf(worst_decel, (profile.speeds[i - 1] ** 2 - profile.speeds[i] ** 2) / (2.0 * profile.step))
		increasing = increasing and profile.times[i] > profile.times[i - 1]
	expect(increasing and worst_decel <= car.brake + 0.01, "stage 2 speed profile is drivable")
	var spawn := world.get_player_spawn_transform().origin
	var spawn_local := builder.to_local(spawn)
	expect(builder.get_road_distance(spawn_local.x, spawn_local.z) > builder.road_width,
			"the player starts off the road")
	car.start()
	var worst_gap := 0.0
	for _i in 4:
		await physics_frames(50)
		worst_gap = maxf(worst_gap, absf(car.global_position.y - world.get_ground_height(car.global_position)))
	expect(worst_gap < 0.3, "the car stays on the road of stage 2 (%.2f m)" % worst_gap)
	car.distance = profile.length - 40.0
	for _i in 1500:
		await get_tree().physics_frame
		if car.has_finished:
			break
	expect(car.has_finished, "the car finishes stage 2")
	world.queue_free()
	await process_frames(2)


func _check_transitions() -> void:
	SceneTransition.host = self
	var info := StageCatalog.get_default().find(&"stage_02")
	SceneTransition.start_stage(info)
	await process_frames(30)
	var loading := SceneTransition.find_child("LoadingScreen", false, false) as LoadingScreen
	expect(loading != null and get_tree().paused, "the loading screen shows while the stage builds, game paused")
	var progress_seen := 0.0
	var start := Time.get_ticks_msec()
	while SceneTransition.busy and Time.get_ticks_msec() - start < TRANSITION_TIMEOUT_MSEC:
		if is_instance_valid(loading):
			progress_seen = maxf(progress_seen, loading.get_progress())
		await process_frames(1)
	var stage := SceneTransition.current as Stage
	expect(not SceneTransition.busy and stage != null and stage.is_stage_ready,
			"start_stage ends with the stage ready")
	expect(stage != null and stage.stage_id == &"stage_02" and stage.world.scene_file_path == info.scene,
			"the stage plays the world of its catalog entry")
	expect(not get_tree().paused, "the game is unpaused once the stage is ready")
	expect(progress_seen > 0.5, "the loading screen showed the build progress (%.2f)" % progress_seen)
	expect(stage != null and stage.stage_name.contains("Lomas"), "the stage knows its name (%s)" % stage.stage_name)

	SceneTransition.reload_stage()
	await _wait_transition()
	var reloaded := SceneTransition.current as Stage
	expect(reloaded != null and reloaded != stage and reloaded.is_stage_ready and not get_tree().paused,
			"reload_stage ends with a new stage, unpaused")

	# Pause > Back to menu: the main menu, not the title.
	if reloaded:
		reloaded.open_pause_menu()
		await process_frames(5)
		reloaded.pause_menu.menu_requested.emit()
		await process_frames(2)
		await _wait_transition()
	var main := SceneTransition.current as Main
	expect(main != null and main.main_menu != null and not get_tree().paused,
			"back to the menu opens the main menu, unpaused")
	if is_instance_valid(SceneTransition.current):
		SceneTransition.current.queue_free()
	SceneTransition.current = null
	SceneTransition.host = null
	await process_frames(2)


func _wait_transition() -> void:
	await process_frames(1)
	var start := Time.get_ticks_msec()
	while SceneTransition.busy and Time.get_ticks_msec() - start < TRANSITION_TIMEOUT_MSEC:
		await process_frames(1)


func _check_results() -> void:
	var screen := RESULTS.instantiate() as ResultsScreen
	add_child(screen)
	await process_frames(2)
	var stage_two := StageCatalog.get_default().find(&"stage_02")
	var clips: Array[ShotReport] = [_report(0.75)]
	screen.show_results("Auto 7", clips, {"new_record": true, "unlocked": stage_two, "next": stage_two})
	await process_frames(3)
	expect(screen.record_label.visible, "a record says so")
	expect(screen.unlocked_label.visible and screen.unlocked_label.text.contains(stage_two.display_name),
			"the stage unlocked is named (%s)" % screen.unlocked_label.text)
	expect(screen.button_next.visible and screen.initial_focus == screen.button_next,
			"Next stage is offered first")
	var chosen: Array[StageInfo] = []
	var _discard := screen.next_requested.connect(func(info: StageInfo) -> void: chosen.append(info))
	screen.button_next.pressed.emit()
	expect(chosen.size() == 1 and chosen[0] == stage_two, "Next stage asks for stage 2")
	var empty: Array[ShotReport] = []
	screen.show_results("Auto 7", empty)
	expect(not screen.record_label.visible and not screen.button_next.visible,
			"without a run there is no record and no next stage")
	screen.queue_free()
	await process_frames(2)


func _clips(scores: Array[float]) -> Array[ShotReport]:
	var clips: Array[ShotReport] = []
	for score in scores:
		clips.append(_report(score))
	return clips


## A clip whose every sample scores `score` (4 s long).
func _report(score: float) -> ShotReport:
	var report := ShotReport.new()
	for _i in 80:
		report.add_sample(score, score, score, 1.0, score)
	report.duration = 4.0
	report.finalize()
	return report
