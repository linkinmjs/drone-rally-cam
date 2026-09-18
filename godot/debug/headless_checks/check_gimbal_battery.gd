## The gimbal keeps the horizon level while the drone banks, and the battery drains with
## thrust until it cuts the motors.
extends HeadlessCheck


const DRONE_SCENE := preload("res://drone/drones/rally_drone.tscn")


func run() -> void:
	add_floor()
	var drone := DRONE_SCENE.instantiate() as Drone
	add_child(drone)
	await physics_frames(5)
	await _check_gimbal(drone)
	await _check_battery(drone)


func _check_gimbal(drone: Drone) -> void:
	var gimbal := drone.get_node("Gimbal") as Gimbal
	drone.freeze = true
	var banked := Basis.from_euler(Vector3(deg_to_rad(10.0), deg_to_rad(30.0), deg_to_rad(20.0)))
	drone.global_transform = Transform3D(banked, Vector3(0, 5, 0))
	gimbal.tilt = deg_to_rad(-45.0)
	await process_frames(150)
	var angles := gimbal.camera.global_basis.get_euler()
	note("drone banked 20 deg, pitched 10 deg; camera pitch %.1f deg, roll %.1f deg, heading %.1f deg" % [
			rad_to_deg(angles.x), rad_to_deg(angles.z), rad_to_deg(angles.y)])
	expect(absf(rad_to_deg(angles.x) + 45.0) < 2.0, "the camera should keep the -45 deg tilt")
	expect(absf(rad_to_deg(angles.z)) < 1.0, "the camera should not roll with the drone")
	expect(absf(rad_to_deg(angles.y) - 30.0) < 2.0, "the camera should follow the drone heading")
	await process_frames(20)
	expect(gimbal.angular_speed < 0.05, "a settled gimbal should report no rotation")
	drone.freeze = false
	drone.reset_to(Transform3D.IDENTITY)
	await physics_frames(60)


func _check_battery(drone: Drone) -> void:
	var battery := drone.get_node("Battery") as Battery
	var fc := drone.flight_controller
	var hover_amps := battery._estimate_hover_current()
	note("estimated hover: %.1f A, %.1f min with a full %d mAh battery" % [hover_amps,
			battery.capacity_mah / 1000.0 / hover_amps * 60.0, int(battery.capacity_mah)])

	var low_signals := [0]
	var depleted_signals := [0]
	var _a := battery.low.connect(func() -> void: low_signals[0] += 1)
	var _b := battery.depleted.connect(func() -> void: depleted_signals[0] += 1)
	battery.capacity_mah = 4.0
	battery.recharge()
	fc.select_flight_mode(FlightMode.Type.TRACK)
	fc.input.power = 0.5
	fc._on_arm_input()
	expect(fc.state_armed, "the drone should arm for the battery test")
	var frames := 0
	while fc.state_armed and frames < 2000:
		fc.input.power = 0.8 if frames < 150 else 0.5
		await get_tree().physics_frame
		frames += 1
	note("a 4 mAh battery lasted %.1f s" % (frames / 100.0))
	expect(low_signals[0] == 1, "the low battery warning should fire once")
	expect(depleted_signals[0] == 1, "the depleted signal should fire once")
	expect(not fc.state_armed, "an empty battery should cut the motors")
	expect(is_equal_approx(fc.power_limit, battery.low_power_limit), "a low battery should limit the motors")
	var failures := []
	var _f := fc.arm_failed.connect(func(reason: FlightController.ArmFail) -> void: failures.append(reason))
	await physics_frames(200)
	fc.input.power = 0.5
	fc._on_arm_input()
	expect(not fc.state_armed and failures.has(FlightController.ArmFail.BLOCKED),
			"an empty battery must not arm again")
	battery.capacity_mah = 350.0
	battery.recharge()
	expect(is_equal_approx(fc.power_limit, 1.0), "recharging should lift the motor limit")
