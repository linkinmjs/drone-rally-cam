# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: no language,
# sky, tutorial or challenge settings; adds the stick deadzone and the Drone Rally Cam HUD
# presets (Cine, Piloto, Completo).
extends Node


signal hud_config_updated
signal game_settings_updated

enum HudPreset {CINE, PILOT, FULL, CUSTOM}

const LANGUAGE := "es"
## Default menu navigation with the sticks: StickNavigation.Scheme.GAMEPAD. Written as a number
## because this autoload is created before StickNavigation.
const STICK_NAV_DEFAULT := 2
const STICK_NAV_MAX := 2
## Version of the saved HUD settings. 2: no RPM or side tapes, distance and gimbal rows, car
## marker on by default (a version 1 file keeps its other toggles but not the car marker).
const HUD_CONFIG_VERSION := 2
const HUD_OBSOLETE_KEYS: Array[String] = ["rpm", "side_tapes"]
const HUD_BOOL_KEYS: Array[String] = ["crosshair", "horizon", "ladder", "speed", "altitude",
		"heading", "sticks", "flight_mode", "status", "distance", "gimbal", "car_marker",
		"pilot_guide", "score_bars", "thirds"]
## Cine: only what a camera operator needs. Piloto: plus the flight aids of the simulator
## (the default). Completo: everything, pitch ladder and heading included.
const HUD_PRESETS := [
	{"crosshair": false, "horizon": false, "ladder": false, "speed": false, "altitude": false,
			"heading": false, "sticks": false, "flight_mode": false, "status": false,
			"distance": false, "gimbal": false, "car_marker": false, "pilot_guide": false,
			"score_bars": true, "thirds": true},
	{"crosshair": true, "horizon": true, "ladder": false, "speed": true, "altitude": true,
			"heading": false, "sticks": true, "flight_mode": true, "status": true,
			"distance": true, "gimbal": true, "car_marker": true, "pilot_guide": true,
			"score_bars": true, "thirds": true},
	{"crosshair": true, "horizon": true, "ladder": true, "speed": true, "altitude": true,
			"heading": true, "sticks": true, "flight_mode": true, "status": true,
			"distance": true, "gimbal": true, "car_marker": true, "pilot_guide": true,
			"score_bars": true, "thirds": true},
]

var game_settings_path := "%s/GameSettings.cfg" % [Controls.CONFIG_DIR]

var hud_config := {"fps": 10, "horizon_mode": "camera"}

## `stick_nav`: how the sticks drive the menus (StickNavigation.Scheme). It replaced
## `nav_scheme`, whose saved 0 (Betaflight) must not carry over now that gamepads have their
## own scheme. `stick_deadzone`: radial deadzone of the flight sticks (gamepads rest a few
## percent off-centre; 0 for a real radio). `menu_blur`: the scene behind the menus is
## blurred (it reads the screen; the graphics options of plan 07 expose it).
var game_config := {"stick_nav": STICK_NAV_DEFAULT, "stick_deadzone": 0.08, "menu_blur": true}


func _init() -> void:
	var defaults: Dictionary = HUD_PRESETS[HudPreset.PILOT]
	for key: String in defaults:
		hud_config[key] = defaults[key]


func _ready() -> void:
	load_game_settings()
	load_hud_config()


func load_game_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK and config.has_section("game"):
		for key: String in game_config.keys():
			if config.has_section_key("game", key):
				game_config[key] = config.get_value("game", key)
	game_config["stick_deadzone"] = clampf(float(game_config["stick_deadzone"]), 0.0, 0.25)
	apply_game_settings()


func save_game_settings() -> void:
	_ensure_config_dir()
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK or err == ERR_FILE_NOT_FOUND or err == ERR_PARSE_ERROR:
		for key: String in game_config.keys():
			config.set_value("game", key, game_config[key])
		if config.has_section_key("game", "nav_scheme"):
			config.erase_section_key("game", "nav_scheme")
		err = config.save(game_settings_path)
	if err != OK:
		push_error("Error while saving game settings: %s" % [error_string(err)])
	game_settings_updated.emit()


