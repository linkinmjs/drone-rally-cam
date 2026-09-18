## Options > Drone and Options > Controls: the settings survive a save and load, and the drone
## flies with them (rates, weight, default flight mode). check_all points the files at a
## scratch folder, so this never touches the player's own settings.
extends HeadlessCheck


const DRONE_SCENE := preload("res://drone/drones/rally_drone.tscn")


func run() -> void:
	expect(QuadSettings.quad_settings_path.begins_with("user://headless_checks"),
			"the check should write to the scratch folder (%s)" % QuadSettings.quad_settings_path)
	if not QuadSettings.quad_settings_path.begins_with("user://headless_checks"):
		return

	# Save, change in memory, load: the saved values come back.
	QuadSettings.angle = 30
	QuadSettings.fov = 95
	QuadSettings.dry_weight = 0.6
	QuadSettings.default_mode = FlightMode.Type.ACRO
	QuadSettings.control_profile.roll_rate = 540
	QuadSettings.control_profile.pitch_expo = 0.4
	QuadSettings.save_quad_settings()
	QuadSettings.reset_quad()
	QuadSettings.control_profile.roll_rate = 300
	QuadSettings.control_profile.pitch_expo = 0.0
	QuadSettings.load_quad_settings()
	expect(QuadSettings.angle == 30, "camera angle should load (%d)" % QuadSettings.angle)
	expect(QuadSettings.fov == 95, "field of view should load (%d)" % QuadSettings.fov)
	expect(is_equal_approx(QuadSettings.dry_weight, 0.6), "dry weight should load")
	expect(QuadSettings.default_mode == FlightMode.Type.ACRO, "default mode should load")
	expect(QuadSettings.control_profile.roll_rate == 540, "roll rate should load")
	expect(is_equal_approx(QuadSettings.control_profile.pitch_expo, 0.4), "pitch expo should load")

	GameSettings.set_stick_deadzone(0.15)
	GameSettings.game_config["stick_deadzone"] = 0.0
	GameSettings.load_game_settings()
	expect(is_equal_approx(GameSettings.get_stick_deadzone(), 0.15),
			"stick dead zone should load (%.2f)" % GameSettings.get_stick_deadzone())
	GameSettings.set_stick_deadzone(0.5)
	expect(is_equal_approx(GameSettings.get_stick_deadzone(), 0.25), "the dead zone is capped at 25 %")

	# A drone takes the settings when it spawns and when they change.
	var drone := DRONE_SCENE.instantiate() as Drone
	add_child(drone)
	await physics_frames(3)
	var fc := drone.flight_controller
	note("mass %.2f kg, hover thrust %.2f N per motor, default mode %s" % [drone.mass, fc.hover_thrust,
			FlightMode.Type.keys()[fc.default_mode]])
	expect(fc.control_profile == QuadSettings.control_profile, "the drone flies with the saved rates")
	expect(is_equal_approx(drone.mass, 0.6 + QuadSettings.battery_weight), "the drone weighs dry + battery")
	expect(fc.default_mode == FlightMode.Type.ACRO, "the drone starts in the saved default mode")
	expect(fc.flight_mode_idx == FlightMode.Type.ACRO, "the drone selects the default mode on start")

	QuadSettings.default_mode = FlightMode.Type.HORIZON
	QuadSettings.dry_weight = 0.5
	QuadSettings.settings_updated.emit()
	expect(fc.default_mode == FlightMode.Type.HORIZON, "changing the default mode reaches the drone")
	expect(is_equal_approx(drone.mass, 0.5 + QuadSettings.battery_weight), "changing the weight reaches the drone")
	expect(is_equal_approx(fc.hover_thrust, drone.mass / 4.0 * 9.81), "hover thrust follows the weight")

	# Options > Controls lists the game's actions with translated names.
	var names: PackedStringArray = []
	for controller_action in Controls.action_list:
		names.append(controller_action.action_name)
		expect(InputMap.has_action(controller_action.action_name),
				"listed action %s should exist" % controller_action.action_name)
		expect(tr(controller_action.action_label) != controller_action.action_label,
				"%s should have a translated label" % controller_action.action_label)
	for required in ["toggle_arm", "cycle_flight_modes", "rec_toggle", "change_camera", "pilot_toggle",
			"respawn", "show_map", "gimbal_up", "gimbal_down"]:
		expect(required in names, "Options > Controls should list %s" % required)

	drone.queue_free()
	GameSettings.reset_to_defaults()
	QuadSettings.reset_quad()
	QuadSettings.control_profile = ControlProfile.new()
	QuadSettings.settings_updated.emit()
