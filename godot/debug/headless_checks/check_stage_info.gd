## What the player needs to know on the stage: where the car will pass and when (tablet map,
## radio countdown and splits), the checklist of steps, and the marker on the deployed drone.
extends HeadlessCheck


const STAGE_SCENE := preload("res://game/stage.tscn")


func run() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(30)
	var announcements: PackedStringArray = []
	var _discard := stage.hud.radio_feed.announced.connect(func(text: String) -> void: announcements.append(text))

	expect(stage.tablet.is_open, "the tablet opens with the briefing at the start")
	note("briefing: %s" % stage.briefing().get_slice("\n", 0))
	await action(&"show_map")
	expect(not stage.tablet.is_open, "show_map closes the tablet while walking")
	await action(&"show_map")
	expect(stage.tablet.is_open, "show_map opens it again")
	await process_frames(2)
	var start_on_map := stage.tablet._map.to_map(stage.world.car.global_position)
	expect(Rect2(Vector2.ZERO, stage.tablet._map.size).has_point(start_on_map),
			"the car's start is inside the map (%s in %s)" % [start_on_map, stage.tablet._map.size])

	# Far from the road the first step is to find a spot.
	var builder := stage.world.builder
	var player := stage.player
	var far := Vector3(builder.size * 0.45, 0.0, builder.size * 0.45)
	far.y = stage.world.get_ground_height(far) + 0.05
	player.global_position = far
	await physics_frames(5)
	await process_frames(30)
	note("far spot: %.0f m from the road" % stage.reference_road_distance())
	if stage.reference_road_distance() > Stage.NEAR_ROAD:
		expect(stage.checklist_step() == 0, "far from the road the checklist asks for a spot")

	# Next to the road, 120 m after the start.
	var road_point := builder.to_global(builder.driving_curve.sample_baked(120.0))
	var next := builder.to_global(builder.driving_curve.sample_baked(125.0))
	var side := (next - road_point).cross(Vector3.UP).normalized()
	var stand := road_point + side * 12.0
	stand.y = stage.world.get_ground_height(stand) + 0.05
	player.global_position = stand
	player.look_at(Vector3(road_point.x, stand.y, road_point.z), Vector3.UP)
	await physics_frames(40)
	var offset := stage.reference_route_offset()
	note("player's spot on the road: %.1f m (expected about 120)" % offset)
	expect(absf(offset - 120.0) < 15.0, "the player's spot on the road should be near 120 m")
	note("next to the road: %.1f m from its centre" % stage.reference_road_distance())
	expect(absf(stage.reference_road_distance() - 12.0) < 2.0, "the distance to the road is measured")
	expect(stage.checklist_step() == 1, "next to the road the checklist asks to deploy the drone")
	expect(stage.hud.get_checklist_line(0).begins_with("✓"), "the first step is ticked")

	# Deploy: the drone marker shows it within reach.
	var spot := Transform3D(player.global_basis, player.global_position - player.global_basis.z * 1.8)
	expect(stage.control.deploy(spot), "the drone deploys")
	await physics_frames(20)
	await process_frames(2)
	expect(stage.checklist_step() == 2, "with the drone out the checklist asks to take control and arm")
	var head := player.get_node("Head") as Node3D
	head.rotation.x = deg_to_rad(-35.0)
	await process_frames(3)
	var marker := stage.hud.drone_marker
	note("drone marker: '%s', on screen %s" % [marker.text, marker.is_on_screen])
	expect(marker.visible and marker.text.ends_with("al alcance"), "the drone marker says it is within reach")
	expect(marker.is_on_screen, "the drone in front of the player is marked on screen")

	# Take control and arm.
	expect(stage.control.toggle_pilot(), "taking the controller works")
	expect(not stage.tablet.is_open, "the tablet closes when piloting")
	var fc := stage.drone.flight_controller
	var radio := stage.get_node("RadioController") as RadioController
	radio.set_physics_process(false)
	fc.input = FlightCommand.new()
	fc.input.power = 0.5
	fc._on_arm_input()
	await process_frames(2)
	expect(stage.checklist_step() == 3, "armed, the checklist asks to film the car")

	# The countdown to the drone's spot while waiting and racing.
	var drone_spot := stage.reference_route_offset()
	var eta_waiting := stage.seconds_until_car_at(drone_spot)
	stage._countdown = 0.3
	await physics_frames(40)
	expect(stage.phase == Stage.Phase.RACING, "the car started")
	var eta_racing := stage.seconds_until_car_at(drone_spot)
	note("car at the drone's spot in %.1f s while waiting, %.1f s once racing" % [eta_waiting, eta_racing])
	expect(eta_racing > 0.0 and eta_racing < eta_waiting, "the countdown goes down")
	var car := stage.world.car
	while car.distance < 330.0 and car.running:
		await get_tree().physics_frame
	await process_frames(2)
	expect(stage.seconds_until_car_at(drone_spot) < 0.0, "once past, the countdown is over")
	note("radio: %s" % " | ".join(announcements))
	var joined := " | ".join(announcements)
	expect(joined.contains("Largó"), "the radio announces the start")
	expect(joined.contains("km %s" % HudStyle.decimal(0.3)), "the radio announces the split at 300 m")
	expect(joined.contains("pasó por tu punto"), "the radio says the car went past")

	# A delivered clip moves the checklist to landing and packing.
	stage.clips.append(ShotReport.new())
	await process_frames(1)
	expect(stage.checklist_step() == 4, "after a clip the checklist asks to pack the drone")
	fc._on_disarm_input()
	expect(stage.control.toggle_pilot(), "releasing the controller works")
	player.global_position = stage.drone.global_position + Vector3(1.0, 0.0, 0.0)
	await physics_frames(5)
	expect(stage.control.recover(), "the drone packs")
	expect(stage.checklist_step() == Stage.CHECKLIST.size(), "everything is ticked")
