# Modified from GodotDrone (GPL-3.0, (c) Cykyrios), 2026: configurable default mode (position
# hold), hold targets captured on arm/mode change, arming with a centred throttle in hold
# modes, a fixed mode cycle, a power limit for low battery and no DebugGeometry.
class_name FlightController
extends Node3D


signal armed(mode: FlightMode)
signal disarmed
signal arm_failed(reason: ArmFail)
signal flight_mode_changed(mode: FlightMode)

enum Controller {YAW, ROLL, PITCH, YAW_SPEED, ROLL_SPEED, PITCH_SPEED,
		ALTITUDE, POS_X, POS_Z, VERTICAL_SPEED, FORWARD_SPEED, LATERAL_SPEED,
		LAUNCH}
enum ArmFail {THROTTLE_HIGH, CRASH_RECOVERY_MODE, BLOCKED}

var pid_roll_p := 50.0
var pid_roll_i := 30.0
var pid_roll_d := 30.0
var pid_pitch_p := 50.0
var pid_pitch_i := 30.0
var pid_pitch_d := 30.0
var pid_yaw_p := 70.0
var pid_yaw_i := 90.0
var pid_yaw_d := 40.0

var telemetry_enabled := false

## Mode selected when the drone is created. TRACK is the stabilized, position-hold mode.
## Mode selected on start and on every deploy. Set from QuadSettings by the drone.
var default_mode := FlightMode.Type.TRACK
## Modes reachable with the cycle button, in order: Stabilized, Attitude, Acro.
var cycle_order: Array[FlightMode.Type] = [
		FlightMode.Type.TRACK, FlightMode.Type.HORIZON, FlightMode.Type.ACRO]
## Upper bound for every motor PWM. The battery lowers it when it runs low.
var power_limit := 1.0
## When true the drone refuses to arm (an empty battery, for instance).
var arming_blocked := false
## Recovery hands control back once roll and pitch are below this angle.
@export var recovered_angle_deg := 15.0
## In Stabilized mode, holding the throttle down on the ground for this long disarms.
@export var auto_disarm_seconds := 1.5
## Below this height the drone counts as sitting on the ground (see `_hold_on_ground`).
@export var ground_contact_height := 0.2
var _landed_time := 0.0

var time := 0.0
var dt := 0.0
var pos := Vector3(0, 0, 0)
var pos_prev := pos
var angles := Vector3(0, 0, 0)
var angles_prev := angles
var lin_vel := Vector3(0, 0, 0)
var local_vel := Vector3(0, 0, 0)
var ang_vel := Vector3(0, 0, 0)
var basis_curr := Basis()
var basis_prev := basis_curr
var basis_flat := basis_curr
var flight_state := FlightState.new()

var motors: Array[Motor] = []
var hover_thrust := 0.0
var input := FlightCommand.new()

var control_profile: ControlProfile = null

var state_armed := false :
	set(arm):
		state_armed = arm
		for motor in motors:
			motor.powered = state_armed
		if state_armed:
			armed.emit(flight_mode)
		else:
			disarmed.emit()

var pid_controllers: Array[PID] = []

var flight_mode: FlightMode = null
var flight_modes: Array[FlightMode] = []
var flight_mode_idx := 0

var pid_scale_p := 0.004
var pid_scale_i := 0.002
var pid_scale_d := 0.0002

var telemetry_file: FileAccess = null


func _ready() -> void:
	setup_pids()
	setup_flight_modes()

	var _discard := flight_mode_changed.connect(get_parent()._on_flight_mode_changed)
	default_mode = QuadSettings.default_mode
	select_flight_mode.call_deferred(default_mode)

	if telemetry_enabled:
		var dir := DirAccess.open("")
		_discard = dir.remove("user://telemetry.csv")


