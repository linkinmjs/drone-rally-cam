# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: default flight mode,
# rectilinear pilot camera field of view.
extends MenuScreen


## Help texts shown as tooltips (translation keys). The rate ones depend on the selected
## curve, because the three sliders change meaning with it.
const HELP_RATES := {
	ControlProfile.RateCurve.ACTUAL: ["QUAD_HELP_ACTUAL_RATE", "QUAD_HELP_ACTUAL_RC", "QUAD_HELP_ACTUAL_EXPO"],
	ControlProfile.RateCurve.RACEFLIGHT: ["QUAD_HELP_RACEFLIGHT_RATE", "QUAD_HELP_RACEFLIGHT_RC",
			"QUAD_HELP_RACEFLIGHT_EXPO"],
	ControlProfile.RateCurve.KISS: ["QUAD_HELP_KISS_RATE", "QUAD_HELP_KISS_RC", "QUAD_HELP_KISS_EXPO"],
	ControlProfile.RateCurve.QUICKRATES: ["QUAD_HELP_QUICKRATES_RATE", "QUAD_HELP_QUICKRATES_RC",
			"QUAD_HELP_QUICKRATES_EXPO"],
}


## Modes offered as the default, in the order of the list.
const DEFAULT_MODES: Array[FlightMode.Type] = [FlightMode.Type.TRACK, FlightMode.Type.HORIZON,
		FlightMode.Type.ACRO]
const DEFAULT_MODE_NAMES: Array[String] = ["QUAD_MODE_STABILIZED", "QUAD_MODE_ATTITUDE",
		"QUAD_MODE_ACRO"]

@onready var default_mode_label := %DefaultModeLabel as Label
@onready var default_mode_options := %DefaultModeOptions as OptionButton
@onready var camera_angle_label := %CameraAngleLabel as Label
@onready var camera_angle_slider := %CameraAngleSlider as HSlider
@onready var camera_angle_spin := %CameraAngleCurrent as SpinBox
@onready var dry_weight_label := %DryWeightLabel as Label
@onready var dry_weight_slider := %DryWeightSlider as HSlider
@onready var dry_weight_spin := %DryWeightCurrent as SpinBox
@onready var battery_weight_label := %BatteryWeightLabel as Label
@onready var battery_weight_slider := %BatteryWeightSlider as HSlider
@onready var battery_weight_spin := %BatteryWeightCurrent as SpinBox
@onready var fov_label := %FovLabel as Label
@onready var fov_slider := %FovSlider as HSlider
@onready var fov_spin := %FovCurrent as SpinBox

@onready var rates_curve_label := %RatesCurveLabel as Label
@onready var rates_curve_list := %RatesCurveOptionButton as OptionButton
@onready var rate_label := %RateLabel as Label
@onready var rc_label := %RcLabel as Label
@onready var expo_label := %ExpoLabel as Label
@onready var pitch_label := %PitchLabel as Label
@onready var roll_label := %RollLabel as Label
@onready var yaw_label := %YawLabel as Label

@onready var pitch_rate_slider := %PitchRateSlider as HSlider
@onready var roll_rate_slider := %RollRateSlider as HSlider
@onready var yaw_rate_slider := %YawRateSlider as HSlider
@onready var pitch_rate_spin := %PitchRate as SpinBox
@onready var roll_rate_spin := %RollRate as SpinBox
@onready var yaw_rate_spin := %YawRate as SpinBox
@onready var pitch_rc_slider := %PitchRcSlider as HSlider
@onready var roll_rc_slider := %RollRcSlider as HSlider
@onready var yaw_rc_slider := %YawRcSlider as HSlider
@onready var pitch_rc_spin := %PitchRc as SpinBox
@onready var roll_rc_spin := %RollRc as SpinBox
@onready var yaw_rc_spin := %YawRc as SpinBox
@onready var pitch_expo_slider := %PitchExpoSlider as HSlider
@onready var roll_expo_slider := %RollExpoSlider as HSlider
@onready var yaw_expo_slider := %YawExpoSlider as HSlider
@onready var pitch_expo_spin := %PitchExpo as SpinBox
@onready var roll_expo_spin := %RollExpo as SpinBox
@onready var yaw_expo_spin := %YawExpo as SpinBox

@onready var rate_graph := %RateGraph as Control

