## Viewfinder v2 (plan 02): the horizon follows the camera in view, the numbers are right
## (vertical speed, unknown height, turtle/launch), one message line with priorities, crash
## and lost clip in one message, no region overlaps with any preset, the shortcuts line is not
## rebuilt every frame and the settings preview is the real viewfinder, laid out at full size.
extends HeadlessCheck


const STAGE_SCENE := preload("res://game/stage.tscn")
const HUD_CONFIG := preload("res://gui/options_menu/hud_config.tscn")


func run() -> void:
	await _check_numbers()
	_check_status()
	await _check_message_queue()
	_check_guide_steps()
	_check_drawing_helpers()
	await _check_on_stage()
	await _check_settings_preview()
	GameSettings.reset_to_defaults()


## Vertical speed over the real window, reset after a jump, unknown height shown as "---".
func _check_numbers() -> void:
	var hud := HUD.new()
	add_child(hud)
	await process_frames(1)
	hud.set_process(false)
	hud.hud_timer = 0.1
	hud.update_data(0.1, Vector3(0, 5, 0), Vector3.ZERO, Vector3(3, 0, 4), Vector2.ZERO, Vector2.ZERO)
	hud.flush_numbers()
	expect(not hud.readouts.vertical_speed_known, "no vertical speed before a second sample")
	# A slow frame rate makes the window longer than the refresh interval: +3 m over 0.3 s.
	for _i in 3:
		hud.update_data(0.1, Vector3(0, 8, 0), Vector3.ZERO, Vector3(3, 0, 4), Vector2.ZERO, Vector2.ZERO)
	hud.flush_numbers()
	note("vertical speed %.2f m/s, speed %.1f km/h" % [hud.readouts.vertical_speed, hud.readouts.speed_kmh])
	expect(absf(hud.readouts.vertical_speed - 10.0) < 0.5, "+3 m over a 0.3 s window reads 10 m/s")
	expect(absf(hud.readouts.speed_kmh - 18.0) < 0.1, "speed is horizontal (5 m/s = 18 km/h)")
	hud.update_data(0.1, Vector3(0, 6, 0), Vector3.ZERO, Vector3(0, 8, 0), Vector2.ZERO, Vector2.ZERO)
	hud.flush_numbers()
	expect(hud.readouts.speed_kmh < 0.1, "climbing straight up does not show as speed")
	hud.reset_altitude()
	hud.update_data(0.1, Vector3(0, 40, 0), Vector3.ZERO, Vector3.ZERO, Vector2.ZERO, Vector2.ZERO)
	hud.flush_numbers()
	expect(not hud.readouts.vertical_speed_known, "after a jump (respawn) there is no vertical speed spike")
	hud.altitude_known = false
	hud.update_data(0.1, Vector3(0, 900, 0), Vector3.ZERO, Vector3.ZERO, Vector2.ZERO, Vector2.ZERO)
	hud.flush_numbers()
	var first_row: Array = hud.readouts._rows()[0]
	expect(first_row[1] == "---", "with no ground in range the height reads --- (got %s)" % first_row[1])
	hud.queue_free()


func _check_status() -> void:
	var status := HUDStatus.new()
	add_child(status)
	status._on_armed(FlightModeTurtle.new())
	expect(status.text == tr("HUD_STATUS_TURTLE"), "arming in turtle mode says so (%s)" % status.text)
	status._on_armed(FlightModeLaunch.new())
	expect(status.text == tr("HUD_STATUS_LAUNCH"), "arming in launch mode says so")
	var refused := [""]
	var _discard := status.arm_refused.connect(func(text: String) -> void: refused[0] = text)
	status.throttle_centered_to_arm = true
	status._on_arm_failed(FlightController.ArmFail.THROTTLE_HIGH)
	expect(refused[0] == tr("HUD_STATUS_THROTTLE_TO_CENTER") and not refused[0].contains("*"),
			"a refused arming is reported plainly (%s)" % refused[0])
	status.queue_free()


func _check_message_queue() -> void:
	var messages := VisorMessages.new()
	add_child(messages)
	messages.post("info", VisorMessages.Level.INFO, 1.0)
	messages.post("alert", VisorMessages.Level.ALERT, 0.2)
	expect(messages.current_text() == "alert", "an alert interrupts an info message")
	for _i in 30:
		messages._process(0.02)
	expect(messages.current_text() == "info", "the interrupted message comes back (%s)" % messages.current_text())
	messages.post("one", VisorMessages.Level.WARN, 1.0, &"battery")
	messages.post("two", VisorMessages.Level.WARN, 1.0, &"battery")
	expect(messages.current_text() == "two" and not messages._queue.any(
			func(m: Dictionary) -> bool: return m["text"] == "one"), "the same key replaces the message")
	for i in 6:
		messages.post("m%d" % i, VisorMessages.Level.INFO, 1.0)
	expect(messages._queue.size() <= VisorMessages.MAX_QUEUED, "the queue is bounded")
	messages.clear()
	expect(messages.current_text().is_empty(), "clear empties the line")
	messages.queue_free()
	await process_frames(1)