func _physics_process(delta: float) -> void:
	if state_armed and (flight_mode is FlightModeHorizon or flight_mode is FlightModeSpeed \
			or flight_mode is FlightModeTrack) and not is_flight_safe():
		change_flight_mode(FlightMode.Type.RECOVER)
	elif not state_armed and flight_mode is FlightModeRecover:
		# Recovery only makes sense in flight. A drone disarmed while still tilted used to
		# stay in recovery mode forever, which refuses to arm until a respawn.
		change_flight_mode(flight_mode_idx)
	elif state_armed and flight_mode is FlightModeRecover and _is_level():
		# Level again: back to the pilot's mode, holding this spot.
		select_flight_mode(flight_mode_idx)
	elif flight_mode is FlightModeLaunch and (angles.x < deg_to_rad(-80) or angles.x > deg_to_rad(10)):
		_on_disarm_input()
	_check_auto_disarm(delta)

	if telemetry_enabled:
		write_telemetry()


## Landing in Stabilized mode: with the drone on the ground and the stick held down, the
## motors stop after a moment, like camera drones do.
func _check_auto_disarm(delta: float) -> void:
	var landed := state_armed and flight_mode is FlightModeTrack 			and flight_state.ground_distance < 0.3 and input.power < 0.2
	_landed_time = _landed_time + delta if landed else 0.0
	if _landed_time >= auto_disarm_seconds:
		_landed_time = 0.0
		_on_disarm_input()


## While the drone sits on the ground it cannot reach the attitude or position the PIDs ask
## for (it may rest on a slope), so their integral terms would wind up and flip it at
## take-off. Reset them, and in Stabilized keep holding the spot and heading where it sits.
func _hold_on_ground() -> void:
	for controller in [Controller.ROLL, Controller.PITCH, Controller.YAW, Controller.YAW_SPEED,
			Controller.ROLL_SPEED, Controller.PITCH_SPEED, Controller.POS_X, Controller.POS_Z,
			Controller.FORWARD_SPEED, Controller.LATERAL_SPEED]:
		pid_controllers[controller].reset_integral()
	if flight_mode is FlightModeTrack:
		pid_controllers[Controller.POS_X].target = pos.x
		pid_controllers[Controller.POS_Z].target = pos.z
		_capture_heading()


func set_control_profile(profile: ControlProfile) -> void:
	control_profile = profile
	for mode in flight_modes:
		mode.control_profile = control_profile


