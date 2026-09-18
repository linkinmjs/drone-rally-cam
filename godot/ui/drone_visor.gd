## Viewfinder while piloting. Underneath, the flight HUD from drone-simulator: sticks,
## horizon, height and speed, flight mode and armed state. On top, the camera operator's
## layer: REC and clip time, battery with time left, rule of thirds and, while recording, a
## thin border that turns from red to green as the shot improves.
## The gimbal view draws an attitude horizon (its image never leans with the drone); the
## pilot view draws the real horizon through its tilted camera.
class_name DroneVisor
extends Control


const HUD_SCENE := preload("res://hud/hud.tscn")
const BORDER := 5.0

var drone: Drone = null
var recorder: Recorder = null
var pilot: Node3D = null
var control: ControlState = null
var hud: HUD = null
var car_marker: WorldMarker = null
var score_bars: ScoreBars = null
var pilot_guide: PilotGuide = null
var _car: RallyCar = null

var _gimbal: Gimbal = null
var _pilot_camera: PilotCamera = null
var _battery_node: Battery = null
var _rec: Label
var _battery: Label
var _hint: Label
var _alert: Label
var _thirds: Control
var _show_thirds := true
var _border: Array[ColorRect] = []
var _alert_time := 0.0
var _blink := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	hud = HUD_SCENE.instantiate() as HUD
	add_child(hud)
	car_marker = WorldMarker.new()
	car_marker.color = Color(1.0, 0.45, 0.4)
	car_marker.offset = Vector3(0.0, 1.8, 0.0)
	car_marker.visible = false
	add_child(car_marker)

	_thirds = Control.new()
	_thirds.set_anchors_preset(Control.PRESET_FULL_RECT)
	_thirds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var _discard := _thirds.draw.connect(_draw_thirds)
	add_child(_thirds)

	for side in 4:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_border.append(rect)
	_layout_border()

	score_bars = ScoreBars.new()
	score_bars.visible = false
	add_child(score_bars)
	HudStyle.anchor(score_bars, Control.PRESET_BOTTOM_LEFT, 60.0)
	pilot_guide = PilotGuide.new()
	add_child(pilot_guide)
	HudStyle.anchor(pilot_guide, Control.PRESET_BOTTOM_LEFT, 60.0)

	_rec = HudStyle.make_label("STBY", 26)
	add_child(_rec)
	HudStyle.anchor(_rec, Control.PRESET_TOP_LEFT)
	_battery = HudStyle.make_label("", 26, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_battery)
	HudStyle.anchor(_battery, Control.PRESET_TOP_RIGHT)
	_hint = HudStyle.make_label("", 18, HudStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_hint)
	HudStyle.anchor(_hint, Control.PRESET_CENTER_BOTTOM, 20.0)
	_alert = HudStyle.make_label("", 40, HudStyle.RED, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_alert)
	HudStyle.anchor(_alert, Control.PRESET_CENTER_TOP, 240.0)

	_discard = resized.connect(_layout_border)
	_discard = GameSettings.hud_config_updated.connect(_apply_view)
	_discard = EventBus.drone_crashed.connect(func(_d: Drone, _s: float) -> void: show_alert("DRON ESTRELLADO"))
	_discard = EventBus.battery_low.connect(func() -> void: show_alert("BATERÍA BAJA"))
	_discard = EventBus.battery_depleted.connect(func() -> void: show_alert("SIN BATERÍA"))
	_discard = EventBus.recording_aborted.connect(func(_r: String) -> void: show_alert("TOMA PERDIDA"))


func setup(new_drone: Drone, new_recorder: Recorder, new_pilot: Node3D,
		new_control: ControlState = null) -> void:
	drone = new_drone
	recorder = new_recorder
	pilot = new_pilot
	control = new_control
	_gimbal = drone.get_node("Gimbal") as Gimbal
	_pilot_camera = drone.get_node_or_null("PilotCamera") as PilotCamera
	_battery_node = drone.get_node("Battery") as Battery
	score_bars.recorder = recorder
	pilot_guide.setup(drone, recorder, control)

	var fc := drone.flight_controller
	var _discard := fc.armed.connect(hud.status._on_armed)
	_discard = fc.disarmed.connect(hud.status._on_disarmed)
	_discard = fc.flight_mode_changed.connect(hud.status._on_mode_changed)
	_discard = fc.flight_mode_changed.connect(hud.update_flight_mode)
	_discard = fc.arm_failed.connect(_on_arm_failed)
	if fc.flight_mode:
		hud.update_flight_mode(fc.flight_mode)
	if control:
		_discard = control.view_changed.connect(func(_view: ControlState.View) -> void: _apply_view())
	_apply_view()


## The rally car, for its marker (shown with the car marker toggle of the HUD settings).
func set_car(car: RallyCar) -> void:
	_car = car
	car_marker.target = car


func is_pilot_view() -> bool:
	return control != null and control.view == ControlState.View.PILOT


