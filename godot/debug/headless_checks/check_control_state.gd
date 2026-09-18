## Walking, deploying, piloting and recovering the drone through ControlState.
extends HeadlessCheck


const PLAYER_SCENE := preload("res://player/player.tscn")
const DRONE_SCENE := preload("res://drone/drones/rally_drone.tscn")


func run() -> void:
	add_floor()
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	var drone := DRONE_SCENE.instantiate() as Drone
	drone.name = "Drone"
	add_child(drone)
	var radio := RadioController.new()
	radio.name = "Radio"
	radio.target_path = NodePath("../Drone")
	radio.enabled = false
	add_child(radio)
	var recorder := Recorder.new()
	recorder.name = "Recorder"
	add_child(recorder)
	var control := ControlState.new()
	control.player_path = NodePath("../%s" % player.name)
	control.drone_path = NodePath("../Drone")
	control.radio_path = NodePath("../Radio")
	control.recorder_path = NodePath("../Recorder")
	add_child(control)
	recorder.setup(drone, null)
	drone.stow()
	await physics_frames(30)

	expect(control.state == ControlState.State.WALKING_NO_DRONE, "the game starts walking with the drone packed")
	expect(not control.toggle_pilot(), "there is nothing to pilot before deploying")

	var spot: Variant = player.find_deploy_spot()
	expect(spot is Transform3D, "flat ground in front of the player should accept the case")
	if not spot is Transform3D:
		return
	expect(control.deploy(spot), "deploying should work while walking with the kit")
	await physics_frames(30)
	expect(control.state == ControlState.State.WALKING_DRONE_DEPLOYED, "deploying should leave the drone on the ground")
	expect(not drone.is_stowed and drone.visible, "the deployed drone should be in the world")
	expect(not player.has_kit, "the player no longer carries the kit")
	var drone_distance := player.global_position.distance_to(drone.global_position)
	note("drone set down %.1f m from the player, %.2f m above the floor" % [drone_distance, drone.global_position.y])
	expect(drone_distance < control.recover_distance, "the drone should be set down within reach")

	expect(control.toggle_pilot(), "taking the controller should work with the drone deployed")
	expect(control.state == ControlState.State.PILOTING, "should be piloting")
	expect(radio.enabled and not player.active, "piloting enables the radio and freezes the player")
	expect(drone.get_node("Gimbal/Camera3D").is_current(), "piloting shows the drone camera")

	drone.flight_controller.input.power = 0.5
	drone.flight_controller._on_arm_input()
	expect(drone.flight_controller.state_armed, "the drone should arm in Stabilized")
	drone.flight_controller.select_flight_mode(FlightMode.Type.HORIZON)
	expect(control.toggle_pilot(), "letting go of the controller should work")
	expect(drone.flight_controller.flight_mode is FlightModeTrack, "letting go switches the drone to position hold")
	expect(not radio.enabled and player.active, "walking disables the radio")
	expect(player.camera.is_current(), "walking shows the player's eyes")
	expect(not control.recover(), "an armed drone cannot be packed")

	drone.flight_controller._on_disarm_input()
	var home := player.global_position
	player.global_position = home + Vector3(30, 0, 0)
	await physics_frames(5)
	expect(not control.recover(), "a drone far away cannot be packed")
	player.global_position = home
	await physics_frames(5)
	expect(control.recover(), "a landed drone within reach can be packed")
	expect(control.state == ControlState.State.WALKING_NO_DRONE and player.has_kit and drone.is_stowed,
			"recovering packs the drone and gives the kit back")

	# Steep ground refuses the case.
	var slope := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	shape.shape = box
	slope.add_child(shape)
	add_child(slope)
	slope.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(30.0)), player.global_position + Vector3(0, 0.5, -2))
	await physics_frames(3)
	expect(player.find_deploy_spot() is String, "a 30 deg slope should refuse the case")