func setup_pids() -> void:
	for _i in Controller.size():
		pid_controllers.append(PID.new())

	pid_controllers[Controller.ALTITUDE].set_coefficients(
			300 * pid_scale_p, 300 * pid_scale_i, 800 * pid_scale_d)
	pid_controllers[Controller.ALTITUDE].set_clamp_limits(0.3, 0.7)
	pid_controllers[Controller.VERTICAL_SPEED].set_coefficients(
			200 * pid_scale_p, 600 * pid_scale_i, 200 * pid_scale_d)
	pid_controllers[Controller.VERTICAL_SPEED].set_clamp_limits(0.1, 1)
	pid_controllers[Controller.ROLL].set_coefficients(
			50 * pid_scale_p, 30 * pid_scale_i, 120 * pid_scale_d)
	pid_controllers[Controller.ROLL].set_clamp_limits(-0.025, 0.025)
	pid_controllers[Controller.PITCH].set_coefficients(
			50 * pid_scale_p, 30 * pid_scale_i, 120 * pid_scale_d)
	pid_controllers[Controller.PITCH].set_clamp_limits(-0.025, 0.025)

	# Clamp limits for speed controllers are equal to the maximum pitch/roll angle
	var max_angle := deg_to_rad(35)
	pid_controllers[Controller.FORWARD_SPEED].set_coefficients(
			50 * pid_scale_p, 50 * pid_scale_i, 1 * pid_scale_d)
	pid_controllers[Controller.FORWARD_SPEED].set_clamp_limits(-max_angle, max_angle)
	pid_controllers[Controller.LATERAL_SPEED].set_coefficients(
			50 * pid_scale_p, 50 * pid_scale_i, 1 * pid_scale_d)
	pid_controllers[Controller.LATERAL_SPEED].set_clamp_limits(-max_angle, max_angle)

	pid_controllers[Controller.YAW_SPEED].set_coefficients(
			pid_scale_p * pid_yaw_p, pid_scale_i * pid_yaw_i, pid_scale_d * pid_yaw_d)
	pid_controllers[Controller.YAW_SPEED].set_clamp_limits(-0.25, 0.25)
	pid_controllers[Controller.ROLL_SPEED].set_coefficients(
			pid_scale_p * pid_roll_p, pid_scale_i * pid_roll_i, pid_scale_d * pid_roll_d)
	pid_controllers[Controller.ROLL_SPEED].set_clamp_limits(-0.25, 0.25)
	pid_controllers[Controller.PITCH_SPEED].set_coefficients(
			pid_scale_p * pid_pitch_p, pid_scale_i * pid_pitch_i, pid_scale_d * pid_pitch_d)
	pid_controllers[Controller.PITCH_SPEED].set_clamp_limits(-0.25, 0.25)

	pid_controllers[Controller.POS_X].set_coefficients(0.5, 0.05, 0.3)
	pid_controllers[Controller.POS_X].set_clamp_limits(-0.5, 0.5)
	pid_controllers[Controller.POS_Z].set_coefficients(0.5, 0.05, 0.3)
	pid_controllers[Controller.POS_Z].set_clamp_limits(-0.5, 0.5)
	pid_controllers[Controller.YAW].set_coefficients(
			50 * pid_scale_p, 20 * pid_scale_i, 100 * pid_scale_d)
	pid_controllers[Controller.YAW].set_clamp_limits(-0.5, 0.5)

	pid_controllers[Controller.LAUNCH].set_coefficients(
			300 * pid_scale_p, 30 * pid_scale_i, 500 * pid_scale_d)
	pid_controllers[Controller.LAUNCH].set_clamp_limits(-0.5, 0)


