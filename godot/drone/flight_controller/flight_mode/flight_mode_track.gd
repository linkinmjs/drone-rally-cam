# Modified from GodotDrone (GPL-3.0, (c) Cykyrios), 2026: stick input relative to the
# heading, configurable speeds, centred idle throttle, direct speed response to the sticks and
# a planned stop on release. Used as the "Stabilized" mode.
## The horizontal sticks command the ground speed directly (like a camera drone): the drone
## responds at once and, on release, brakes to a stop point planned from its speed, then
## holds that position. The throttle stick moves the height target.
class_name FlightModeTrack
extends FlightMode


var pid_pitch: PID = null
var pid_roll: PID = null
var pid_yaw: PID = null
var pid_altitude: PID = null
var pid_pos_x: PID = null
var pid_pos_z: PID = null
var pid_speed_forward: PID = null
var pid_speed_side: PID = null

## Maximum speed of the hold target when the sticks are fully deflected, in m/s.
var speed_h := 10.0
var speed_v := 4.0
## Maximum yaw rate, in rad/s.
var yaw_rate := deg_to_rad(120.0)
## Below this height the descent slows down, to 1/4 of speed_v on the ground, so landing
## with the stick held down touches down gently.
var landing_slowdown_height := 5.0
## Deceleration used to place the stop point when the stick is released, in m/s².
var brake_deceleration := 5.0
## Deceleration of the speed profile toward the stop point, in m/s². Lower than
## brake_deceleration so the drone starts braking as soon as the stick is released.
var approach_deceleration := 3.5
## Hardest braking the bank limit allows, in m/s². When even this could not stop the drone
## before the stop point, the point moves ahead instead of making the drone come back.
var max_brake_deceleration := 7.0
## Farthest the hold point can be from the drone, in meters.
var hold_leash := 10.0

## Horizontal stick deflection under which the sticks count as released.
const STICK_ACTIVE := 0.05

var _steering := false
var _braking := false


func _init() -> void:
	type = Type.TRACK


func _to_string() -> String:
	return "STABILIZED"


func idle_power() -> float:
	return 0.5


