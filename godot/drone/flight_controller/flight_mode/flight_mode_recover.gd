# Modified from GodotDrone (GPL-3.0, (c) Cykyrios), 2026: levels out holding the height instead
# of descending at 5 m/s (which crashed the drone), and only disarms when tipped over on the ground.
class_name FlightModeRecover
extends FlightMode


signal disarm_requested

var pid_pitch_speed : PID = null
var pid_roll_speed : PID = null
var pid_pitch : PID = null
var pid_roll : PID = null
var pid_yaw : PID = null
var pid_speed_forward : PID = null
var pid_speed_side : PID = null
var pid_speed_vertical : PID = null


func _init() -> void:
	type = Type.RECOVER


func _to_string() -> String:
	return "RECOVER"


func _get_command(_input: FlightCommand) -> FlightCommand:
	var flight_command := FlightCommand.new()
	var angles := flight_state.orientation
	var ang_vel := flight_state.angular_velocity

	pid_yaw.target = 0
	flight_command.yaw = pid_yaw.get_output(ang_vel.y, dt, false)

	# Keep the height while levelling out; the flight controller hands control back to the
	# pilot's mode once the drone is level again.
	pid_speed_vertical.target = 0.0
	flight_command.power = pid_speed_vertical.get_output(flight_state.velocity.y, dt, false)
	# Tipped over on the ground: stop the motors instead of fighting the ground.
	if flight_state.ground_distance < 0.3:
		disarm_requested.emit()

	if ang_vel.length_squared() <= deg_to_rad(360):
		pid_roll.target = 0
		flight_command.roll = pid_roll.get_output(-angles.z, dt, false)
		pid_pitch.target = 0
		flight_command.pitch = pid_pitch.get_output(angles.x, dt, false)
	else:
		pid_roll_speed.target = 0
		flight_command.roll = pid_roll_speed.get_output(-ang_vel.z, dt, false)
		pid_pitch_speed.target = 0
		flight_command.pitch = pid_pitch_speed.get_output(ang_vel.x, dt, false)

	return flight_command