## Camera, horizon style and optional rows for the current view and HUD settings.
func _apply_view() -> void:
	if not drone:
		return
	var pilot_view := is_pilot_view() and _pilot_camera != null
	hud.set_camera(_pilot_camera if pilot_view else _gimbal.camera)
	hud.forced_horizon_mode = "" if pilot_view else "attitude"
	hud.apply_hud_config()
	var config := GameSettings.hud_config
	hud.readouts.show_distance = bool(config["altitude"])
	hud.readouts.show_gimbal = bool(config["altitude"]) and not pilot_view
	# Recomputes the readouts' visibility with the extra rows.
	hud.show_component(HUD.Component.ALTITUDE, bool(config["altitude"]))
	_show_thirds = bool(config["thirds"]) and not pilot_view
	_thirds.queue_redraw()


func _on_arm_failed(reason: FlightController.ArmFail) -> void:
	var mode := drone.flight_controller.flight_mode
	hud.status.throttle_centered_to_arm = mode != null and mode.idle_power() > 0.0
	hud.status._on_arm_failed(reason)


func show_alert(text: String, seconds := 2.5) -> void:
	_alert.text = text
	_alert_time = seconds


func _process(delta: float) -> void:
	if not visible or not drone:
		return
	_blink = fmod(_blink + delta, 1.0)
	_alert_time -= delta
	_alert.visible = _alert_time > 0.0

	_feed_hud(delta)
	var recording := recorder != null and recorder.recording
	score_bars.visible = recording and bool(GameSettings.hud_config["score_bars"])
	pilot_guide.visible = not recording and bool(GameSettings.hud_config["pilot_guide"])
	_update_car_marker()
	_update_rec()
	_update_battery()
	_update_hint()


## Same data the simulator's drone sends to its HUD; the height is above the ground.
func _feed_hud(delta: float) -> void:
	var fc := drone.flight_controller
	var input := fc.input
	var pos := fc.pos
	var height := fc.flight_state.ground_distance
	if is_finite(height):
		pos.y = height
	var left_stick := Vector2(input.yaw, -2.0 * (input.power - 0.5))
	var right_stick := Vector2(input.roll, input.pitch)
	var rpm := [0.0, 0.0, 0.0, 0.0]
	for i in mini(fc.motors.size(), 4):
		rpm[i] = fc.motors[i].rpm
	hud.update_data(delta, pos, fc.angles, fc.lin_vel, left_stick, right_stick, rpm)
	hud.recording = recorder != null and recorder.recording
	hud.readouts.distance = drone.global_position.distance_to(pilot.global_position) if pilot else 0.0
	hud.readouts.gimbal_deg = _gimbal.get_tilt_degrees()


func _update_car_marker() -> void:
	car_marker.visible = _car != null and _car.running and bool(GameSettings.hud_config["car_marker"])
	if car_marker.visible:
		car_marker.text = "%s · %d m" % [_car.driver_name, roundi(_car.global_position.distance_to(
				drone.global_position))]


func _update_rec() -> void:
	var recording := recorder != null and recorder.recording
	if recording:
		var dot := "●" if _blink < 0.6 else " "
		_rec.text = "%s REC %s / %s" % [dot, HudStyle.format_time(recorder.elapsed),
				HudStyle.format_time(recorder.max_clip_seconds)]
		_rec.add_theme_color_override("font_color", HudStyle.RED)
		var color := HudStyle.score_color(recorder.last_score)
		color.a = 0.85
		for rect in _border:
			rect.color = color
	else:
		_rec.text = "STBY" if not is_pilot_view() else "STBY · VISTA PILOTO"
		_rec.add_theme_color_override("font_color", HudStyle.WHITE)
	for rect in _border:
		rect.visible = recording
	_thirds.visible = _show_thirds


func _update_battery() -> void:
	var fraction := _battery_node.get_fraction()
	_battery.text = "BAT %3d%%  %s" % [roundi(fraction * 100.0),
			HudStyle.format_time(_battery_node.get_seconds_left())]
	var color := HudStyle.WHITE
	if _battery_node.is_low:
		color = HudStyle.RED if _blink < 0.5 else HudStyle.WHITE
	elif fraction < 0.35:
		color = HudStyle.AMBER
	_battery.add_theme_color_override("font_color", color)


func _update_hint() -> void:
	var fc := drone.flight_controller
	var parts: PackedStringArray = []
	if not fc.state_armed:
		parts.append("%s armar" % InputHints.button("toggle_arm"))
	parts.append("%s modo" % InputHints.button("cycle_flight_modes"))
	parts.append("%s grabar" % InputHints.button("rec_toggle"))
	parts.append("%s gimbal" % InputHints.button("gimbal"))
	parts.append("%s vista %s" % [InputHints.button("change_camera"),
			"gimbal" if is_pilot_view() else "piloto"])
	parts.append("%s soltar control" % InputHints.button("pilot_toggle"))
	parts.append("%s al despegue" % InputHints.button("respawn"))
	_hint.text = "  ".join(parts)


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


func _draw_thirds() -> void:
	var area := _thirds.size
	var color := Color(1, 1, 1, 0.18)
	for i: int in [1, 2]:
		var x := area.x * i / 3.0
		var y := area.y * i / 3.0
		_thirds.draw_line(Vector2(x, 0), Vector2(x, area.y), color, 1.0)
		_thirds.draw_line(Vector2(0, y), Vector2(area.x, y), color, 1.0)