@onready var button_reset_quad := %ButtonResetQuad as Button
@onready var button_reset_rates := %ButtonResetRates as Button
@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	initial_focus = default_mode_options
	focus_groups = [$PanelContainer/VBoxContainer/SettingsHBox/QuadScroll as Control,
			$PanelContainer/VBoxContainer/SettingsHBox/RatesScroll as Control,
			$PanelContainer/VBoxContainer/ButtonsHBox as Control]
	super()
	QuadSettings.load_quad_settings()

	for mode_name in DEFAULT_MODE_NAMES:
		default_mode_options.add_item(mode_name)
	default_mode_options.select(maxi(DEFAULT_MODES.find(QuadSettings.default_mode), 0))
	var _mode_discard := default_mode_options.item_selected.connect(_on_default_mode_selected)

	# Each spin box shares its range with the slider next to it: typing a value moves
	# the slider and dragging the slider updates the text, through a single signal.
	camera_angle_slider.share(camera_angle_spin)
	dry_weight_slider.share(dry_weight_spin)
	battery_weight_slider.share(battery_weight_spin)
	fov_slider.share(fov_spin)
	pitch_rate_slider.share(pitch_rate_spin)
	roll_rate_slider.share(roll_rate_spin)
	yaw_rate_slider.share(yaw_rate_spin)
	pitch_rc_slider.share(pitch_rc_spin)
	roll_rc_slider.share(roll_rc_spin)
	yaw_rc_slider.share(yaw_rc_spin)
	pitch_expo_slider.share(pitch_expo_spin)
	roll_expo_slider.share(roll_expo_spin)
	yaw_expo_slider.share(yaw_expo_spin)

	var _discard := camera_angle_slider.value_changed.connect(_on_angle_changed)
	camera_angle_slider.value = QuadSettings.angle

	_discard = dry_weight_slider.value_changed.connect(_on_dry_weight_changed)
	_discard = battery_weight_slider.value_changed.connect(_on_battery_weight_changed)
	dry_weight_slider.value = QuadSettings.dry_weight * 1000
	battery_weight_slider.value = QuadSettings.battery_weight * 1000
	_discard = fov_slider.value_changed.connect(_on_fov_changed)
	fov_slider.value = QuadSettings.fov

	rates_curve_list.clear()
	for item: String in ControlProfile.RateCurve.keys():
		rates_curve_list.add_item(item)
	rates_curve_list.select(QuadSettings.control_profile.rate_curve)
	_discard = rates_curve_list.item_selected.connect(_on_rate_curve_selected)

	_discard = pitch_rate_slider.value_changed.connect(_on_rate_changed.bind(pitch_rate_slider))
	_discard = roll_rate_slider.value_changed.connect(_on_rate_changed.bind(roll_rate_slider))
	_discard = yaw_rate_slider.value_changed.connect(_on_rate_changed.bind(yaw_rate_slider))
	_discard = pitch_rc_slider.value_changed.connect(_on_rc_changed.bind(pitch_rc_slider))
	_discard = roll_rc_slider.value_changed.connect(_on_rc_changed.bind(roll_rc_slider))
	_discard = yaw_rc_slider.value_changed.connect(_on_rc_changed.bind(yaw_rc_slider))
	_discard = pitch_expo_slider.value_changed.connect(_on_expo_changed.bind(pitch_expo_slider))
	_discard = roll_expo_slider.value_changed.connect(_on_expo_changed.bind(roll_expo_slider))
	_discard = yaw_expo_slider.value_changed.connect(_on_expo_changed.bind(yaw_expo_slider))

	_discard = button_reset_quad.pressed.connect(_on_reset_quad_pressed)
	_discard = button_reset_rates.pressed.connect(_on_reset_rates_pressed)
	bind_back_button(button_back)

	# Spin boxes stay editable with the mouse, but keyboard / gamepad / stick navigation
	# moves between the sliders (the spin box text field would trap up/down).
	for spin: SpinBox in [camera_angle_spin, dry_weight_spin, battery_weight_spin, fov_spin,
			pitch_rate_spin, roll_rate_spin, yaw_rate_spin, pitch_rc_spin, roll_rc_spin, yaw_rc_spin,
			pitch_expo_spin, roll_expo_spin, yaw_expo_spin]:
		spin.get_line_edit().focus_mode = Control.FOCUS_CLICK

	setup_help()
	update_rates_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		setup_help()
		update_rates_labels()


func _before_back() -> void:
	QuadSettings.save_quad_settings()