func _check_guide_steps() -> void:
	var fallen := PilotGuide.step_for({"armed": false, "height": 6.0})
	expect(String(fallen["text"]).begins_with("Dron caído"), "a disarmed drone in the air is a fallen drone")
	var landed_low := PilotGuide.step_for({"armed": true, "height": 0.1, "battery_low": true})
	expect(String(landed_low["text"]).contains("apagar los motores"),
			"low battery on the ground asks to stop the motors, not to land")
	expect(landed_low["stick"] == PilotGuide.Stick.DOWN, "…with the throttle down")


## Edge arrow label clear of its arrow, horizon kept out of the side columns, decimals and
## tips that fit the assistance panel.
func _check_drawing_helpers() -> void:
	var text_size := Vector2(160, 24)
	var edge := Vector2(900, 500)
	var clear := true
	for i in 8:
		var direction := Vector2.RIGHT.rotated(TAU * i / 8.0)
		var center := WorldMarker.label_center_for(edge, direction, text_size)
		var label := Rect2(center - text_size / 2.0, text_size)
		var side := Vector2(-direction.y, direction.x) * 12.0
		var arrow := Rect2(edge + direction * 18.0, Vector2.ZERO).expand(edge - direction * 6.0 + side) 				.expand(edge - direction * 6.0 - side)
		clear = clear and not label.intersects(arrow)
	expect(clear, "the label of an off-screen car marker never covers its arrow")

	var line := PackedVector2Array([Vector2(0, 10), Vector2(100, 10), Vector2(200, 10), Vector2(300, 10)])
	var clipped := HUDHorizon.clip_to_band(line, 50.0, 250.0)
	expect(clipped.size() == 4 and clipped[0].is_equal_approx(Vector2(50, 10))
			and clipped[3].is_equal_approx(Vector2(250, 10)),
			"the camera horizon is cut at the edges of the central band (%s)" % clipped)

	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("es")
	expect(HudStyle.decimal(0.7) == "0,7" and HudStyle.format_duration(12.44) == "12,4 s",
			"Spanish decimals use a comma (%s, %s)" % [HudStyle.decimal(0.7), HudStyle.format_duration(12.44)])
	TranslationServer.set_locale(locale)

	var bars := ScoreBars.new()
	add_child(bars)
	var fits := true
	for tip: String in ["Así, mantené", "Centrá el auto o usá los tercios", "El auto está cortado: centralo"]:
		bars._set_tip(tip)
		fits = fits and bars._tip.get_combined_minimum_size().x <= ScoreBars.TIP_WIDTH
	expect(fits, "every tip fits the assistance panel without widening it")
	bars.queue_free()