func setup_flight_modes() -> void:
	var flight_mode_acro := FlightModeAcro.new()
	flight_mode_acro.pid_pitch = pid_controllers[Controller.PITCH_SPEED]
	flight_mode_acro.pid_roll = pid_controllers[Controller.ROLL_SPEED]
	flight_mode_acro.pid_yaw = pid_controllers[Controller.YAW_SPEED]
	flight_modes.append(flight_mode_acro)
	var flight_mode_horizon := FlightModeHorizon.new()
	flight_mode_horizon.pid_pitch = pid_controllers[Controller.PITCH]
	flight_mode_horizon.pid_roll = pid_controllers[Controller.ROLL]
	flight_mode_horizon.pid_yaw = pid_controllers[Controller.YAW_SPEED]
	flight_modes.append(flight_mode_horizon)
	var flight_mode_speed := FlightModeSpeed.new()
	flight_mode_speed.pid_pitch = pid_controllers[Controller.PITCH]
	flight_mode_speed.pid_roll = pid_controllers[Controller.ROLL]
	flight_mode_speed.pid_yaw = pid_controllers[Controller.YAW_SPEED]
	flight_mode_speed.pid_speed_forward = pid_controllers[Controller.FORWARD_SPEED]
	flight_mode_speed.pid_speed_side = pid_controllers[Controller.LATERAL_SPEED]
	flight_mode_speed.pid_speed_vertical = pid_controllers[Controller.VERTICAL_SPEED]
	flight_modes.append(flight_mode_speed)
	var flight_mode_track := FlightModeTrack.new()
	flight_mode_track.pid_pitch = pid_controllers[Controller.PITCH]
	flight_mode_track.pid_roll = pid_controllers[Controller.ROLL]
	flight_mode_track.pid_yaw = pid_controllers[Controller.YAW_SPEED]
	flight_mode_track.pid_pos_x = pid_controllers[Controller.POS_X]
	flight_mode_track.pid_pos_z = pid_controllers[Controller.POS_Z]
	flight_mode_track.pid_altitude = pid_controllers[Controller.ALTITUDE]
	flight_mode_track.pid_speed_forward = pid_controllers[Controller.FORWARD_SPEED]
	flight_mode_track.pid_speed_side = pid_controllers[Controller.LATERAL_SPEED]
	flight_modes.append(flight_mode_track)
	var flight_mode_launch := FlightModeLaunch.new()
	flight_mode_launch.pid_launch = pid_controllers[Controller.LAUNCH]
	flight_modes.append(flight_mode_launch)
	var flight_mode_turtle := FlightModeTurtle.new()
	flight_modes.append(flight_mode_turtle)
	var flight_mode_recover := FlightModeRecover.new()
	flight_mode_recover.pid_pitch_speed = pid_controllers[Controller.PITCH_SPEED]
	flight_mode_recover.pid_roll_speed = pid_controllers[Controller.ROLL_SPEED]
	flight_mode_recover.pid_pitch = pid_controllers[Controller.PITCH]
	flight_mode_recover.pid_roll = pid_controllers[Controller.ROLL]
	flight_mode_recover.pid_yaw = pid_controllers[Controller.YAW_SPEED]
	flight_mode_recover.pid_speed_forward = pid_controllers[Controller.FORWARD_SPEED]
	flight_mode_recover.pid_speed_side = pid_controllers[Controller.LATERAL_SPEED]
	flight_mode_recover.pid_speed_vertical = pid_controllers[Controller.VERTICAL_SPEED]
	flight_modes.append(flight_mode_recover)
	# Recovery mode asks to disarm once the drone is back near the ground
	var _discard := flight_mode_recover.disarm_requested.connect(_on_disarm_input)

	for mode in flight_modes:
		mode.control_profile = control_profile
		mode.flight_state = flight_state


## True when the throttle sits where the current mode expects it before arming: fully down
## in Acro/Attitude, centred in the hold modes (a gamepad stick rests there).
func is_throttle_at_idle() -> bool:
	return absf(input.power - flight_mode.idle_power()) <= 0.05


func _on_arm_input() -> void:
	if arming_blocked:
		arm_failed.emit(ArmFail.BLOCKED)
		return
	if is_throttle_at_idle() and not flight_mode is FlightModeRecover:
		if Input.is_action_pressed("mode_turtle"):
			change_flight_mode(FlightMode.Type.TURTLE)
		elif Input.is_action_pressed("mode_launch"):
			change_flight_mode(FlightMode.Type.LAUNCH)
		capture_hold_targets()
		state_armed = true
	else:
		if not is_throttle_at_idle():
			arm_failed.emit(ArmFail.THROTTLE_HIGH)
		elif flight_mode is FlightModeRecover:
			arm_failed.emit(ArmFail.CRASH_RECOVERY_MODE)
	for controller in pid_controllers:
		controller.disabled = false


func _on_disarm_input() -> void:
	state_armed = false
	if flight_mode is FlightModeTurtle or flight_mode is FlightModeLaunch or flight_mode is FlightModeRecover:
		# Back to the mode the pilot had selected before the special mode kicked in
		change_flight_mode(flight_mode_idx)
	for controller in pid_controllers:
		controller.disabled = true
		controller.reset()


func integrate_loop(delta: float, drone_pos: Vector3, drone_basis: Basis) -> void:
	dt = delta
	time += dt

	update_position(drone_pos, drone_basis)
	update_velocity()

	if state_armed:
		update_control(dt)


func update_position(new_pos := global_transform.origin, new_basis := global_transform.basis) -> void:
	pos_prev = pos
	pos = new_pos
	basis_prev = basis_curr
	basis_curr = new_basis
	angles_prev = angles
	angles = basis_curr.get_euler()

	flight_state.position = pos
	flight_state.orientation = angles
	flight_state.basis = basis_curr