func setup_help() -> void:
	for control: Control in [default_mode_label, default_mode_options]:
		set_help(control, "QUAD_HELP_DEFAULT_MODE")
	for control: Control in [camera_angle_label, camera_angle_slider, camera_angle_spin]:
		set_help(control, "QUAD_HELP_CAMERA_ANGLE")
	for control: Control in [dry_weight_label, dry_weight_slider, dry_weight_spin]:
		set_help(control, "QUAD_HELP_DRY_WEIGHT")
	for control: Control in [battery_weight_label, battery_weight_slider, battery_weight_spin]:
		set_help(control, "QUAD_HELP_BATTERY_WEIGHT")
	for control: Control in [fov_label, fov_slider, fov_spin]:
		set_help(control, "QUAD_HELP_FOV")
	for control: Control in [rates_curve_label, rates_curve_list]:
		set_help(control, "QUAD_HELP_RATES_CURVE")
	set_help(pitch_label, "QUAD_HELP_PITCH")
	set_help(roll_label, "QUAD_HELP_ROLL")
	set_help(yaw_label, "QUAD_HELP_YAW")
	set_help(rate_graph, "QUAD_HELP_GRAPH")
	set_help(button_reset_quad, "QUAD_HELP_RESET_QUAD")
	set_help(button_reset_rates, "QUAD_HELP_RESET_RATES")


func set_help(control: Control, key: String) -> void:
	control.tooltip_text = tr(key)
	if control is Label:
		# Labels ignore the mouse by default, so they would never show a tooltip
		control.mouse_filter = Control.MOUSE_FILTER_PASS


func _on_default_mode_selected(idx: int) -> void:
	QuadSettings.default_mode = DEFAULT_MODES[idx]


func _on_angle_changed(value: float) -> void:
	QuadSettings.angle = value as int


func _on_fov_changed(value: float) -> void:
	QuadSettings.fov = value as int


func _on_dry_weight_changed(value: float) -> void:
	QuadSettings.dry_weight = value / 1000


func _on_battery_weight_changed(value: float) -> void:
	QuadSettings.battery_weight = value / 1000


func _on_rate_curve_selected(idx: int) -> void:
	var new_curve := ControlProfile.RateCurve[rates_curve_list.get_item_text(idx)] as ControlProfile.RateCurve
	if new_curve != QuadSettings.control_profile.rate_curve:
		QuadSettings.control_profile.rate_curve = new_curve
		update_rates_ui()


func _on_rate_changed(value: float, slider: HSlider) -> void:
	if slider == pitch_rate_slider:
		QuadSettings.control_profile.pitch_rate = value as int
	elif slider == roll_rate_slider:
		QuadSettings.control_profile.roll_rate = value as int
	elif slider == yaw_rate_slider:
		QuadSettings.control_profile.yaw_rate = value as int
	update_graph()


func _on_rc_changed(value: float, slider: HSlider) -> void:
	if slider == pitch_rc_slider:
		QuadSettings.control_profile.pitch_rc = value as int
	elif slider == roll_rc_slider:
		QuadSettings.control_profile.roll_rc = value as int
	elif slider == yaw_rc_slider:
		QuadSettings.control_profile.yaw_rc = value as int
	update_graph()


func _on_expo_changed(value: float, slider: HSlider) -> void:
	if slider == pitch_expo_slider:
		QuadSettings.control_profile.pitch_expo = value
	elif slider == roll_expo_slider:
		QuadSettings.control_profile.roll_expo = value
	elif slider == yaw_expo_slider:
		QuadSettings.control_profile.yaw_expo = value
	update_graph()


func update_graph() -> void:
	var pitch: Array[Vector2] = []
	var roll: Array[Vector2] = []
	var yaw: Array[Vector2] = []

	var num_points := 101
	for i in num_points:
		var input := (i / 50.0 - 1) as float
		var pitch_y := QuadSettings.control_profile.get_axis_command(ControlProfile.Axis.PITCH, input)
		var roll_y := QuadSettings.control_profile.get_axis_command(ControlProfile.Axis.ROLL, input)
		var yaw_y := QuadSettings.control_profile.get_axis_command(ControlProfile.Axis.YAW, input)
		pitch.append(Vector2(input, pitch_y))
		roll.append(Vector2(input, roll_y))
		yaw.append(Vector2(input, yaw_y))

	rate_graph.update_rates(pitch, roll, yaw)


func update_rates_labels() -> void:
	match QuadSettings.control_profile.rate_curve:
		ControlProfile.RateCurve.ACTUAL:
			rate_label.text = "QUAD_MAX_RATE"
			rc_label.text = "QUAD_CENTER_RATE"
			expo_label.text = "QUAD_EXPO"
		ControlProfile.RateCurve.RACEFLIGHT:
			rate_label.text = "QUAD_RATE"
			rc_label.text = "QUAD_ACRO_PLUS"
			expo_label.text = "QUAD_EXPO"
		ControlProfile.RateCurve.KISS:
			rate_label.text = "QUAD_RATE"
			rc_label.text = "QUAD_RC_RATE"
			expo_label.text = "QUAD_RC_CURVE"
		ControlProfile.RateCurve.QUICKRATES:
			rate_label.text = "QUAD_MAX_RATE"
			rc_label.text = "QUAD_RC_RATE"
			expo_label.text = "QUAD_EXPO"

	# The help follows the curve, since the columns change meaning with it
	var help: Array = HELP_RATES[QuadSettings.control_profile.rate_curve]
	for control: Control in [rate_label, pitch_rate_slider, roll_rate_slider, yaw_rate_slider,
			pitch_rate_spin, roll_rate_spin, yaw_rate_spin]:
		set_help(control, help[0] as String)
	for control: Control in [rc_label, pitch_rc_slider, roll_rc_slider, yaw_rc_slider,
			pitch_rc_spin, roll_rc_spin, yaw_rc_spin]:
		set_help(control, help[1] as String)
	for control: Control in [expo_label, pitch_expo_slider, roll_expo_slider, yaw_expo_slider,
			pitch_expo_spin, roll_expo_spin, yaw_expo_spin]:
		set_help(control, help[2] as String)


