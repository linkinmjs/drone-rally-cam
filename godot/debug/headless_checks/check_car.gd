## Builds the hand-made stage and drives the car along it: terrain collision size, speed
## profile rules (grip limit, braking before corners, increasing times) and the car staying
## on the road surface.
extends HeadlessCheck


const STAGE := preload("res://world/stages/stage_01.tscn")


func run() -> void:
	var start := Time.get_ticks_msec()
	var world := STAGE.instantiate() as StageWorld
	add_child(world)
	note("stage built in %d ms" % (Time.get_ticks_msec() - start))
	var builder := world.builder
	var car := world.car

	var body := builder.find_child("TerrainBody", true, false) as StaticBody3D
	expect(body != null, "the terrain has no collision body")
	if body:
		var heightmap := (body.get_child(0) as CollisionShape3D).shape as HeightMapShape3D
		expect(heightmap.map_width == heightmap.map_depth, "the heightmap must be square for Jolt")
		note("heightmap %d x %d samples, heights %.1f .. %.1f m" % [heightmap.map_width,
				heightmap.map_depth, heightmap.get_min_height() * builder.resolution,
				heightmap.get_max_height() * builder.resolution])

	var length := builder.get_road_length()
	note("road length %.0f m, %d trees" % [length, builder.tree_positions.size()])
	expect(length > 1000.0 and length < 2500.0, "unexpected road length %.0f m" % length)

	var profile := car.profile
	expect(profile != null, "the car has no speed profile")
	if not profile:
		return
	var fastest := 0.0
	var slowest := INF
	for i in profile.speeds.size():
		var speed := profile.speeds[i]
		fastest = maxf(fastest, speed)
		var distance := i * profile.step
		if distance > 150.0 and distance < profile.length - 150.0:
			slowest = minf(slowest, speed)
		if i > 0:
			expect(profile.times[i] > profile.times[i - 1], "profile times must increase")
			if profile.times[i] <= profile.times[i - 1]:
				break
	note("profile: fastest %.1f m/s, slowest corner %.1f m/s, stage time %.1f s" % [
			fastest, slowest, car.expected_time_at(profile.length)])
	expect(fastest <= car.top_speed + 0.01, "the profile exceeds the top speed")
	expect(slowest < fastest * 0.7, "corners should be clearly slower than straights")

	# Braking: the profile never needs more deceleration than the car has.
	var worst_decel := 0.0
	for i in range(1, profile.speeds.size()):
		var decel := (profile.speeds[i - 1] ** 2 - profile.speeds[i] ** 2) / (2.0 * profile.step)
		worst_decel = maxf(worst_decel, decel)
	expect(worst_decel <= car.brake + 0.01, "the profile brakes harder than the car can (%.1f)" % worst_decel)

	car.start()
	var worst_height_error := 0.0
	for _second in 12:
		await physics_frames(100)
		var ground := world.get_ground_height(car.global_position)
		worst_height_error = maxf(worst_height_error, absf(car.global_position.y - ground))
	note("after 12 s the car covered %.0f m (%.1f m/s now)" % [car.distance, car.speed])
	expect(car.distance > 150.0, "the car did not make progress along the stage")
	note("largest gap between the car and the ground: %.2f m" % worst_height_error)
	expect(worst_height_error < 0.3, "the car floats or sinks into the road")

	await _check_car_hits_drone(world, car)
	await _check_car_finishes(car)


## A car running into a drone hovering low over the road is a crash, even though the drone
## itself was not moving.
func _check_car_hits_drone(world: StageWorld, car: RallyCar) -> void:
	var drone := (load("res://drone/drones/rally_drone.tscn") as PackedScene).instantiate() as Drone
	add_child(drone)
	# Drive on the centre line so the car cannot pass beside the small drone.
	var offset := car.max_lateral_offset
	car.max_lateral_offset = 0.0
	await physics_frames(2)
	var spot := world.builder.to_global(world.builder.driving_curve.sample_baked(car.distance + 90.0, true))
	drone.reset_to(Transform3D(Basis.IDENTITY, spot))
	await physics_frames(20)
	var fc := drone.flight_controller
	fc.select_flight_mode(FlightMode.Type.TRACK)
	fc.input.power = 0.5
	fc._on_arm_input()
	fc.set_tracking_target(drone.global_position + Vector3.UP * 0.8)
	# The crash must register on the impact itself, not later when the drone lands.
	var frames := {"contact": -1, "crash": -1}
	var _b := drone.body_entered.connect(func(body: Node) -> void:
		if body == car and frames["contact"] < 0:
			frames["contact"] = Engine.get_physics_frames())
	var _c := EventBus.drone_crashed.connect(func(_d: Drone, _s: float) -> void:
		if frames["crash"] < 0:
			frames["crash"] = Engine.get_physics_frames())
	for _i in 600:
		await get_tree().physics_frame
		if frames["crash"] >= 0:
			break
	note("car impact on physics frame %d, crash registered on frame %d" % [frames["contact"], frames["crash"]])
	expect(frames["contact"] >= 0, "the car should have hit the hovering drone")
	expect(frames["crash"] >= 0 and frames["crash"] - frames["contact"] <= 1,
			"a car hitting a hovering drone should count as a crash right away")
	car.max_lateral_offset = offset
	drone.queue_free()


func _check_car_finishes(car: RallyCar) -> void:
	var finished := [false]
	var _c := car.finished.connect(func() -> void: finished[0] = true)
	car.distance = car.profile.length - 60.0
	for _i in 2000:
		await get_tree().physics_frame
		if finished[0]:
			break
	note("finish: reached %.1f of %.1f m" % [car.distance, car.profile.length])
	expect(finished[0] and car.has_finished, "the car should reach the finish and emit finished")