func _get_command(input: FlightCommand) -> FlightCommand:
	var flight_command := FlightCommand.new()
	var angles := flight_state.orientation
	var basis := flight_state.basis
	var local_vel := flight_state.velocity * basis

	var target := get_tracking_target()
	var target_prev := target
	var pos := flight_state.position
	# Sticks command a speed relative to the drone's heading, not along world axes.
	var move := Vector3(input.roll, 0.0, input.pitch).rotated(Vector3.UP, angles.y) * speed_h
	var steering := Vector2(input.roll, input.pitch).length() > STICK_ACTIVE
	if steering != _steering:
		# The speed loop's memory of the previous phase (sustained tilt against drag while
		# cruising) would fight the new one: braking would barely tilt back.
		pid_speed_forward.reset_integral()
		pid_speed_side.reset_integral()
	if steering:
		# The hold point rides along with the drone: nothing winds up while steering.
		target.x = pos.x
		target.z = pos.z
		_braking = false
	elif _steering or _braking:
		# Released: stop where the drone can brake to from its current speed. The stop point
		# only ever moves ahead, so the drone never has to come back to it.
		var velocity := Vector2(flight_state.velocity.x, flight_state.velocity.z)
		var speed := velocity.length()
		var here := Vector2(pos.x, pos.z)
		if _steering:
			var stop := here + velocity * speed / (2.0 * brake_deceleration)
			target.x = stop.x
			target.z = stop.y
		else:
			var hardest := here + velocity * speed / (2.0 * max_brake_deceleration)
			if (hardest - Vector2(target.x, target.z)).dot(velocity) > 0.0:
				target.x = hardest.x
				target.z = hardest.y
		_braking = speed > 0.5
	_steering = steering
	var climb := 2.0 * (input.power - 0.5) * speed_v
	if climb < 0.0:
		climb *= clampf(flight_state.ground_distance / landing_slowdown_height, 0.25, 1.0)
	target.y = target.y + climb * dt
	# Keep the target close to the drone: holding the stick against the ground or an obstacle
	# must not wind it up far away, or releasing the stick would send the drone flying.
	target.y = maxf(target.y, pos.y - 1.0)
	var offset := Vector2(target.x - pos.x, target.z - pos.z).limit_length(hold_leash)
	target.x = pos.x + offset.x
	target.z = pos.z + offset.y
	set_tracking_target(target)

	flight_command.power = pid_altitude.get_output(flight_state.position.y, dt, false)

	var target_angle := pid_yaw.target - input.yaw * yaw_rate * dt
	while target_angle > PI:
		target_angle -= 2 * PI
	while target_angle < -PI:
		target_angle += 2 * PI
	pid_yaw.target = target_angle
	var hdg_delta := 0.0
	if absf(target_angle - angles.y) > PI:
		hdg_delta = 2 * PI
		if target_angle < 0:
			hdg_delta = -hdg_delta
	var measurement := angles.y + hdg_delta
	# Manually correct previous PID measurement to remove discontinuity
	if absf(pid_yaw.mv_prev - measurement) > PI:
		pid_yaw.mv_prev += hdg_delta
	flight_command.yaw = pid_yaw.get_output(measurement, dt, false)

	var xform := Transform3D(basis, flight_state.position)
	target = get_tracking_target()
	var delta_pos: Vector3 = target * xform
	var target_vel := Vector3(move.x, (target.y - target_prev.y) / dt, move.z) if steering \
			else Vector3(0.0, (target.y - target_prev.y) / dt, 0.0)
	var local_target_vel := target_vel * basis
	var approach := Vector2.ZERO if steering else _approach_speed(Vector2(delta_pos.x, delta_pos.z))

	var bank_limit := deg_to_rad(35)
	if (
		steering
		or _braking
		or flight_state.velocity.length() > 2.8
		or target_vel.length() > 2.8
		or delta_pos.length() > 3.0
	):
		pid_speed_side.target = local_target_vel.x + approach.x
		var roll_change := pid_speed_side.get_output(local_vel.x, dt, false)
		pid_roll.target = clampf(roll_change, -bank_limit, bank_limit)
		flight_command.roll = pid_roll.get_output(-angles.z, dt, false)

		pid_speed_forward.target = local_target_vel.z + approach.y
		var pitch_change := pid_speed_forward.get_output(local_vel.z, dt, false)
		pid_pitch.target = clampf(pitch_change, -bank_limit, bank_limit)
		flight_command.pitch = pid_pitch.get_output(angles.x, dt, false)
	else:
		var roll_target := pid_pos_x.get_output(target.x - delta_pos.x, dt)
		pid_roll.target = clampf(roll_target,-bank_limit, bank_limit)
		flight_command.roll = pid_roll.get_output(-angles.z, dt)

		var pitch_target := pid_pos_z.get_output(target.z - delta_pos.z, dt)
		pid_pitch.target = clampf(pitch_target,-bank_limit, bank_limit)
		flight_command.pitch = pid_pitch.get_output(angles.x, dt)

	return flight_command


## Speed toward a point `offset` away: proportional close to it, and never faster than what
## still lets the drone brake to a stop there.
func _approach_speed(offset: Vector2) -> Vector2:
	var distance := offset.length()
	if distance < 1e-4:
		return Vector2.ZERO
	var speed := minf(2.0 * distance, sqrt(2.0 * approach_deceleration * distance))
	return offset / distance * speed


func get_tracking_target() -> Vector3:
	return Vector3(pid_pos_x.target, pid_altitude.target, pid_pos_z.target)


func set_tracking_target(target: Vector3) -> void:
	pid_pos_x.target = target.x
	pid_altitude.target = target.y
	pid_pos_z.target = target.z
