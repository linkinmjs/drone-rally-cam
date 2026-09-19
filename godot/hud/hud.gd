# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: thin flight layer of
# the viewfinder. Horizon for any Camera3D (the gimbal view draws the real horizon), vertical
# speed over the real averaging window, horizontal speed, heading as a number, armed state in
# the mode chip; no side tapes, compass tape, RPM table or REC indicator.
class_name HUD
extends Control
## Flight layer of the viewfinder. It draws the horizon and the crosshair over the whole view
## and owns the components the viewfinder places in its layout: the readouts column, the mode
## chip and the two sticks, plus the armed state (`status`). Orientation aids follow the
## camera every frame; the numbers refresh at the "numbers rate" of the HUD settings.


enum Component {CROSSHAIR, STATUS, HEADING, SPEED, ALTITUDE, LADDER, HORIZON, STICKS,
		FLIGHT_MODE, DISTANCE, GIMBAL}

## HUD settings keys handled here (the rest of `GameSettings.hud_config` belongs to the
## viewfinder).
const OWN_KEYS: Array[String] = ["crosshair", "horizon", "ladder", "speed", "altitude",
		"heading", "sticks", "flight_mode", "status", "distance", "gimbal"]
const STICK_SIZE := 96.0
const STATE_COLORS := {
	HUDStatus.Status.DISARMED: HudStyle.AMBER,
	HUDStatus.Status.ARMED: HudStyle.GREEN,
	HUDStatus.Status.LAUNCH: HudStyle.AMBER,
	HUDStatus.Status.TURTLE: HudStyle.AMBER,
	HUDStatus.Status.RECOVERY: HudStyle.RED,
}

var horizon: HUDHorizon
var crosshair: HUDCrosshair
var readouts: HUDReadouts
var mode_badge: HUDModeBadge
var status: HUDStatus
var sticks: HBoxContainer
var stick_left: StickHint
var stick_right: StickHint

## True when the HUD is a preview in the settings (no drone around it): fake flight data.
var preview_mode := false
## True in the pilot view: the horizon style follows the settings there. The gimbal view
## always draws the real horizon of its camera.
var pilot_view := false
## False while there is no ground under the drone within the sensor range.
var altitude_known := true

# Flight data, averaged over the numbers refresh period
var hud_timer := 0.1
var hud_delta := 0.0
var hud_position := Vector3.ZERO
var hud_velocity := Vector3.ZERO

# Latest raw values, used every frame by the orientation aids
var latest_position := Vector3.ZERO
var latest_angles := Vector3.ZERO
var latest_velocity := Vector3.ZERO
var latest_left_stick := Vector2.ZERO
var latest_right_stick := Vector2.ZERO

var _previous_altitude := 0.0
var _has_previous_altitude := false
var _window_altitude_known := true
var _camera: Camera3D = null
var _preview_time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	horizon = HUDHorizon.new()
	horizon.name = "HUDHorizon"
	horizon.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(horizon)
	crosshair = HUDCrosshair.new()
	crosshair.name = "Crosshair"
	crosshair.custom_minimum_size = Vector2(48, 48)
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	status = HUDStatus.new()
	status.name = "HUDStatus"
	add_child(status)

	# Placed by the viewfinder in its layout.
	readouts = HUDReadouts.new()
	readouts.name = "HUDReadouts"
	mode_badge = HUDModeBadge.new()
	mode_badge.name = "HUDModeBadge"
	sticks = HBoxContainer.new()
	sticks.name = "HUDSticks"
	sticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sticks.add_theme_constant_override("separation", int(HudStyle.GUTTER))
	stick_left = StickHint.new()
	stick_left.custom_minimum_size = Vector2(STICK_SIZE, STICK_SIZE)
	sticks.add_child(stick_left)
	stick_right = StickHint.new()
	stick_right.custom_minimum_size = Vector2(STICK_SIZE, STICK_SIZE)
	sticks.add_child(stick_right)


func _ready() -> void:
	var _discard := status.changed.connect(_on_status_changed)
	_discard = GameSettings.hud_config_updated.connect(apply_hud_config)
	reset_data()
	_on_status_changed()
	apply_hud_config()


func _exit_tree() -> void:
	# The placed components live elsewhere in the tree; the ones never placed are freed here.
	for component: Node in [readouts, mode_badge, sticks]:
		if is_instance_valid(component) and not component.is_inside_tree():
			component.queue_free()