func _check_on_stage() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(30)
	var control := stage.control
	var visor := stage.visor
	var hud := visor.hud
	var gimbal := stage.drone.get_node("Gimbal") as Gimbal
	var spot := Transform3D(stage.player.global_basis, stage.player.global_position
			- stage.player.global_basis.z * 2.0)
	expect(control.deploy(spot), "the drone deploys")
	await physics_frames(20)
	expect(control.toggle_pilot(), "taking the controller works")
	await process_frames(4)
	var radio := stage.get_node("RadioController") as RadioController
	radio.set_physics_process(false)

	expect(not stage.hud.visible, "the on-foot overlay is hidden while piloting")
	expect(hud.horizon.camera == gimbal.camera and hud.horizon.mode == "camera",
			"gimbal view: real horizon of the gimbal camera")
	expect(stage.drone.respawned.is_connected(hud.reset_altitude), "a respawn resets the vertical speed")
	expect(visor.car_marker.visible and visor.car_marker.text.ends_with("largada"),
			"before the start the car marker shows the start line (%s)" % visor.car_marker.text)

	# Messages: routed to the viewfinder while piloting; crash + lost clip = one line.
	stage.recorder.start()
	EventBus.drone_crashed.emit(stage.drone, 9.0)
	await process_frames(2)
	note("crash message: %s" % visor.messages.current_text())
	expect(visor.messages.current_text() == "DRON ESTRELLADO · TOMA PERDIDA",
			"a crash that loses the clip is one message")
	expect(visor.messages.current_level() == VisorMessages.Level.ALERT, "…as an alert")
	visor.visible = false
	expect(visor.messages.current_text().is_empty(), "hiding the viewfinder clears its messages")
	visor.visible = true

	# The REC dot blinks without moving the block under it.
	stage.recorder.start()
	visor._blink_rec = 0.0
	await process_frames(2)
	var rec_rect := visor._rec.get_global_rect()
	var block_size := visor.region_top_left.size
	var dot_on := visor._rec_dot.modulate.a
	visor._blink_rec = 0.65
	await process_frames(2)
	expect(visor._rec_dot.modulate.a < dot_on, "the REC dot blinks")
	expect(visor._rec.get_global_rect() == rec_rect and visor.region_top_left.size == block_size,
			"the REC blink does not move the top left block (%s → %s)" % [rec_rect, visor._rec.get_global_rect()])
	stage.recorder.stop()
	await process_frames(2)

	# Pilot view while recording: the score still comes from the gimbal.
	await action(&"change_camera")
	await process_frames(3)
	expect(hud.horizon.camera == stage.drone.get_node("PilotCamera"), "pilot view: pilot camera horizon")
	stage.recorder.start()
	await process_frames(3)
	expect(visor._view.text.contains("graba el gimbal"), "the pilot view says the gimbal records")
	expect(visor.score_bars.get_title().contains("GIMBAL"), "the score bars say they measure the gimbal")
	expect(not visor._thirds.visible, "no rule of thirds over the pilot camera")
	stage.recorder.stop()
	await action(&"change_camera")
	await process_frames(3)

	# No overlaps: every preset, recording or not, with the clip summary on screen.
	var report := ShotReport.new()
	for i in 40:
		report.add_sample(0.7, 0.6, 0.8, 1.0, 0.7)
	report.duration = 2.0
	report.finalize()
	report.comment = "Un comentario bastante largo del productor para que el resumen ocupe dos o tres líneas en pantalla."
	var window := get_tree().root
	var saved_size := window.size
	for window_size: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1280, 720)]:
		window.size = window_size
		await process_frames(3)
		var screen := get_viewport().get_visible_rect()
		note("window %s: layout %s" % [window_size, screen.size])
		for preset in [GameSettings.HudPreset.CINE, GameSettings.HudPreset.PILOT, GameSettings.HudPreset.FULL]:
			GameSettings.apply_hud_preset(preset)
			for recording: bool in [false, true]:
				stage.summary.show_report(report)
				if recording:
					stage.recorder.start()
				await process_frames(4)
				_expect_no_overlap(visor, stage.summary, screen, "%s preset %d, recording %s"
						% [window_size, preset, recording])
				if recording:
					stage.recorder.stop()
					await process_frames(2)
	window.size = saved_size
	await process_frames(2)
	GameSettings.reset_to_defaults()

	# The shortcuts line is rebuilt on changes only.
	await process_frames(5)
	var rebuilds := visor.hint_rebuilds
	await process_frames(100)
	expect(visor.hint_rebuilds == rebuilds, "the shortcuts line is not rebuilt every frame (%d → %d)"
			% [rebuilds, visor.hint_rebuilds])
	stage.drone.flight_controller.input.power = 0.5
	stage.drone.flight_controller._on_arm_input()
	await process_frames(2)
	expect(visor.hint_rebuilds > rebuilds, "arming rebuilds the shortcuts line")
	stage.drone.flight_controller._on_disarm_input()

	# Walking: messages go to the on-foot overlay.
	expect(control.toggle_pilot(), "releasing the controller works")
	await process_frames(2)
	stage.notify("Aviso de prueba")
	expect(stage.hud.get("_notice").text == "Aviso de prueba", "walking, notices go to the on-foot overlay")
	stage.queue_free()
	await process_frames(2)


func _expect_no_overlap(visor: DroneVisor, summary: Control, screen: Rect2, label: String) -> void:
	var rects := {}
	var regions: Dictionary = visor.regions()
	for key: String in regions:
		var region: Control = regions[key]
		if region.is_visible_in_tree() and region.get_global_rect().has_area():
			rects[key] = region.get_global_rect()
	if summary and summary.is_visible_in_tree():
		rects["summary"] = summary.get_global_rect()
	var keys := rects.keys()
	for i in keys.size():
		var rect: Rect2 = rects[keys[i]]
		expect(screen.encloses(rect), "%s: %s fits on screen (%s)" % [label, keys[i], rect])
		for j in range(i + 1, keys.size()):
			var other: Rect2 = rects[keys[j]]
			expect(not rect.intersects(other), "%s: %s overlaps %s (%s / %s)" % [label, keys[i], keys[j],
					rect, other])


func _check_settings_preview() -> void:
	var config := HUD_CONFIG.instantiate()
	add_child(config)
	await process_frames(5)
	var visor: DroneVisor = config.get("visor")
	expect(visor != null and visor.preview_mode, "the HUD settings preview is the real viewfinder")
	if visor:
		var viewport := visor.get_viewport() as SubViewport
		expect(visor.size == Vector2(viewport.size), "the preview viewfinder fills its 1920×1080 view (%s)"
				% visor.size)
		_expect_no_overlap(visor, null, Rect2(Vector2.ZERO, viewport.size), "settings preview")
		expect(visor.pilot_guide.visible, "the preview shows the pilot guide")
		GameSettings.hud_config["pilot_guide"] = false
		GameSettings.hud_config_updated.emit()
		await process_frames(3)
		expect(not visor.pilot_guide.visible, "turning the guide off hides it in the preview")
		GameSettings.hud_config["thirds"] = false
		GameSettings.hud_config_updated.emit()
		await process_frames(3)
		expect(not visor._thirds.visible, "turning the thirds off hides them in the preview")
	config.queue_free()
	await process_frames(2)
