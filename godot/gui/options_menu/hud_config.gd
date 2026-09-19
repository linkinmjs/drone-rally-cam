# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: Drone Rally Cam
# presets and toggles; the preview is the real viewfinder, rendered at 1920x1080 and scaled.
extends HBoxContainer
## HUD settings with a live preview. Every change is written to GameSettings.hud_config;
## the preview HUD (and the in-flight HUD) listen to `hud_config_updated`.


const TOGGLES := {
	"CheckCrosshair": "crosshair",
	"CheckHorizon": "horizon",
	"CheckLadder": "ladder",
	"CheckHeading": "heading",
	"CheckSpeed": "speed",
	"CheckAltitude": "altitude",
	"CheckDistance": "distance",
	"CheckFlightMode": "flight_mode",
	"CheckStatus": "status",
	"CheckSticks": "sticks",
	"CheckGimbal": "gimbal",
	"CheckPilotGuide": "pilot_guide",
	"CheckScoreBars": "score_bars",
	"CheckThirds": "thirds",
	"CheckCarMarker": "car_marker",
}

@onready var fps := %SliderRefreshRate as HSlider
@onready var fps_value := %ValueRefreshRate as Label
@onready var preset := %PresetOptions as OptionButton
@onready var horizon_mode := %HorizonModeOptions as OptionButton
@onready var preview := $Preview as PanelContainer

## The viewfinder shown in the preview (the same one used while flying).
var visor: DroneVisor = null

var _buttons := {}
var _updating := false


func _ready() -> void:
	($Preview as Control).clip_contents = true
	GameSettings.load_hud_config()

	preset.add_item("HUD_PRESET_CINE")
	preset.add_item("HUD_PRESET_PILOT")
	preset.add_item("HUD_PRESET_FULL")
	preset.add_item("HUD_PRESET_CUSTOM")
	preset.set_item_disabled(GameSettings.HudPreset.CUSTOM, true)
	var _discard := preset.item_selected.connect(_on_preset_selected)

	horizon_mode.add_item("HUD_HORIZON_CAMERA")
	horizon_mode.add_item("HUD_HORIZON_ATTITUDE")
	_discard = horizon_mode.item_selected.connect(_on_horizon_mode_selected)

	_discard = fps.value_changed.connect(_on_hud_fps_changed)

	for node_name: String in TOGGLES:
		var button := get_node("%" + node_name) as CheckButton
		_buttons[TOGGLES[node_name]] = button
		_discard = button.toggled.connect(_on_button_toggled.bind(TOGGLES[node_name]))

	_refresh()
	_build_preview()


## The viewfinder at its real resolution in a SubViewport, scaled into the preview panel, so
## what is seen here is exactly the in-flight layout.
func _build_preview() -> void:
	var viewport := SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.size = Vector2i(1920, 1080)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	visor = DroneVisor.new()
	visor.name = "PreviewVisor"
	viewport.add_child(visor)
	visor.setup_preview()
	var texture := TextureRect.new()
	texture.texture = viewport.get_texture()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(texture)


func _refresh() -> void:
	_updating = true
	fps.value = GameSettings.hud_config["fps"]
	fps_value.text = "%d Hz" % [int(fps.value)]
	horizon_mode.select(1 if GameSettings.hud_config["horizon_mode"] == "attitude" else 0)
	for key: String in _buttons:
		(_buttons[key] as CheckButton).set_pressed_no_signal(bool(GameSettings.hud_config[key]))
	preset.select(GameSettings.get_hud_preset())
	_updating = false


func _on_hud_fps_changed(value: float) -> void:
	fps_value.text = "%d Hz" % [int(value)]
	if _updating:
		return
	GameSettings.hud_config["fps"] = int(value)
	GameSettings.save_hud_config()


func _on_button_toggled(button_pressed: bool, key: String) -> void:
	if _updating:
		return
	GameSettings.hud_config[key] = button_pressed
	GameSettings.save_hud_config()
	preset.select(GameSettings.get_hud_preset())


func _on_preset_selected(idx: int) -> void:
	if idx == GameSettings.HudPreset.CUSTOM:
		return
	GameSettings.apply_hud_preset(idx as GameSettings.HudPreset)
	_refresh()


func _on_horizon_mode_selected(idx: int) -> void:
	GameSettings.hud_config["horizon_mode"] = "attitude" if idx == 1 else "camera"
	GameSettings.save_hud_config()
