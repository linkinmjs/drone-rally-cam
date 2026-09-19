## Runs every headless check in sequence and exits with code 1 if any failed.
extends Node


const CHECKS: Array[String] = [
	"res://debug/headless_checks/check_load.gd",
	"res://debug/headless_checks/check_drone.gd",
	"res://debug/headless_checks/check_car.gd",
	"res://debug/headless_checks/check_input.gd",
	"res://debug/headless_checks/check_gimbal_battery.gd",
	"res://debug/headless_checks/check_scorer.gd",
	"res://debug/headless_checks/check_control_state.gd",
	"res://debug/headless_checks/check_stage.gd",
	"res://debug/headless_checks/check_gui.gd",
	"res://debug/headless_checks/check_settings.gd",
	"res://debug/headless_checks/check_pilot_view.gd",
	"res://debug/headless_checks/check_stage_info.gd",
	"res://debug/headless_checks/check_scoring_ui.gd",
	"res://debug/headless_checks/check_gamepad_nav.gd",
	"res://debug/headless_checks/check_visor.gd",
	"res://debug/headless_checks/check_theme.gd",
	"res://debug/headless_checks/check_flow.gd",
	"res://debug/headless_checks/check_world_presentation.gd",
]

## The checks read and write their settings here, never in the player's user://config.
const TEST_CONFIG_DIR := "user://headless_checks"


func _ready() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")

	_isolate_settings()
	var failed: PackedStringArray = []
	var ran := 0
	for path in CHECKS:
		var check_name := path.get_file().get_basename()
		if not only.is_empty() and not check_name.contains(only):
			continue
		ran += 1
		print("[%s]" % check_name)
		var script := load(path) as GDScript
		if not script or not script.can_instantiate():
			failed.append(check_name)
			print("  FAILED: the check does not compile")
			continue
		var check := script.new() as HeadlessCheck
		check.name = check_name
		add_child(check)
		var start := Time.get_ticks_msec()
		await check.run()
		var elapsed := (Time.get_ticks_msec() - start) / 1000.0
		if check.failures.is_empty():
			print("  ok (%.1f s)" % elapsed)
		else:
			failed.append(check_name)
			print("  FAILED: %d problem(s)" % check.failures.size())
		check.queue_free()
		get_tree().paused = false
		# Let the audio thread release the streams the check was playing. With --fixed-fps
		# frames run faster than real time, so wait on the clock rather than on frames.
		var freed_at := Time.get_ticks_msec()
		while Time.get_ticks_msec() - freed_at < 300:
			await get_tree().process_frame

	print("")
	if failed.is_empty():
		print("All %d checks passed." % ran)
		get_tree().quit(0)
	else:
		print("Failed checks: %s" % ", ".join(failed))
		get_tree().quit(1)


## Points every settings file at a scratch folder and restores the defaults in memory, so the
## developer's own settings (rates, dead zone, bindings) never change the results.
func _isolate_settings() -> void:
	var _err := DirAccess.make_dir_recursive_absolute(TEST_CONFIG_DIR)
	for file in DirAccess.get_files_at(TEST_CONFIG_DIR):
		_err = DirAccess.remove_absolute(TEST_CONFIG_DIR.path_join(file))
	Controls.input_map_path = TEST_CONFIG_DIR.path_join("InputMap.cfg")
	Audio.audio_settings_path = TEST_CONFIG_DIR.path_join("Audio.cfg")
	GameSettings.game_settings_path = TEST_CONFIG_DIR.path_join("GameSettings.cfg")
	QuadSettings.quad_settings_path = TEST_CONFIG_DIR.path_join("Quad.cfg")
	Progress.save_path = TEST_CONFIG_DIR.path_join("progress.tres")
	Progress.reset()
	InputMap.load_from_project_settings()
	GameSettings.reset_to_defaults()
	QuadSettings.reset_quad()
	QuadSettings.control_profile = ControlProfile.new()
	QuadSettings.settings_updated.emit()
