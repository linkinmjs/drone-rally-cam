## Loads the real stage and plays a compressed version of the Phase 1 loop: wait, deploy,
## take off, start the car, film it and get a graded clip.
extends HeadlessCheck


const STAGE_SCENE := preload("res://game/stage.tscn")


func run() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(60)

	var player := stage.player
	var ground := stage.world.get_ground_height(player.global_position)
	note("player spawned at %s, %.2f m above the ground" % [player.global_position, player.global_position.y - ground])
	expect(absf(player.global_position.y - ground) < 0.3, "the player should stand on the terrain")
	expect(stage.drone.is_stowed, "the drone starts packed")
	expect(stage.phase == Stage.Phase.WAITING_START, "the stage starts waiting for the car")

	# Walk to the road side: put the player next to a point of the road the car reaches early.
	var builder := stage.world.builder
	var road_point := builder.driving_curve.sample_baked(120.0)
	var next := builder.driving_curve.sample_baked(125.0)
	var side := (next - road_point).cross(Vector3.UP).normalized()
	var stand := road_point + side * 14.0
	stand.y = stage.world.get_ground_height(stand) + 0.05
	player.global_position = stand
	player.look_at(road_point, Vector3.UP)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	await physics_frames(10)

	var spot: Variant = player.find_deploy_spot()
	if not spot is Transform3D:
		# Rough ground next to the road: use the player's feet.
		spot = Transform3D(player.global_basis, player.global_position)
	expect(stage.control.deploy(spot), "deploying next to the road should work")
	await physics_frames(20)
	expect(stage.control.toggle_pilot(), "taking the controller should work")

	# Take off in Stabilized and climb a few meters.
	var fc := stage.drone.flight_controller
	var radio := stage.get_node("RadioController") as RadioController
	# The check drives the sticks directly instead of the radio.
	radio.set_physics_process(false)
	fc.input = FlightCommand.new()
	fc.input.power = 0.5
	fc._on_arm_input()
	expect(fc.state_armed, "the drone should arm")
	for _i in 150:
		fc.input.power = 0.9
		await get_tree().physics_frame
	for _i in 100:
		fc.input.power = 0.5
		await get_tree().physics_frame
	note("drone %.1f m above the ground" % fc.flight_state.ground_distance)
	expect(fc.flight_state.ground_distance > 2.0, "the drone should have taken off")

	# Point the camera at the road point and start the car.
	var gimbal := stage.drone.get_node("Gimbal") as Gimbal
	var to_road := road_point - gimbal.global_position
	gimbal.tilt = clampf(atan2(to_road.y, Vector2(to_road.x, to_road.z).length()), deg_to_rad(-89.0), 0.0)
	stage._countdown = 0.0
	await process_frames(2)
	expect(stage.phase == Stage.Phase.RACING and stage.world.car.running, "the car should be racing")

	# Record while the car passes the drone.
	var car := stage.world.car
	while car.distance < 60.0:
		await get_tree().physics_frame
	stage.recorder.start()
	var seen := 0
	while car.distance < 200.0 and car.running:
		await get_tree().physics_frame
		if stage.recorder.last_score > 0.0:
			seen += 1
	stage.recorder.stop()
	await process_frames(2)
	expect(stage.clips.size() == 1, "stopping the recording should deliver a clip")
	if stage.clips.size() == 1:
		var clip := stage.clips[0]
		note("clip: %.1f s, %d samples, grade %s, mean %.2f, %s" % [clip.duration, clip.sample_count(),
				clip.grade, clip.mean_score, clip.comment])
		expect(clip.sample_count() > 20, "the clip should have samples")
	note("the car scored in %d physics frames while passing" % seen)
	expect(seen > 0, "the car should have been in the shot at some point")
