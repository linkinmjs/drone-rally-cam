## Piloting views and the flight HUD: taking the controller starts on the gimbal, the camera
## button switches to the pilot camera and back, recording keeps using the gimbal, and the
## HUD gets the height above the ground, the armed state and the preset toggles.
extends HeadlessCheck


const STAGE_SCENE := preload("res://game/stage.tscn")


func run() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(30)
	var control := stage.control
	var drone := stage.drone
	var fc := drone.flight_controller
	var visor := stage.visor
	var hud := visor.hud
	var gimbal := drone.get_node("Gimbal") as Gimbal
	var pilot_camera := drone.get_node("PilotCamera") as PilotCamera

	expect(not control.change_camera(), "the camera cannot change while walking")
	var spot := Transform3D(stage.player.global_basis, stage.player.global_position
			- stage.player.global_basis.z * 2.0)
	expect(control.deploy(spot), "the drone deploys")
	await physics_frames(20)
	expect(fc.flight_mode is FlightModeTrack, "deploying selects the default mode (Stabilized)")
	expect(control.toggle_pilot(), "taking the controller works")
	await process_frames(3)
	expect(control.view == ControlState.View.GIMBAL, "piloting starts on the gimbal")
	expect(gimbal.camera.current, "the gimbal camera is current")
	expect(visor.visible, "the viewfinder is shown while piloting")
	expect(hud.horizon.mode == "camera" and hud.horizon.camera == gimbal.camera,
			"the gimbal view draws the real horizon of the gimbal camera (%s)" % hud.horizon.mode)
	expect(hud.readouts.show_gimbal, "the gimbal view shows the gimbal tilt")

	await action(&"change_camera")
	await process_frames(3)
	expect(control.view == ControlState.View.PILOT, "change_camera switches to the pilot view")
	expect(pilot_camera.current, "the pilot camera is current")
	expect(pilot_camera.cull_mask & Gimbal.DRONE_BODY_LAYER == 0, "the pilot camera hides the drone body")
	expect(hud.horizon.mode == str(GameSettings.hud_config["horizon_mode"]),
			"the pilot view draws the horizon from the settings (%s)" % hud.horizon.mode)
	expect(hud.horizon.camera == pilot_camera, "the horizon follows the pilot camera")
	expect(stage.recorder.camera == gimbal.camera, "recording keeps using the gimbal")
	var tilt := rad_to_deg(pilot_camera.transform.basis.get_euler().x)
	note("pilot camera tilt %.1f deg, fov %.0f" % [tilt, pilot_camera.fov])
	expect(absf(tilt - QuadSettings.angle) < 0.5, "the pilot camera uses the angle from Options > Drone")

	# The HUD gets the height above the ground and the sticks.
	var radio := stage.get_node("RadioController") as RadioController
	radio.set_physics_process(false)
	fc.input = FlightCommand.new()
	fc.input.power = 1.0
	fc.input.roll = 0.5
	await process_frames(3)
	note("HUD height %.2f m, ground distance %.2f m" % [hud.latest_position.y, fc.flight_state.ground_distance])
	expect(absf(hud.latest_position.y - fc.flight_state.ground_distance) < 0.05,
			"the HUD shows the height above the ground")
	expect(hud.latest_left_stick.y < -0.9 and absf(hud.latest_right_stick.x - 0.5) < 0.01,
			"the HUD sticks follow the radio")

	# Arming with the throttle up is refused with a message.
	fc._on_arm_input()
	await process_frames(2)
	note("status: %s" % hud.status.text)
	expect(not fc.state_armed, "the drone does not arm with the throttle up")
	expect(hud.status.text.contains(tr("HUD_STATUS_THROTTLE_TO_CENTER")),
			"Stabilized asks for the throttle in the centre")
	fc.input.power = 0.5
	fc.input.roll = 0.0
	fc._on_arm_input()
	await process_frames(2)
	expect(fc.state_armed and hud.status.text == tr("HUD_STATUS_ARMED"), "arming shows ARMADO")
	fc._on_disarm_input()

	# Presets.
	GameSettings.apply_hud_preset(GameSettings.HudPreset.CINE)
	await process_frames(1)
	expect(not hud.sticks.visible and not hud.readouts.visible, "the Cine preset hides sticks and numbers")
	GameSettings.apply_hud_preset(GameSettings.HudPreset.FULL)
	await process_frames(1)
	expect(hud.sticks.visible and hud.readouts.show_heading and hud.horizon.show_ladder,
			"the Full preset shows everything (heading and pitch ladder included)")
	GameSettings.reset_to_defaults()

	# Letting go of the controller and taking it again starts on the gimbal.
	expect(control.toggle_pilot(), "releasing the controller works")
	await process_frames(2)
	expect(stage.player.camera.current, "the player's camera is back")
	expect(control.toggle_pilot(), "taking the controller again works")
	await process_frames(2)
	expect(control.view == ControlState.View.GIMBAL and gimbal.camera.current, "back on the gimbal")
