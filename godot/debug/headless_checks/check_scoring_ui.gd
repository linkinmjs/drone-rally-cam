## Scoring made readable: live tips, the reasons behind each aspect of a clip, the pilot
## guide's steps, and the results at the end of the stage.
extends HeadlessCheck


const CLIP_SUMMARY := preload("res://ui/clip_summary.tscn")
const RESULTS := preload("res://ui/results_screen.tscn")
const STAGE_SCENE := preload("res://game/stage.tscn")


func run() -> void:
	_check_tips()
	_check_reasons()
	await _check_clip_summary()
	_check_pilot_guide()
	await _check_results_screen()
	await _check_results_after_the_finish()


func _check_tips() -> void:
	var cases := [
		[[0.0, false, 0.0, 0.0, 1.0, 0.0], "Buscá al auto"],
		[[0.05, false, 0.9, 1.0, 1.0, 0.2], "Algo tapa al auto"],
		[[0.4, true, 0.8, 0.2, 1.0, 1.0], "El auto está cortado: alejate"],
		[[0.003, false, 0.9, 0.3, 1.0, 1.0], "Acercate: el auto se ve chico"],
		[[0.05, false, 0.2, 1.0, 1.0, 1.0], "Centrá el auto o usá los tercios"],
		[[0.05, false, 0.9, 1.0, 0.3, 1.0], "Quieto: movimientos suaves"],
		[[0.05, false, 0.9, 1.0, 0.9, 1.0], "Así, mantené"],
	]
	for case: Array in cases:
		var args: Array = case[0]
		var tip := ShotAdvice.tip(args[0], args[1], args[2], args[3], args[4], args[5])
		expect(tip == case[1], "tip for %s should be '%s', got '%s'" % [args, case[1], tip])


func _make_report(values: Array, samples := 60) -> ShotReport:
	var report := ShotReport.new()
	for i in samples:
		report.add_sample(values[0], values[1], values[2], values[3], values[4])
	report.duration = samples * report.sample_interval
	report.finalize()
	return report


func _check_reasons() -> void:
	var good := _make_report([0.9, 0.9, 0.9, 1.0, 0.9])
	expect(good.aspect_reason("framing") == "centrado o en los tercios", "good framing reason")
	expect(good.aspect_reason("stability") == "imagen quieta", "good stability reason")
	var shaky := _make_report([0.3, 0.0, 0.2, 0.3, 0.2])
	expect(shaky.aspect_reason("framing") == "lejos del centro y de los tercios", "poor framing reason")
	expect(shaky.aspect_reason("size") == "fuera de cuadro buena parte", "off-screen size reason")
	expect(shaky.aspect_reason("stability") == "la cámara se mueve mucho", "shaky reason")
	expect(shaky.aspect_reason("visibility") == "tapado o fuera de cuadro", "hidden reason")
	note("good clip %s (%.2f), poor clip %s (%.2f)" % [good.grade, good.mean_score, shaky.grade, shaky.mean_score])
	expect(good.grade == "S" and shaky.grade == "C", "grades follow the thresholds")


func _check_clip_summary() -> void:
	var summary := CLIP_SUMMARY.instantiate() as ClipSummary
	add_child(summary)
	await process_frames(1)
	summary.show_report(_make_report([0.8, 0.6, 0.4, 1.0, 0.65]))
	var line := summary.aspect_line("framing")
	note("summary: %s | %s" % [line, summary.aspect_line("stability")])
	expect(line == "Encuadre 80 % centrado o en los tercios", "the summary gives value and reason (%s)" % line)
	expect(summary.aspect_line("stability").ends_with("la cámara se mueve mucho"), "stability reason shown")
	expect(ClipSummary.rules_text().begins_with("S: promedio ≥ 85 %"), "the rules come from the thresholds")
	summary.queue_free()


func _check_pilot_guide() -> void:
	var states := [
		[{"armed": false, "throttle_idle": false, "idle_centred": true}, "al centro", PilotGuide.Stick.CENTRE],
		[{"armed": false, "throttle_idle": false, "idle_centred": false}, "abajo", PilotGuide.Stick.DOWN],
		[{"armed": false, "throttle_idle": true, "idle_centred": true}, "para armar", PilotGuide.Stick.CENTRE],
		[{"armed": true, "height": 0.05}, "despegar", PilotGuide.Stick.UP],
		[{"armed": true, "height": 8.0, "pilot_view": true}, "gimbal", PilotGuide.Stick.NONE],
		[{"armed": true, "height": 8.0}, "grabá", PilotGuide.Stick.NONE],
		[{"armed": true, "height": 8.0, "battery_low": true}, "aterrizá", PilotGuide.Stick.DOWN],
		[{"armed": true, "height": 8.0, "recording": true}, "", PilotGuide.Stick.NONE],
	]
	for case: Array in states:
		var step := PilotGuide.step_for(case[0])
		var text: String = step["text"]
		var matches: bool = text.is_empty() if (case[1] as String).is_empty() else text.contains(case[1])
		expect(matches and step["stick"] == case[2], "guide for %s: '%s' / %d" % [case[0], text, step["stick"]])


func _check_results_screen() -> void:
	var screen := RESULTS.instantiate() as ResultsScreen
	add_child(screen)
	await process_frames(2)
	var clips: Array[ShotReport] = [_make_report([0.9, 0.9, 0.9, 1.0, 0.9]),
			_make_report([0.5, 0.6, 0.5, 1.0, 0.55])]
	screen.show_results("Auto 7", clips)
	await process_frames(2)
	note("results: %s · %s" % [screen.title.text, screen.subtitle.text])
	expect(screen.clip_count() == 2, "the results list both clips (%d)" % screen.clip_count())
	expect(screen.subtitle.text.contains("mejor nota: S"), "the results show the best grade")
	var restarted := [false]
	var _discard := screen.restart_requested.connect(func() -> void: restarted[0] = true)
	await action(&"restart_stage")
	expect(restarted[0], "Enter restarts from the results")
	screen.queue_free()
	await process_frames(2)


func _check_results_after_the_finish() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(20)
	stage._countdown = 0.0
	await physics_frames(3)
	var car := stage.world.car
	car.distance = car.get_route_length() - 4.0
	while not car.has_finished:
		await get_tree().physics_frame
	expect(stage.phase == Stage.Phase.FINISHED, "the stage ends when the car finishes")
	for _i in roundi((Stage.RESULTS_DELAY + 0.5) * 100.0):
		await get_tree().process_frame
	expect(stage.results != null and get_tree().paused, "the results show and pause the game")
	if stage.results:
		expect(stage.results.clip_count() == 0, "no clips were delivered")
	get_tree().paused = false