func update_rates_ui() -> void:
	update_rates_labels()
	update_slider_limits()
	update_sliders()
	update_graph()


func update_slider_limits() -> void:
	match QuadSettings.control_profile.rate_curve:
		ControlProfile.RateCurve.ACTUAL:
			pitch_rate_slider.min_value = 0
			pitch_rate_slider.max_value = 1800
			roll_rate_slider.min_value = 0
			roll_rate_slider.max_value = 1800
			yaw_rate_slider.min_value = 0
			yaw_rate_slider.max_value = 1800
			pitch_rc_slider.min_value = 10
			pitch_rc_slider.max_value = 1800
			roll_rc_slider.min_value = 10
			roll_rc_slider.max_value = 1800
			yaw_rc_slider.min_value = 10
			yaw_rc_slider.max_value = 1800
		ControlProfile.RateCurve.RACEFLIGHT:
			pitch_rate_slider.min_value = 10
			pitch_rate_slider.max_value = 1800
			roll_rate_slider.min_value = 10
			roll_rate_slider.max_value = 1800
			yaw_rate_slider.min_value = 10
			yaw_rate_slider.max_value = 1800
			pitch_rc_slider.min_value = 0
			pitch_rc_slider.max_value = 255
			roll_rc_slider.min_value = 0
			roll_rc_slider.max_value = 255
			yaw_rc_slider.min_value = 0
			yaw_rc_slider.max_value = 255
		ControlProfile.RateCurve.KISS:
			pitch_rate_slider.min_value = 0
			pitch_rate_slider.max_value = 99
			roll_rate_slider.min_value = 0
			roll_rate_slider.max_value = 99
			yaw_rate_slider.min_value = 0
			yaw_rate_slider.max_value = 99
			pitch_rc_slider.min_value = 1
			pitch_rc_slider.max_value = 255
			roll_rc_slider.min_value = 1
			roll_rc_slider.max_value = 255
			yaw_rc_slider.min_value = 1
			yaw_rc_slider.max_value = 255
		ControlProfile.RateCurve.QUICKRATES:
			pitch_rate_slider.min_value = 0
			pitch_rate_slider.max_value = 1800
			roll_rate_slider.min_value = 0
			roll_rate_slider.max_value = 1800
			yaw_rate_slider.min_value = 0
			yaw_rate_slider.max_value = 1800
			pitch_rc_slider.min_value = 1
			pitch_rc_slider.max_value = 255
			roll_rc_slider.min_value = 1
			roll_rc_slider.max_value = 255
			yaw_rc_slider.min_value = 1
			yaw_rc_slider.max_value = 255


func update_sliders() -> void:
	pitch_rate_slider.value = QuadSettings.control_profile.pitch_rate
	roll_rate_slider.value = QuadSettings.control_profile.roll_rate
	yaw_rate_slider.value = QuadSettings.control_profile.yaw_rate
	pitch_rc_slider.value = QuadSettings.control_profile.pitch_rc
	roll_rc_slider.value = QuadSettings.control_profile.roll_rc
	yaw_rc_slider.value = QuadSettings.control_profile.yaw_rc
	pitch_expo_slider.value = QuadSettings.control_profile.pitch_expo
	roll_expo_slider.value = QuadSettings.control_profile.roll_expo
	yaw_expo_slider.value = QuadSettings.control_profile.yaw_expo


func _on_reset_quad_pressed() -> void:
	QuadSettings.reset_quad()
	camera_angle_slider.value = QuadSettings.angle
	dry_weight_slider.value = QuadSettings.dry_weight * 1000
	battery_weight_slider.value = QuadSettings.battery_weight * 1000
	fov_slider.value = QuadSettings.fov
	default_mode_options.select(DEFAULT_MODES.find(QuadSettings.default_mode))


func _on_reset_rates_pressed() -> void:
	QuadSettings.reset_rates()
	update_sliders()

