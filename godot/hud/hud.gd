# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: draws for any Camera3D (pilot or
# gimbal), no race track or gate marker, the game's HUD settings keys.
extends Control
class_name HUD
## In-flight OSD. Orientation aids (horizon, compass, side tapes, next gate) follow the camera
## every frame; numeric values refresh at the "numbers rate" of the HUD settings so they stay
## readable. The data pipeline (`update_data`) and `show_component` are unchanged.


enum Component {CROSSHAIR, STATUS, HEADING, SPEED, ALTITUDE, LADDER, HORIZON, STICKS, RPM,
		FLIGHT_MODE, REC, SIDE_TAPES}

## HUD settings keys handled here (the rest of `GameSettings.hud_config` belongs to the viewfinder).
const OWN_KEYS: Array[String] = ["crosshair", "horizon", "ladder", "speed", "altitude", "heading",
		"sticks", "rpm", "flight_mode", "status", "side_tapes"]

# HUD components
@onready var crosshair := %Crosshair as HUDCrosshair
@onready var horizon := %HUDHorizon as HUDHorizon
@onready var side_tapes := %HUDSideTapes as HUDSideTapes
@onready var compass := %HUDCompass as HUDCompassTape
@onready var readouts := %HUDReadouts as HUDReadouts
@onready var mode_badge := %HUDModeBadge as HUDModeBadge
@onready var rec_indicator := %HUDRec as HUDRecIndicator
@onready var sticks := %HUDSticks as Control
@onready var stick_left := %HUDStickLeft as HUDStickInput
@onready var stick_right := %HUDStickRight as HUDStickInput
@onready var rpm_table := %HUDRPM as HUDRPM
@onready var status := %HUDStatus as HUDStatus

## True when the HUD is shown as a preview in the settings (no drone around it)
var preview_mode := false
## Whether the drone is recording (the REC indicator of this HUD is off in the game: the
## viewfinder shows its own with the clip time).
var recording := false
## When true the horizon mode follows `forced_horizon_mode` instead of the settings (the
## gimbal view always uses the attitude horizon: its camera never tilts with the drone).
var forced_horizon_mode := ""

# Flight data, averaged over the numbers refresh period
var hud_timer := 0.1
var hud_delta := 0.0
var hud_position := Vector3.ZERO
var hud_angles := Vector3.ZERO
var hud_velocity := Vector3.ZERO
var hud_left_stick := Vector2.ZERO
var hud_right_stick := Vector2.ZERO
var hud_rpm := [0.0, 0.0, 0.0, 0.0]
var is_first := false
var first_angles := Vector3.ZERO

# Latest raw values, used every frame by the orientation aids
var latest_position := Vector3.ZERO
var latest_angles := Vector3.ZERO
var latest_velocity := Vector3.ZERO
var latest_left_stick := Vector2.ZERO
var latest_right_stick := Vector2.ZERO
var _previous_altitude := 0.0
var _camera: Camera3D = null
var _show_rec := false
var _preview_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_data()
	update_data(hud_delta, hud_position, hud_angles, hud_velocity, hud_left_stick, hud_right_stick, hud_rpm)
	var _discard := GameSettings.hud_config_updated.connect(apply_hud_config)
	apply_hud_config()


## The camera the HUD draws the horizon and heading for.
func set_camera(camera: Camera3D) -> void:
	_camera = camera
	horizon.camera = camera


func apply_hud_config() -> void:
	var config := GameSettings.hud_config
	hud_timer = 1.0 / float(config["fps"])
	horizon.mode = forced_horizon_mode if not forced_horizon_mode.is_empty() \
			else str(config["horizon_mode"])
	for key: String in OWN_KEYS:
		show_component(_component_for_key(key), bool(config[key]))
	show_component(Component.REC, preview_mode)


func _component_for_key(key: String) -> Component:
	match key:
		"crosshair": return Component.CROSSHAIR
		"horizon": return Component.HORIZON
		"ladder": return Component.LADDER
		"speed": return Component.SPEED
		"altitude": return Component.ALTITUDE
		"heading": return Component.HEADING
		"sticks": return Component.STICKS
		"rpm": return Component.RPM
		"flight_mode": return Component.FLIGHT_MODE
		"status": return Component.STATUS
		"rec": return Component.REC
		_: return Component.SIDE_TAPES


func _process(delta: float) -> void:
	if preview_mode:
		_update_preview(delta)
	_update_orientation()
	if hud_delta >= hud_timer:
		hud_position /= hud_delta
		hud_angles /= hud_delta
		hud_velocity /= hud_delta
		hud_left_stick /= hud_delta
		hud_right_stick /= hud_delta
		for i in hud_rpm.size():
			hud_rpm[i] /= hud_delta
		update_display()
		reset_data()