## The camera in view: the horizon and the heading are drawn for it.
func set_camera(camera: Camera3D, is_pilot_view := false) -> void:
	_camera = camera
	horizon.camera = camera
	pilot_view = is_pilot_view
	horizon.mode = str(GameSettings.hud_config["horizon_mode"]) if pilot_view else "camera"
	horizon.queue_redraw()


func apply_hud_config() -> void:
	var config := GameSettings.hud_config
	hud_timer = 1.0 / float(config["fps"])
	horizon.mode = str(config["horizon_mode"]) if pilot_view else "camera"
	for key: String in OWN_KEYS:
		show_component(_component_for_key(key), bool(config.get(key, false)))


func _component_for_key(key: String) -> Component:
	match key:
		"crosshair": return Component.CROSSHAIR
		"horizon": return Component.HORIZON
		"ladder": return Component.LADDER
		"speed": return Component.SPEED
		"altitude": return Component.ALTITUDE
		"heading": return Component.HEADING
		"sticks": return Component.STICKS
		"flight_mode": return Component.FLIGHT_MODE
		"status": return Component.STATUS
		"distance": return Component.DISTANCE
		_: return Component.GIMBAL


func show_component(component: int, show_comp: bool = true) -> void:
	match component:
		Component.CROSSHAIR:
			crosshair.visible = show_comp
		Component.STATUS:
			mode_badge.set_parts(mode_badge.show_mode, show_comp)
		Component.FLIGHT_MODE:
			mode_badge.set_parts(show_comp, mode_badge.show_state)
		Component.HEADING:
			readouts.show_heading = show_comp
		Component.SPEED:
			readouts.show_speed = show_comp
		Component.ALTITUDE:
			readouts.show_altitude = show_comp
		Component.DISTANCE:
			readouts.show_distance = show_comp
		Component.GIMBAL:
			readouts.show_gimbal = show_comp
		Component.LADDER:
			horizon.show_ladder = show_comp
			horizon.queue_redraw()
		Component.HORIZON:
			horizon.show_horizon = show_comp
			horizon.queue_redraw()
		Component.STICKS:
			sticks.visible = show_comp
	readouts.refresh_layout()


func _process(delta: float) -> void:
	if preview_mode:
		_update_preview(delta)
	_update_orientation()
	if hud_delta >= hud_timer:
		flush_numbers()


## Averages the data of the finished window and refreshes the numbers.
func flush_numbers() -> void:
	if hud_delta <= 0.0:
		return
	var window := hud_delta
	var avg_position := hud_position / window
	var avg_velocity := hud_velocity / window
	readouts.speed_kmh = Vector2(avg_velocity.x, avg_velocity.z).length() * 3.6
	readouts.altitude = avg_position.y
	readouts.altitude_known = _window_altitude_known
	if _window_altitude_known and _has_previous_altitude:
		readouts.vertical_speed = (avg_position.y - _previous_altitude) / window
		readouts.vertical_speed_known = true
	else:
		readouts.vertical_speed_known = false
	_previous_altitude = avg_position.y
	_has_previous_altitude = _window_altitude_known
	readouts.queue_redraw()
	reset_data()


## The height jumped (respawn, deploy): the next vertical speed must not compare against it.
func reset_altitude() -> void:
	_has_previous_altitude = false
	readouts.vertical_speed_known = false
	reset_data()


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
	readouts.heading_deg = fposmod(heading, 360.0)

	horizon.pitch = latest_angles.x
	horizon.roll = latest_angles.z
	if horizon.show_horizon or horizon.show_ladder:
		horizon.queue_redraw()

	if sticks.visible:
		stick_left.set_stick(latest_left_stick)
		stick_right.set_stick(latest_right_stick)


func update_data(dt: float, pos: Vector3, angles: Vector3, velocity: Vector3,
		left_stick: Vector2, right_stick: Vector2) -> void:
	latest_position = pos
	latest_angles = angles
	latest_velocity = velocity
	latest_left_stick = left_stick
	latest_right_stick = right_stick
	hud_delta += dt
	hud_position += dt * pos
	hud_velocity += dt * velocity
	if not altitude_known:
		_window_altitude_known = false


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
	hud_delta = 0.0
	hud_position = Vector3.ZERO
	hud_velocity = Vector3.ZERO
	_window_altitude_known = altitude_known


func _on_status_changed() -> void:
	mode_badge.set_state(status.state_key(), STATE_COLORS[status.status])


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
	update_data(delta, pos, angles, velocity, left, right)