func update_velocity() -> void:
	lin_vel = (pos - pos_prev) / dt
	local_vel = lin_vel * basis_curr

	var ref1 := Vector3(1, 0, 0)
	var orb1 := ((pos + basis_curr * ref1 - (pos_prev + basis_prev * ref1)) / dt - lin_vel) * basis_curr
	var omegax := (ref1.cross(orb1) / ref1.length_squared()).cross(ref1)
	var ref2 := Vector3(0, 1, 0)
	var orb2 := ((pos + basis_curr * ref2 - (pos_prev + basis_prev * ref2)) / dt - lin_vel) * basis_curr
	var omegay := (ref2.cross(orb2) / ref2.length_squared()).cross(ref2)
	var ref3 := Vector3(0, 0, 1)
	var orb3 := ((pos + basis_curr * ref3 - (pos_prev + basis_prev * ref3)) / dt - lin_vel) * basis_curr
	var omegaz := (ref3.cross(orb3) / ref3.length_squared()).cross(ref3)
	ang_vel = Vector3(omegay.z, omegaz.x, omegax.y)

	flight_state.velocity = lin_vel
	flight_state.angular_velocity = ang_vel


func init_telemetry() -> void:
	telemetry_file = FileAccess.open("user://telemetry.csv", FileAccess.WRITE)
	if telemetry_file:
		var _discard := telemetry_file.store_csv_line(["t", "input.power", "input.yaw", "input.roll", "input.pitch",
				"x", "y", "z", "vx", "vy", "vz", "vx_loc", "vy_loc", "vz_loc",
				"yaw", "roll", "pitch", "yaw_speed", "roll_speed", "pitch_speed",
				"delta_posx", "delta_posy", "delta_posz",
				"rpm1", "rpm2", "rpm3", "rpm4",
				"thrust1", "thrust2", "thrust3", "thrust4",
				"pid.alt.tgt", "pid.alt.err", "pid.alt.out", "pid.alt.clamp",
				"pid.pitch.tgt", "pid.pitch.err", "pid.pitch.out", "pid.pitch.clamp",
				"pid.roll.tgt", "pid.roll.err", "pid.roll.out", "pid.roll.clamp",
				"pid.yaw.tgt", "pid.yaw.err", "pid.yaw.out", "pid.yaw.clamp",
				"pid.yawspeed.tgt", "pid.yawspeed.err", "pid.yawspeed.out", "pid.yawspeed.clamp",
				"pid.pitchspeed.tgt", "pid.pitchspeed.err", "pid.pitchspeed.out", "pid.pitchspeed.clamp",
				"pid.rollspeed.tgt", "pid.rollspeed.err", "pid.rollspeed.out", "pid.rollspeed.clamp",
				"pid.fwdspeed.tgt", "pid.fwdspeed.err", "pid.fwdspeed.out", "pid.fwdspeed.clamp",
				"pid.latspeed.tgt", "pid.latspeed.err", "pid.latspeed.out", "pid.latspeed.clamp",
				"pid.vrtspeed.tgt", "pid.vrtspeed.err", "pid.vrtspeed.out", "pid.vrtspeed.clamp",
				"pid.posx.tgt", "pid.posx.err", "pid.posx.out", "pid.posx.clamp",
				"pid.posz.tgt", "pid.posz.err", "pid.posz.out", "pid.posz.clamp",
				"pid.launch.tgt", "pid.launch.err", "pid.launch.out", "pid.launch.clamp"])
		telemetry_file = null