func apply_game_settings() -> void:
	TranslationServer.set_locale(LANGUAGE)
	# StickNavigation is registered after this autoload: it reads the scheme itself
	# in its _ready, and later changes are pushed from here.
	var stick_navigation := get_node_or_null(^"/root/StickNavigation")
	if stick_navigation:
		stick_navigation.set(&"scheme", get_nav_scheme())


func get_nav_scheme() -> int:
	return clampi(int(game_config["stick_nav"]), 0, STICK_NAV_MAX)


func set_nav_scheme(scheme: int) -> void:
	game_config["stick_nav"] = clampi(scheme, 0, STICK_NAV_MAX)
	apply_game_settings()
	save_game_settings()


func get_stick_deadzone() -> float:
	return float(game_config["stick_deadzone"])


func set_stick_deadzone(value: float) -> void:
	game_config["stick_deadzone"] = clampf(value, 0.0, 0.25)
	save_game_settings()


func menu_blur_enabled() -> bool:
	return bool(game_config["menu_blur"])


func set_menu_blur(enabled: bool) -> void:
	game_config["menu_blur"] = enabled
	save_game_settings()


func load_hud_config() -> void:
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK:
		var hud_section := "hud_config"
		if config.has_section(hud_section):
			var version := int(config.get_value(hud_section, "version", 1))
			for key in config.get_section_keys(hud_section):
				var value: Variant = config.get_value(hud_section, key)
				if key == "car_marker" and version < 2:
					continue
				if hud_config.has(key):
					if key == "fps" and (value is int or value is float):
						hud_config[key] = clampf(value, 5, 60) as int
					elif key == "horizon_mode" and value is String:
						hud_config[key] = "attitude" if value == "attitude" else "camera"
					elif value is bool:
						hud_config[key] = value
	elif err != ERR_FILE_NOT_FOUND:
		push_error("Error while loading the HUD settings: %s" % [error_string(err)])
	hud_config_updated.emit()


func save_hud_config() -> void:
	_ensure_config_dir()
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK or err == ERR_FILE_NOT_FOUND or err == ERR_PARSE_ERROR:
		for key: String in hud_config.keys():
			config.set_value("hud_config", key, hud_config[key])
		for key in HUD_OBSOLETE_KEYS:
			if config.has_section_key("hud_config", key):
				config.erase_section_key("hud_config", key)
		config.set_value("hud_config", "version", HUD_CONFIG_VERSION)
		err = config.save(game_settings_path)
	if err != OK:
		push_error("Error while saving the HUD settings: %s" % [error_string(err)])
	hud_config_updated.emit()


func apply_hud_preset(preset: HudPreset) -> void:
	if preset < 0 or preset >= HUD_PRESETS.size():
		return
	var values: Dictionary = HUD_PRESETS[preset]
	for key: String in values:
		hud_config[key] = values[key]
	save_hud_config()


func get_hud_preset() -> HudPreset:
	for i in HUD_PRESETS.size():
		var values: Dictionary = HUD_PRESETS[i]
		var matches := true
		for key: String in values:
			if bool(hud_config[key]) != bool(values[key]):
				matches = false
				break
		if matches:
			return i as HudPreset
	return HudPreset.CUSTOM


## Restores the defaults in memory, without saving (used by the automated checks).
func reset_to_defaults() -> void:
	game_config = {"stick_nav": STICK_NAV_DEFAULT, "stick_deadzone": 0.08, "menu_blur": true}
	var defaults: Dictionary = HUD_PRESETS[HudPreset.PILOT]
	for key: String in defaults:
		hud_config[key] = defaults[key]
	hud_config["fps"] = 10
	hud_config["horizon_mode"] = "camera"
	hud_config_updated.emit()
	game_settings_updated.emit()


func _ensure_config_dir() -> void:
	var _err := DirAccess.make_dir_recursive_absolute(Controls.CONFIG_DIR)
