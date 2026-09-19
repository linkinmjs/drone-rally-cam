## Viewfinder while piloting, laid out like a professional camera drone's screen. Fixed
## regions on a grid (HudStyle.MARGIN, COLUMN_W), so nothing overlaps with any HUD preset:
##
## - top left: REC or STBY, which camera is in view, flight mode and armed state (chip);
## - top center: stage status, the single message line (VisorMessages) and the radio;
## - top right: battery and the readouts column (the clip summary goes below it);
## - center: horizon, crosshair and, in the gimbal view, the rule of thirds;
## - bottom left: one assistance panel, the pilot guide or (recording) the score bars;
## - bottom center: the two sticks; bottom edge: the shortcuts line.
##
## The flight layer (horizon, readouts, chip, sticks, armed state) is HUD; this node places its
## parts and adds the camera operator's layer. It is also the live preview of the HUD settings
## (setup_preview).
class_name DroneVisor
extends Control


const BORDER := 5.0
## Bottom margin of the sticks and the assistance panel, above the shortcuts line.
const BOTTOM_ROW := 60.0
const HINT_BOTTOM := 16.0
const TOP_CENTER_W := 880.0
const ASSIST_H := 150.0
const REC_DOT := 16.0

var drone: Drone = null
var recorder: Recorder = null
var pilot: Node3D = null
var control: ControlState = null
var hud: HUD = null
var messages: VisorMessages = null
var car_marker: WorldMarker = null
var score_bars: ScoreBars = null
var pilot_guide: PilotGuide = null
var radio: RadioFeed = null
## True when this is the preview of the HUD settings (no drone): fake data.
var preview_mode := false
## Times the shortcuts line was rebuilt: it only changes with the device, the view or arming.
var hint_rebuilds := 0

var region_top_left: VBoxContainer
var region_top_center: VBoxContainer
var region_top_right: VBoxContainer
var region_assist: PanelContainer
var region_hint: Label

var _car: RallyCar = null
var _gimbal: Gimbal = null
var _pilot_camera: PilotCamera = null
var _battery_node: Battery = null
var _rec: Label
var _rec_dot: Control
var _view: Label
var _status_line: Label
var _radio_message: Label
var _radio_countdown: Label
var _battery_label: Label
var _battery_bar: ScoreBar
var _thirds: Control
var _show_thirds := true
var _border: Array[ColorRect] = []
var _blink_rec := 0.0
var _blink_battery := 0.0
var _hint_dirty := true
var _preview_time := 0.0


func _ready() -> void:
	# With offsets: created by code inside the preview's SubViewport, it has no size yet.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)

	_thirds = Control.new()
	_thirds.name = "Thirds"
	_thirds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_thirds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var _discard := _thirds.draw.connect(_draw_thirds)
	add_child(_thirds)
	for side in 4:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.visible = false
		add_child(rect)
		_border.append(rect)
	_layout_border()

	car_marker = WorldMarker.new()
	car_marker.color = Color(1.0, 0.45, 0.4)
	car_marker.offset = Vector3(0.0, 1.8, 0.0)
	car_marker.visible = false
	add_child(car_marker)

	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_bottom()

	_discard = resized.connect(_layout_border)
	_discard = GameSettings.hud_config_updated.connect(_apply_view)
	_discard = Controls.input_device_changed.connect(_mark_hint_dirty.unbind(1))
	_discard = UI.context_changed.connect(_mark_hint_dirty)
	_discard = visibility_changed.connect(_on_visibility_changed)
	_apply_view()