func write_telemetry() -> void:
	if not FileAccess.file_exists("user://telemetry.csv"):
		init_telemetry()

	telemetry_file = FileAccess.open("user://telemetry.csv", FileAccess.READ_WRITE)
	if telemetry_file:
		telemetry_file.seek_end()
		var delta_pos := (get_tracking_target() - pos).rotated(Vector3.UP, -angles.y)
		var data := PackedStringArray([
			time,
			input.power,
			input.yaw,
			input.roll,
			input.pitch,
			pos.x,
			pos.y,
			pos.z,
			lin_vel.x,
			lin_vel.y,
			lin_vel.z,
			local_vel.x,
			local_vel.y,
			local_vel.z,
			angles.y,
			angles.z,
			angles.x,
			ang_vel.y,
			ang_vel.z,
			ang_vel.x,
			delta_pos.x,
			delta_pos.y,
			delta_pos.z,
			motors[0].get_rpm(),
			motors[1].get_rpm(),
			motors[2].get_rpm(),
			motors[3].get_rpm(),
			motors[0].propeller.forces[0].length(),
			motors[1].propeller.forces[0].length(),
			motors[2].propeller.forces[0].length(),
			motors[3].propeller.forces[0].length(),
			pid_controllers[Controller.ALTITUDE].target,
			pid_controllers[Controller.ALTITUDE].err,
			pid_controllers[Controller.ALTITUDE].output,
			pid_controllers[Controller.ALTITUDE].clamped_output,
			pid_controllers[Controller.PITCH].target,
			pid_controllers[Controller.PITCH].err,
			pid_controllers[Controller.PITCH].output,
			pid_controllers[Controller.PITCH].clamped_output,
			pid_controllers[Controller.ROLL].target,
			pid_controllers[Controller.ROLL].err,
			pid_controllers[Controller.ROLL].output,
			pid_controllers[Controller.ROLL].clamped_output,
			pid_controllers[Controller.YAW].target,
			pid_controllers[Controller.YAW].err,
			pid_controllers[Controller.YAW].output,
			pid_controllers[Controller.YAW].clamped_output,
			pid_controllers[Controller.YAW_SPEED].target,
			pid_controllers[Controller.YAW_SPEED].err,
			pid_controllers[Controller.YAW_SPEED].output,
			pid_controllers[Controller.YAW_SPEED].clamped_output,
			pid_controllers[Controller.PITCH_SPEED].target,
			pid_controllers[Controller.PITCH_SPEED].err,
			pid_controllers[Controller.PITCH_SPEED].output,
			pid_controllers[Controller.PITCH_SPEED].clamped_output,
			pid_controllers[Controller.ROLL_SPEED].target,
			pid_controllers[Controller.ROLL_SPEED].err,
			pid_controllers[Controller.ROLL_SPEED].output,
			pid_controllers[Controller.ROLL_SPEED].clamped_output,
			pid_controllers[Controller.FORWARD_SPEED].target,
			pid_controllers[Controller.FORWARD_SPEED].err,
			pid_controllers[Controller.FORWARD_SPEED].output,
			pid_controllers[Controller.FORWARD_SPEED].clamped_output,
			pid_controllers[Controller.LATERAL_SPEED].target,
			pid_controllers[Controller.LATERAL_SPEED].err,
			pid_controllers[Controller.LATERAL_SPEED].output,
			pid_controllers[Controller.LATERAL_SPEED].clamped_output,
			pid_controllers[Controller.VERTICAL_SPEED].target,
			pid_controllers[Controller.VERTICAL_SPEED].err,
			pid_controllers[Controller.VERTICAL_SPEED].output,
			pid_controllers[Controller.VERTICAL_SPEED].clamped_output,
			pid_controllers[Controller.POS_X].target,
			pid_controllers[Controller.POS_X].err,
			pid_controllers[Controller.POS_X].output,
			pid_controllers[Controller.POS_X].clamped_output,
			pid_controllers[Controller.POS_Z].target,
			pid_controllers[Controller.POS_Z].err,
			pid_controllers[Controller.POS_Z].output,
			pid_controllers[Controller.POS_Z].clamped_output,
			pid_controllers[Controller.LAUNCH].target,
			pid_controllers[Controller.LAUNCH].err,
			pid_controllers[Controller.LAUNCH].output,
			pid_controllers[Controller.LAUNCH].clamped_output,
		])
		var _discard := telemetry_file.store_csv_line(data)
		telemetry_file = null


