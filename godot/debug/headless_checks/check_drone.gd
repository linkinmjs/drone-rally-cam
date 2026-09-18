## Flies the transplanted drone on a flat floor: import products, climbing in Attitude,
## falling when disarmed, arming with a centred throttle and holding position in Stabilized.
extends HeadlessCheck


const DRONE_SCENE := preload("res://drone/drones/rally_drone.tscn")

var drone: Drone
var fc: FlightController


func run() -> void:
	add_floor()
	drone = DRONE_SCENE.instantiate() as Drone
	add_child(drone)
	fc = drone.flight_controller
	drone.reset_to(Transform3D.IDENTITY)
	await physics_frames(20)

	_check_import_products()
	await _check_attitude_climb_and_fall()
	await _check_stabilized_hold()
	await _check_stabilized_moves_along_heading()
	await _check_crash_disarms()
	await _check_takeoff_from_slope()
	await _check_gentle_landing()
	await _check_recovery_hands_back()


func _check_import_products() -> void:
	expect(drone.find_children("*", "CollisionShape3D", false, false).size() >= 4,
			"the frame's collision shapes were not moved to the drone body")
	for motor in drone.motors:
		expect(motor.propeller.ray != null, "%s has no ground-effect RayCast3D" % motor.name)
		expect(motor.has_node("Area3D"), "%s has no Area3D" % motor.name)
	expect(drone.has_node("Gimbal/Camera3D"), "the drone has no gimbal camera")
	expect(fc.flight_mode is FlightModeTrack, "default flight mode should be Stabilized, got %s" % fc.flight_mode)


func _check_attitude_climb_and_fall() -> void:
	await _reset_on_ground()
	fc.select_flight_mode(FlightMode.Type.HORIZON)
	_set_input(0.0)
	fc._on_arm_input()
	expect(fc.state_armed, "should arm in Attitude with the throttle down")
	var start_y := drone.global_position.y
	await _hold_input(0.75, 200)
	var climb := drone.global_position.y - start_y
	note("Attitude: climbed %.2f m in 2 s at 75 %% throttle" % climb)
	expect(climb > 0.5, "the drone did not climb in Attitude mode (%.2f m)" % climb)

	fc._on_disarm_input()
	await _hold_input(0.0, 900)
	var fallen_y := drone.global_position.y
	note("Attitude: height 9 s after disarming = %.2f m" % fallen_y)
	expect(fallen_y < 0.5, "the drone did not fall back to the ground after disarming")


func _check_stabilized_hold() -> void:
	await _reset_on_ground()
	fc.select_flight_mode(FlightMode.Type.TRACK)
	_set_input(0.0)
	fc._on_arm_input()
	expect(not fc.state_armed, "should refuse to arm in Stabilized with the throttle down")
	_set_input(0.5)
	fc._on_arm_input()
	expect(fc.state_armed, "should arm in Stabilized with a centred throttle")

	await _hold_input(0.5, 100)
	var idle_height := drone.global_position.y
	note("Stabilized: height after 1 s armed with centred stick = %.2f m" % idle_height)
	expect(idle_height < 0.6, "armed with a centred stick, the drone should stay near the ground")

	await _hold_input(1.0, 150)
	var climbed := drone.global_position.y
	note("Stabilized: height after climbing 1.5 s = %.2f m" % climbed)
	expect(climbed > 3.0, "the drone should climb with the throttle up (%.2f m)" % climbed)

	await _hold_input(0.5, 150)
	var hold_start := drone.global_position
	await _hold_input(0.5, 300)
	var drift := drone.global_position - hold_start
	note("Stabilized: drift over 3 s with centred sticks = %s (%.2f m)" % [drift, drift.length()])
	expect(absf(drift.y) < 0.4, "altitude drifted %.2f m in hold" % drift.y)
	expect(Vector2(drift.x, drift.z).length() < 0.4, "position drifted %.2f m in hold" % Vector2(drift.x, drift.z).length())