func show_component(component: int, show_comp: bool = true) -> void:
	match component:
		Component.CROSSHAIR:
			crosshair.visible = show_comp
		Component.STATUS:
			status.visible = show_comp
		Component.HEADING:
			compass.visible = show_comp
		Component.SPEED:
			readouts.show_speed = show_comp
			readouts.queue_redraw()
		Component.ALTITUDE:
			readouts.show_altitude = show_comp
			readouts.queue_redraw()
		Component.LADDER:
			horizon.show_ladder = show_comp
			horizon.queue_redraw()
		Component.HORIZON:
			horizon.show_horizon = show_comp
			horizon.queue_redraw()
		Component.STICKS:
			sticks.visible = show_comp
		Component.RPM:
			rpm_table.visible = show_comp
		Component.FLIGHT_MODE:
			mode_badge.visible = show_comp
		Component.REC:
			_show_rec = show_comp
		Component.SIDE_TAPES:
			side_tapes.visible = show_comp
	readouts.visible = readouts.show_speed or readouts.show_altitude \
			or readouts.show_distance or readouts.show_gimbal


## Orientation aids: every frame, from the latest values and the camera transform.
func _update_orientation() -> void:
	if not is_visible_in_tree():
		return
	var heading := -rad_to_deg(latest_angles.y)
	if is_instance_valid(_camera):
		var forward := -_camera.global_transform.basis.z
		var flat := Vector2(forward.x, -forward.z)
		if flat.length() > 0.08:
			heading = rad_to_deg(atan2(flat.x, flat.y))
	compass.heading = fposmod(heading, 360.0)
	compass.queue_redraw()

	horizon.pitch = latest_angles.x
	horizon.roll = latest_angles.z
	horizon.queue_redraw()

	side_tapes.speed = latest_velocity.length()
	side_tapes.altitude = latest_position.y
	side_tapes.queue_redraw()

	stick_left.update_stick_input(latest_left_stick)
	stick_right.update_stick_input(latest_right_stick)

	rec_indicator.recording = _show_rec and (preview_mode or recording)


func update_display() -> void:
	readouts.speed_kmh = hud_velocity.length() * 3.6
	readouts.altitude = hud_position.y
	if hud_delta > 0.0:
		readouts.vertical_speed = (hud_position.y - _previous_altitude) / maxf(hud_timer, 1e-3)
	_previous_altitude = hud_position.y
	readouts.queue_redraw()
	rpm_table.update_rpm(hud_rpm[0], hud_rpm[1], hud_rpm[2], hud_rpm[3])


func update_data(dt: float, pos: Vector3, angles: Vector3, velocity: Vector3,
		left_stick: Vector2, right_stick: Vector2, rpm: Array) -> void:
	latest_position = pos
	latest_angles = angles
	latest_velocity = velocity
	latest_left_stick = left_stick
	latest_right_stick = right_stick
	hud_delta += dt
	hud_position += dt * pos
	if is_first:
		first_angles = angles
		is_first = false
	# Adjust angles to prevent averaging issues
	hud_angles += dt * get_adjusted_angles(angles)
	hud_velocity += dt * velocity
	hud_left_stick += dt * left_stick
	hud_right_stick += dt * right_stick
	for i in hud_rpm.size():
		hud_rpm[i] += dt * rpm[i]


func update_flight_mode(mode: FlightMode) -> void:
	var key := "HUD_MODE_ACRO"
	var blink := false
	if mode is FlightModeHorizon:
		key = "HUD_MODE_HORIZON"
	elif mode is FlightModeSpeed:
		key = "HUD_MODE_SPEED"
	elif mode is FlightModeTrack:
		key = "HUD_MODE_STABILIZED"
	elif mode is FlightModeTurtle:
		key = "HUD_MODE_TURTLE"
	elif mode is FlightModeLaunch:
		key = "HUD_MODE_LAUNCH"
	elif mode is FlightModeRecover:
		key = "HUD_MODE_RECOVER"
		blink = true
	mode_badge.set_mode(key, blink)


func reset_data() -> void:
	is_first = true
	first_angles = Vector3.ZERO
	hud_delta = 0.0
	hud_position = Vector3.ZERO
	hud_angles = Vector3.ZERO
	hud_velocity = Vector3.ZERO
	hud_left_stick = Vector2.ZERO
	hud_right_stick = Vector2.ZERO
	hud_rpm = [0.0, 0.0, 0.0, 0.0]


func get_adjusted_angles(angles: Vector3) -> Vector3:
	var result := angles
	var correction := 0

	for i in 3:
		# Check sign changes by difference with PI as arbitrary threshold
		if absf(angles[i] - first_angles[i]) > PI:
			if first_angles[i] > 0:
				correction = 1
			else:
				correction = -1
			result[i] = angles[i] + 2 * PI * correction
	return result


## Settings preview: gentle fake flight so every component can be seen.
func _update_preview(delta: float) -> void:
	_preview_time += delta
	var t := _preview_time
	var pos := Vector3(0, 12.0 + sin(t * 0.4) * 3.0, 0)
	var angles := Vector3(deg_to_rad(4.0 * sin(t * 0.5)), deg_to_rad(-25.0 - t * 8.0),
			deg_to_rad(10.0 * sin(t * 0.3)))
	var velocity := Vector3(0, cos(t * 0.4) * 1.2, -11.5 - sin(t * 0.7) * 2.0)
	var left := Vector2(sin(t * 0.6) * 0.3, -0.1)
	var right := Vector2(sin(t * 0.3) * 0.4, cos(t * 0.5) * 0.3)
	var rpm := [21000.0, 20500.0, 21400.0, 20800.0]
	update_data(delta, pos, angles, velocity, left, right, rpm)