func change_flight_mode(mode_idx: int) -> void:
	flight_mode = flight_modes[mode_idx]
	flight_mode_changed.emit(flight_mode)
	print("Mode: %s" % [flight_mode])


## Selects a flight mode as if the pilot had cycled to it: unlike `change_flight_mode`, the
## choice survives a disarm after recovery, turtle or launch mode.
func select_flight_mode(mode: FlightMode.Type) -> void:
	flight_mode_idx = mode
	change_flight_mode(mode)
	capture_hold_targets()


## Makes the hold modes keep the drone where it is now instead of flying back to an old target.
func capture_hold_targets() -> void:
	pid_controllers[Controller.ALTITUDE].target = pos.y
	pid_controllers[Controller.POS_X].target = pos.x
	pid_controllers[Controller.POS_Z].target = pos.z
	_capture_heading()


## Stabilized mode holds its heading with the YAW_SPEED controller (see setup_flight_modes);
## the rate modes overwrite that target every loop, so setting it is always safe.
func _capture_heading() -> void:
	pid_controllers[Controller.YAW].target = angles.y
	if flight_mode is FlightModeTrack:
		pid_controllers[Controller.YAW_SPEED].target = angles.y
		pid_controllers[Controller.YAW_SPEED].mv_prev = angles.y
	else:
		# Rate modes measure the yaw rate with this controller: no derivative kick.
		pid_controllers[Controller.YAW_SPEED].mv_prev = ang_vel.y


func _is_level() -> bool:
	var limit := deg_to_rad(recovered_angle_deg)
	return absf(angles.x) < limit and absf(angles.z) < limit and ang_vel.length() < 1.0


func _on_cycle_flight_modes() -> void:
	if flight_mode is FlightModeTurtle or flight_mode is FlightModeLaunch:
		return
	var next := (cycle_order.find(flight_mode_idx as FlightMode.Type) + 1) % cycle_order.size()
	select_flight_mode(cycle_order[next])


func get_angles_from_basis() -> void:
	angles = global_transform.basis.get_euler()


func is_flight_safe() -> bool:
	var max_angle := deg_to_rad(50)
	var safe := true
	if absf(angles.x) > max_angle or absf(angles.z) > max_angle:
		safe = false
	return safe


func set_motors(motor_array: Array) -> void:
	motors = motor_array
	for motor in motors:
		var _discard := armed.connect(motor._on_armed)


func set_hover_thrust(t: float) -> void:
	hover_thrust = t


func set_tracking_target(target: Vector3) -> void:
	pid_controllers[Controller.POS_X].target = target.x
	pid_controllers[Controller.ALTITUDE].target = target.y
	pid_controllers[Controller.POS_Z].target = target.z


func get_tracking_target() -> Vector3:
	return Vector3(
		pid_controllers[Controller.POS_X].target,
		pid_controllers[Controller.ALTITUDE].target,
		pid_controllers[Controller.POS_Z].target
	)