func _check_stabilized_moves_along_heading() -> void:
	# The drone faces -Z after a reset. Pitch forward must move it towards -Z.
	var start := drone.global_position
	await _hold_input(0.5, 200, 0.0, 0.0, -1.0)
	var moved := drone.global_position - start
	note("Stabilized: full forward stick for 2 s moved %s" % moved)
	expect(moved.z < -4.0, "forward stick did not move the drone forward (%.2f m)" % moved.z)
	expect(absf(moved.x) < 1.5, "forward stick drifted sideways (%.2f m)" % moved.x)

	# Releasing the stick brakes to a stop close by, without springing back.
	var velocity := Vector2(drone.linear_velocity.x, drone.linear_velocity.z)
	var direction := velocity.normalized()
	var released_at := Vector2(drone.global_position.x, drone.global_position.z)
	var farthest := 0.0
	var stop_frame := -1
	for frame in 300:
		_set_input(0.5)
		await get_tree().physics_frame
		var along := (Vector2(drone.global_position.x, drone.global_position.z) - released_at).dot(direction)
		farthest = maxf(farthest, along)
		if stop_frame < 0 and Vector2(drone.linear_velocity.x, drone.linear_velocity.z).length() < 0.3:
			stop_frame = frame
	var final := (Vector2(drone.global_position.x, drone.global_position.z) - released_at).dot(direction)
	note("Stabilized: released at %.1f m/s, ran %.1f m, came back %.2f m, stopped after %.2f s" % [
			velocity.length(), farthest, farthest - final, stop_frame / 100.0])
	expect(farthest < velocity.length_squared() / 8.0 + 1.0, "the drone should brake when the stick is released")
	expect(farthest - final < 0.6, "the drone should not spring back after stopping (%.2f m)" % (farthest - final))
	expect(stop_frame >= 0 and stop_frame < 250, "the drone should come to rest after releasing the stick")

	# A small deflection moves the drone slowly but at once.
	await _hold_input(0.5, 100)
	var gentle_start := drone.global_position
	await _hold_input(0.5, 100, 0.0, 0.0, -0.15)
	var gentle := Vector2(drone.global_position.x - gentle_start.x, drone.global_position.z - gentle_start.z)
	note("Stabilized: 15 %% forward stick for 1 s moved %.2f m" % gentle.length())
	expect(gentle.length() > 0.4, "a small stick deflection should move the drone")
	await _hold_input(0.5, 150)

	# Yaw 90 degrees to the right, then forward must move it towards +X.
	await _hold_input(0.5, 150)
	await _hold_input(0.5, 75, 1.0)
	await _hold_input(0.5, 100)
	var heading := rad_to_deg(drone.global_basis.get_euler().y)
	note("Stabilized: heading after yawing right = %.0f deg" % heading)
	start = drone.global_position
	await _hold_input(0.5, 200, 0.0, 0.0, -1.0)
	moved = drone.global_position - start
	note("Stabilized: forward after the yaw moved %s" % moved)
	expect(moved.x > 3.0 and absf(moved.z) < absf(moved.x),
			"after yawing right, forward stick should move the drone towards +X")


func _check_crash_disarms() -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 1)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = drone.global_position + Vector3(0, 0, -6)

	await _reset_to(Transform3D(Basis.IDENTITY, wall.global_position + Vector3(0, 1, 5)))
	fc.select_flight_mode(FlightMode.Type.HORIZON)
	_set_input(0.0)
	fc._on_arm_input()
	drone.linear_velocity = Vector3(0, 0, -8)
	await _hold_input(0.55, 150)
	expect(not fc.state_armed, "hitting a wall at 8 m/s should disarm the drone")
	wall.queue_free()


func _reset_on_ground() -> void:
	await _reset_to(Transform3D.IDENTITY)


func _reset_to(xform: Transform3D) -> void:
	if fc.state_armed:
		fc._on_disarm_input()
	drone.reset_to(xform)
	await physics_frames(60)


func _set_input(power: float, yaw := 0.0, roll := 0.0, pitch := 0.0) -> void:
	fc.input.power = power
	fc.input.yaw = yaw
	fc.input.roll = roll
	fc.input.pitch = pitch


func _hold_input(power: float, frames: int, yaw := 0.0, roll := 0.0, pitch := 0.0) -> void:
	for _i in frames:
		_set_input(power, yaw, roll, pitch)
		await get_tree().physics_frame