func _build_top_left() -> void:
	region_top_left = _region("RegionTopLeft")
	region_top_left.add_theme_constant_override("separation", 6)
	# The REC dot blinks through its alpha, so the block never moves.
	var rec_row := HBoxContainer.new()
	rec_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rec_row.add_theme_constant_override("separation", 10)
	_rec_dot = Control.new()
	_rec_dot.name = "RecDot"
	_rec_dot.custom_minimum_size = Vector2(REC_DOT, REC_DOT)
	_rec_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rec_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rec_dot.visible = false
	var _discard := _rec_dot.draw.connect(_draw_rec_dot)
	rec_row.add_child(_rec_dot)
	_rec = HudStyle.make_label("STBY", HudStyle.SIZE_L, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	rec_row.add_child(_rec)
	region_top_left.add_child(rec_row)
	_view = HudStyle.make_label("GIMBAL", HudStyle.SIZE_S, HudStyle.DIM)
	region_top_left.add_child(_view)
	hud.mode_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	region_top_left.add_child(hud.mode_badge)
	HudStyle.anchor(region_top_left, Control.PRESET_TOP_LEFT)


## Anchors every region again from its current minimum size: containers keep their size when
## their content shrinks (a preset hiding the readouts), which would leave empty space.
func _relayout() -> void:
	for region: Control in [region_top_left, region_top_center, region_top_right]:
		region.size = Vector2.ZERO
	HudStyle.anchor(region_top_left, Control.PRESET_TOP_LEFT)
	HudStyle.anchor(region_top_center, Control.PRESET_CENTER_TOP)
	HudStyle.anchor(region_top_right, Control.PRESET_TOP_RIGHT)
	region_hint.size = Vector2.ZERO
	_place(region_hint, Control.PRESET_CENTER_BOTTOM, 0.0, HINT_BOTTOM)


func _build_top_center() -> void:
	region_top_center = _region("RegionTopCenter")
	region_top_center.custom_minimum_size.x = TOP_CENTER_W
	region_top_center.add_theme_constant_override("separation", 4)
	_status_line = _center_label(HudStyle.SIZE_M, HudStyle.WHITE)
	region_top_center.add_child(_status_line)
	messages = VisorMessages.new()
	messages.name = "Messages"
	region_top_center.add_child(messages)
	_radio_message = _center_label(HudStyle.SIZE_S, HudStyle.AMBER)
	region_top_center.add_child(_radio_message)
	_radio_countdown = _center_label(HudStyle.SIZE_S, HudStyle.WHITE)
	region_top_center.add_child(_radio_countdown)
	HudStyle.anchor(region_top_center, Control.PRESET_CENTER_TOP)


func _build_top_right() -> void:
	region_top_right = _region("RegionTopRight")
	region_top_right.custom_minimum_size.x = HudStyle.COLUMN_W
	region_top_right.add_theme_constant_override("separation", 8)
	var battery_row := HBoxContainer.new()
	battery_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battery_row.alignment = BoxContainer.ALIGNMENT_END
	battery_row.add_theme_constant_override("separation", 12)
	_battery_label = HudStyle.make_label("", HudStyle.SIZE_M, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	battery_row.add_child(_battery_label)
	_battery_bar = ScoreBar.new()
	_battery_bar.custom_minimum_size = Vector2(72, 10)
	_battery_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	battery_row.add_child(_battery_bar)
	region_top_right.add_child(battery_row)
	hud.readouts.size_flags_horizontal = Control.SIZE_SHRINK_END
	region_top_right.add_child(hud.readouts)
	HudStyle.anchor(region_top_right, Control.PRESET_TOP_RIGHT)


func _build_bottom() -> void:
	region_assist = PanelContainer.new()
	region_assist.name = "RegionAssist"
	region_assist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_assist.add_theme_stylebox_override("panel", HudStyle.panel())
	region_assist.custom_minimum_size = Vector2(HudStyle.COLUMN_W, ASSIST_H)
	add_child(region_assist)
	var assist := VBoxContainer.new()
	assist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_assist.add_child(assist)
	pilot_guide = PilotGuide.new()
	assist.add_child(pilot_guide)
	score_bars = ScoreBars.new()
	score_bars.visible = false
	assist.add_child(score_bars)
	_place(region_assist, Control.PRESET_BOTTOM_LEFT, HudStyle.MARGIN, BOTTOM_ROW)

	hud.sticks.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hud.sticks)
	_place(hud.sticks, Control.PRESET_CENTER_BOTTOM, 0.0, BOTTOM_ROW)

	region_hint = HudStyle.make_label("", HudStyle.SIZE_S, HudStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	region_hint.name = "RegionHint"
	add_child(region_hint)
	_place(region_hint, Control.PRESET_CENTER_BOTTOM, 0.0, HINT_BOTTOM)


func _region(region_name: String) -> VBoxContainer:
	var region := VBoxContainer.new()
	region.name = region_name
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(region)
	return region


func _center_label(font_size: int, color: Color) -> Label:
	var label := HudStyle.make_label("", font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TOP_CENTER_W
	return label


## Anchors `control` with different horizontal and vertical margins.
func _place(control_node: Control, preset: Control.LayoutPreset, margin_x: float, margin_y: float) -> void:
	HudStyle.anchor(control_node, preset, 0.0)
	if control_node.anchor_left == 0.0:
		control_node.offset_left += margin_x
		control_node.offset_right += margin_x
	elif control_node.anchor_left == 1.0:
		control_node.offset_left -= margin_x
		control_node.offset_right -= margin_x
	if control_node.anchor_top == 1.0:
		control_node.offset_top -= margin_y
		control_node.offset_bottom -= margin_y
	elif control_node.anchor_top == 0.0:
		control_node.offset_top += margin_y
		control_node.offset_bottom += margin_y


func setup(new_drone: Drone, new_recorder: Recorder, new_pilot: Node3D,
		new_control: ControlState = null) -> void:
	drone = new_drone
	recorder = new_recorder
	pilot = new_pilot
	control = new_control
	_gimbal = drone.get_node_or_null("Gimbal") as Gimbal
	_pilot_camera = drone.get_node_or_null("PilotCamera") as PilotCamera
	_battery_node = drone.get_node_or_null("Battery") as Battery
	score_bars.recorder = recorder
	pilot_guide.setup(drone, recorder, control, hud.stick_left)

	var fc := drone.flight_controller
	var _discard := fc.armed.connect(hud.status._on_armed)
	_discard = fc.armed.connect(_mark_hint_dirty.unbind(1))
	_discard = fc.disarmed.connect(hud.status._on_disarmed)
	_discard = fc.disarmed.connect(_mark_hint_dirty)
	_discard = fc.flight_mode_changed.connect(hud.status._on_mode_changed)
	_discard = fc.flight_mode_changed.connect(hud.update_flight_mode)
	_discard = fc.arm_failed.connect(_on_arm_failed)
	_discard = hud.status.arm_refused.connect(_on_arm_refused)
	_discard = drone.respawned.connect(hud.reset_altitude)
	_discard = drone.deployed.connect(hud.reset_altitude)
	if fc.flight_mode:
		hud.update_flight_mode(fc.flight_mode)
	if control:
		_discard = control.view_changed.connect(func(_view: ControlState.View) -> void: _apply_view())
	_apply_view()


## The rally car, for its marker (car marker setting of the HUD).
func set_car(car: RallyCar) -> void:
	_car = car
	car_marker.target = car


## The stage radio: its announcements and countdown are drawn here while piloting.
func set_radio(feed: RadioFeed) -> void:
	radio = feed


## The stage status line ("Auto 7 larga en 0:37").
func set_status(text: String) -> void:
	_status_line.text = text


func is_pilot_view() -> bool:
	return control != null and control.view == ControlState.View.PILOT


func is_recording() -> bool:
	if preview_mode:
		return fmod(_preview_time, 8.0) > 4.0
	return recorder != null and recorder.recording


## The named regions of the layout, for the checks: {name: Control}.
func regions() -> Dictionary:
	return {
		"top_left": region_top_left,
		"top_center": region_top_center,
		"top_right": region_top_right,
		"assist": region_assist,
		"sticks": hud.sticks,
		"hint": region_hint,
	}


## Camera, horizon style and view-dependent parts for the current view and HUD settings.
func _apply_view() -> void:
	var pilot_view := is_pilot_view() and _pilot_camera != null
	var camera: Camera3D = null
	if pilot_view:
		camera = _pilot_camera
	elif _gimbal:
		camera = _gimbal.camera
	hud.set_camera(camera, pilot_view)
	hud.apply_hud_config()
	_show_thirds = bool(GameSettings.hud_config["thirds"]) and not pilot_view
	_view.text = "VISTA PILOTO · graba el gimbal" if pilot_view else "GIMBAL"
	score_bars.set_pilot_view(pilot_view)
	_thirds.queue_redraw()
	_mark_hint_dirty()
	_relayout.call_deferred()


func _on_arm_failed(reason: FlightController.ArmFail) -> void:
	var mode := drone.flight_controller.flight_mode
	hud.status.throttle_centered_to_arm = mode != null and mode.idle_power() > 0.0
	hud.status._on_arm_failed(reason)


func _on_arm_refused(text: String) -> void:
	messages.post(text, VisorMessages.Level.WARN, 2.5, &"arm")


func _on_visibility_changed() -> void:
	if visible:
		_mark_hint_dirty()
	else:
		# Whatever was said while flying is stale once the pilot lets go of the controller.
		messages.clear()
		pilot_guide.clear_target()


func _mark_hint_dirty() -> void:
	_hint_dirty = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_hint_dirty = true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if preview_mode:
		_update_preview(delta)
	elif drone:
		_feed_hud(delta)
		_update_car_marker()
		_update_radio()
		_update_battery(delta)
	else:
		return
	_update_rec(delta)
	_update_assist()
	if _hint_dirty:
		_rebuild_hint()


## Same data the simulator's drone sends to its HUD; the height is above the ground.
func _feed_hud(delta: float) -> void:
	var fc := drone.flight_controller
	var input := fc.input
	var pos := fc.pos
	var height := fc.flight_state.ground_distance
	hud.altitude_known = is_finite(height)
	if hud.altitude_known:
		pos.y = height
	hud.update_data(delta, pos, fc.angles, fc.lin_vel, Vector2(input.yaw, -2.0 * (input.power - 0.5)),
			Vector2(input.roll, input.pitch))
	hud.readouts.distance = drone.global_position.distance_to(pilot.global_position) if pilot else 0.0
	if _gimbal:
		hud.readouts.gimbal_deg = _gimbal.get_tilt_degrees()


func _update_car_marker() -> void:
	var enabled := _car != null and not _car.has_finished \
			and bool(GameSettings.hud_config["car_marker"])
	car_marker.visible = enabled
	if not enabled:
		return
	if _car.running:
		car_marker.text = "%s · %d m" % [_car.driver_name,
				roundi(_car.global_position.distance_to(drone.global_position))]
	else:
		car_marker.text = "%s · largada" % _car.driver_name


func _update_radio() -> void:
	var message := radio.message_text() if radio else ""
	_radio_message.text = message
	_radio_message.visible = not message.is_empty()
	if radio:
		_radio_message.modulate.a = radio.message_alpha()
	var countdown := radio.countdown_text() if radio else ""
	_radio_countdown.text = countdown
	_radio_countdown.visible = not countdown.is_empty()
	if radio and not countdown.is_empty():
		HudStyle.set_color(_radio_countdown, radio.countdown_color())


func _update_rec(delta: float) -> void:
	var recording := is_recording()
	if recording:
		_blink_rec = fmod(_blink_rec + delta, 1.0)
		var elapsed := recorder.elapsed if recorder else fmod(_preview_time, 4.0)
		var limit := recorder.max_clip_seconds if recorder else 30.0
		_rec.text = "REC %s / %s" % [HudStyle.format_time(elapsed), HudStyle.format_time(limit)]
		HudStyle.set_color(_rec, HudStyle.RED)
		_rec_dot.modulate.a = 1.0 if _blink_rec < 0.6 else 0.15
		var color := HudStyle.score_color(recorder.last_score if recorder else 0.8)
		color.a = 0.85
		for rect in _border:
			rect.color = color
	else:
		_rec.text = "STBY"
		HudStyle.set_color(_rec, HudStyle.WHITE)
	_rec_dot.visible = recording
	for rect in _border:
		rect.visible = recording
	_thirds.visible = _show_thirds


func _update_battery(delta: float) -> void:
	if not _battery_node:
		return
	var fraction := _battery_node.get_fraction()
	_battery_label.text = "BAT %3d %%  %s" % [roundi(fraction * 100.0),
			HudStyle.format_time(_battery_node.get_seconds_left())]
	_battery_bar.value = fraction
	var color := HudStyle.WHITE
	if _battery_node.is_low:
		_blink_battery = fmod(_blink_battery + delta, 0.8)
		color = HudStyle.RED if _blink_battery < 0.4 else HudStyle.WHITE
	elif fraction < 0.35:
		color = HudStyle.AMBER
	HudStyle.set_color(_battery_label, color)


## One assistance panel: the guide while flying, the score bars while recording.
func _update_assist() -> void:
	var config := GameSettings.hud_config
	var recording := is_recording()
	var show_bars := recording and bool(config["score_bars"])
	var show_guide := not recording and bool(config["pilot_guide"]) \
			and (preview_mode or pilot_guide.refresh())
	score_bars.visible = show_bars
	pilot_guide.visible = show_guide
	region_assist.visible = show_bars or show_guide
	if not show_guide:
		pilot_guide.clear_target()


func _rebuild_hint() -> void:
	_hint_dirty = false
	hint_rebuilds += 1
	var armed := drone != null and drone.flight_controller.state_armed
	var parts: PackedStringArray = []
	if not armed and not preview_mode:
		parts.append("%s armar" % InputHints.button("toggle_arm"))
	parts.append("%s modo" % InputHints.button("cycle_flight_modes"))
	parts.append("%s grabar" % InputHints.button("rec_toggle"))
	parts.append("%s gimbal" % InputHints.button("gimbal"))
	parts.append("%s vista %s" % [InputHints.button("change_camera"),
			"gimbal" if is_pilot_view() else "piloto"])
	parts.append("%s soltar control" % InputHints.button("pilot_toggle"))
	parts.append("%s al despegue" % InputHints.button("respawn"))
	region_hint.text = "   ".join(parts)
	_relayout.call_deferred()


## Turns this viewfinder into the live preview of the HUD settings: fake flight, REC every
## other few seconds, sample radio and guide.
func setup_preview() -> void:
	preview_mode = true
	hud.preview_mode = true
	hud.mode_badge.set_mode("HUD_MODE_STABILIZED")
	hud.status._on_armed(null)
	_status_line.text = "Auto 7 en carrera · 0:31"
	_radio_message.text = "RADIO · Auto 7 · km %s · 0:24" % HudStyle.decimal(0.6)
	_radio_countdown.text = "Llega a tu punto en 0:12"
	_battery_label.text = "BAT  76 %  2:14"
	_battery_bar.value = 0.76
	hud.readouts.distance = 42.0
	hud.readouts.gimbal_deg = -25.0
	pilot_guide.show_step("Encuadrá el camino y grabá %s cuando pase el auto" % InputHints.button("rec_toggle"))
	score_bars.show_preview()
	_apply_view()


func _update_preview(delta: float) -> void:
	_preview_time += delta


func _layout_border() -> void:
	if _border.size() < 4:
		return
	var area := size
	_border[0].position = Vector2.ZERO
	_border[0].size = Vector2(area.x, BORDER)
	_border[1].position = Vector2(0.0, area.y - BORDER)
	_border[1].size = Vector2(area.x, BORDER)
	_border[2].position = Vector2.ZERO
	_border[2].size = Vector2(BORDER, area.y)
	_border[3].position = Vector2(area.x - BORDER, 0.0)
	_border[3].size = Vector2(BORDER, area.y)


func _draw_rec_dot() -> void:
	var center := _rec_dot.size / 2.0
	_rec_dot.draw_circle(center, REC_DOT / 2.0, HudStyle.OUTLINE, true, -1.0, true)
	_rec_dot.draw_circle(center, REC_DOT / 2.0 - 2.0, HudStyle.RED, true, -1.0, true)


func _draw_thirds() -> void:
	var area := _thirds.size
	var color := Color(1, 1, 1, 0.18)
	for i: int in [1, 2]:
		var x := area.x * i / 3.0
		var y := area.y * i / 3.0
		_thirds.draw_line(Vector2(x, 0), Vector2(x, area.y), color, 1.0)
		_thirds.draw_line(Vector2(0, y), Vector2(area.x, y), color, 1.0)