func update_control(delta: float) -> void:
	dt = delta
	flight_mode.update_loop_dt(dt)
	if flight_state.ground_distance < ground_contact_height:
		_hold_on_ground()
	var motor_control := update_command()
	var power := motor_control.power
	var yaw := motor_control.yaw
	var roll := motor_control.roll
	var pitch := motor_control.pitch
	var motor_pwm: Array[float] = [
			power + yaw + roll + pitch,
			power - yaw - roll + pitch,
			power + yaw - roll - pitch,
			power - yaw + roll - pitch,
	]

	# Air Mode
	var pwm_min := motor_pwm.min() as float
	var pwm_max := motor_pwm.max() as float
	var idle_pwm := motors[0].MIN_POWER / 100.0 as float
	# Scale PWM to range [idle, power_limit] as needed, keeping the differences between
	# motors (attitude authority) when the battery limits the power.
	var top := maxf(power_limit, idle_pwm)
	if pwm_max - pwm_min > top - idle_pwm:
		var pwm_mid := (pwm_min + pwm_max) / 2.0
		for i in 4:
			motor_pwm[i] = pwm_mid + (motor_pwm[i] - pwm_mid) * (top - idle_pwm) / (pwm_max - pwm_min)
	pwm_min = motor_pwm.min()
	pwm_max = motor_pwm.max()
	var offset := 0.0
	if pwm_min < idle_pwm:
		offset = idle_pwm - pwm_min
	if pwm_max > top:
		offset = top - pwm_max
	for i in 4:
		motor_pwm[i] += offset

	if flight_mode is FlightModeTurtle:
		motor_pwm = [0.0, 0.0, 0.0, 0.0]
		if absf(roll) > absf(pitch):
			if absf(roll) > 0.2:
				if roll > 0:
					motor_pwm[1] = -roll
					motor_pwm[2] = -roll
				else:
					motor_pwm[0] = roll
					motor_pwm[3] = roll
		else:
			if absf(pitch) > 0.2:
				if pitch > 0:
					motor_pwm[2] = -pitch
					motor_pwm[3] = -pitch
				else:
					motor_pwm[0] = pitch
					motor_pwm[1] = pitch

	elif flight_mode is FlightModeLaunch:
		motor_pwm = [idle_pwm, idle_pwm, idle_pwm, idle_pwm]
		motor_pwm[2] = clampf(-pitch, idle_pwm, 1)
		motor_pwm[3] = clampf(-pitch, idle_pwm, 1)
		if power > 0.2:
			motor_pwm = [-pitch, -pitch, -pitch, -pitch]
			change_flight_mode(FlightMode.Type.ACRO)

	motors[0].set_pwm(motor_pwm[0])
	motors[1].set_pwm(motor_pwm[1])
	motors[2].set_pwm(motor_pwm[2])
	motors[3].set_pwm(motor_pwm[3])


func update_command() -> FlightCommand:
	var command_input := FlightCommand.new()
	command_input.power = input.power
	if flight_mode is FlightModeTrack:
		# Stabilized commands speeds, not rotation rates: the acro rate curve would make small
		# deflections almost dead. A gentle expo keeps fine control around the centre.
		command_input.yaw = track_expo(input.yaw)
		command_input.roll = track_expo(input.roll)
		command_input.pitch = track_expo(input.pitch)
		return flight_mode.get_command(command_input)
	command_input.yaw = control_profile.get_normalized_axis_command(
			ControlProfile.Axis.YAW, input.yaw)
	command_input.roll = control_profile.get_normalized_axis_command(
			ControlProfile.Axis.ROLL, input.roll)
	command_input.pitch = control_profile.get_normalized_axis_command(
			ControlProfile.Axis.PITCH, input.pitch)
	return flight_mode.get_command(command_input)


## Stick shaping of the Stabilized mode: linear with a little cubic expo.
static func track_expo(stick: float, expo := 0.25) -> float:
	return stick * (1.0 - expo) + stick * stick * stick * expo


func reset() -> void:
	state_armed = false
	if flight_mode is FlightModeTurtle or flight_mode is FlightModeLaunch or flight_mode is FlightModeRecover:
		change_flight_mode(flight_mode_idx)

	# Update position twice to ensure pos_prev == pos
	for _i in 2:
		update_position()
	update_velocity()

	for controller in pid_controllers:
		controller.reset()
	pid_controllers[Controller.ALTITUDE].target = pos.y
	pid_controllers[Controller.POS_X].target = pos.x
	pid_controllers[Controller.POS_Z].target = pos.z
	_capture_heading()

	for motor in motors:
		motor.rpm = 0