## The case can be opened on slopes up to 15 degrees: taking off from one, facing any way,
## must not flip or spin the drone, neither climbing with the stick nor with a target far above.
func _check_takeoff_from_slope() -> void:
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	shape.shape = box
	ramp.add_child(shape)
	add_child(ramp)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(14.0))
	ramp.global_transform = Transform3D(tilt, Vector3(60, 0, 0))
	var top := Vector3(60, 0.5 / cos(deg_to_rad(14.0)), 0)
	await physics_frames(2)

	for climb_with_target: bool in [false, true]:
		# Facing away from north: a heading target left at 0 would spin the drone on the ground.
		await _reset_to(Transform3D(tilt * Basis(Vector3.UP, deg_to_rad(-116.0)), top))
		var start_heading := fc.angles.y
		fc.select_flight_mode(FlightMode.Type.TRACK)
		_set_input(0.5)
		await _hold_input(0.5, 100)
		fc._on_arm_input()
		var worst_tilt := 0.0
		var recovered := false
		if climb_with_target:
			fc.set_tracking_target(drone.global_position + Vector3.UP * 7.0)
		for i in 300:
			_set_input(0.5 if climb_with_target else (0.9 if i < 150 else 0.5))
			await get_tree().physics_frame
			worst_tilt = maxf(worst_tilt, maxf(absf(fc.angles.x), absf(fc.angles.z)))
			recovered = recovered or fc.flight_mode is FlightModeRecover
		var height := fc.flight_state.ground_distance
		var turned := rad_to_deg(absf(angle_difference(start_heading, fc.angles.y)))
		note("take-off from a 14 deg slope (%s): %.1f m high, worst tilt %.0f deg, turned %.0f deg" % [
				"hold target 7 m up" if climb_with_target else "stick up", height, rad_to_deg(worst_tilt), turned])
		expect(not recovered and fc.state_armed, "taking off from a slope should not flip the drone")
		expect(turned < 10.0, "the drone should keep its heading when taking off")
		expect(height > 2.5, "the drone should have climbed away from the slope")
	ramp.queue_free()


## Holding the stick down in Stabilized lands softly (no crash) and stops the motors.
func _check_gentle_landing() -> void:
	await _reset_on_ground()
	fc.select_flight_mode(FlightMode.Type.TRACK)
	_set_input(0.5)
	fc._on_arm_input()
	await _hold_input(1.0, 300)
	await _hold_input(0.5, 150)
	var crashes := [0]
	var sensor := drone.get_node("CrashSensor") as CrashSensor
	var count_crash := func(_s: float) -> void: crashes[0] += 1
	var _c := sensor.crashed.connect(count_crash)
	var touchdown := 0.0
	var start_height := fc.flight_state.ground_distance
	for _i in 1500:
		_set_input(0.0)
		var vertical := drone.linear_velocity.y
		await get_tree().physics_frame
		if fc.flight_state.ground_distance < 0.1 and touchdown == 0.0:
			touchdown = absf(vertical)
		if not fc.state_armed:
			break
	note("landing from %.1f m with the stick down: touchdown at %.2f m/s, motors %s" % [
			start_height, touchdown, "stopped" if not fc.state_armed else "still running"])
	expect(crashes[0] == 0, "a normal landing must not count as a crash")
	expect(touchdown < 2.0, "the landing should be gentle (%.2f m/s)" % touchdown)
	expect(not fc.state_armed, "holding the stick down on the ground should stop the motors")
	sensor.crashed.disconnect(count_crash)


## A knock that tips the drone past 50 degrees: it levels out holding its height and gives
## control back in Stabilized, instead of diving into the ground.
func _check_recovery_hands_back() -> void:
	await _reset_on_ground()
	fc.select_flight_mode(FlightMode.Type.TRACK)
	_set_input(0.5)
	fc._on_arm_input()
	await _hold_input(1.0, 350)
	await _hold_input(0.5, 150)
	var height := fc.flight_state.ground_distance
	drone.angular_velocity = drone.global_basis.x * 9.0
	var entered := false
	for _i in 500:
		_set_input(0.5)
		await get_tree().physics_frame
		entered = entered or fc.flight_mode is FlightModeRecover
	note("recovery from %.1f m: entered %s, now %s at %.1f m, armed %s" % [height, entered,
			fc.flight_mode, fc.flight_state.ground_distance, fc.state_armed])
	expect(entered, "tipping the drone past 50 degrees should trigger recovery")
	expect(fc.flight_mode is FlightModeTrack and fc.state_armed, "recovery should hand control back")
	expect(fc.flight_state.ground_distance > height - 4.0, "recovery should not lose much height")
