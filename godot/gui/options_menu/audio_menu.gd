# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: car volume.
extends MenuScreen


@onready var master_volume := %MasterSlider as HSlider
@onready var master_volume_label := %MasterValue as Label
@onready var motors_volume := %MotorsSlider as HSlider
@onready var motors_volume_label := %MotorsValue as Label
@onready var car_volume := %CarSlider as HSlider
@onready var car_volume_label := %CarValue as Label
@onready var ui_volume := %UISlider as HSlider
@onready var ui_volume_label := %UIValue as Label
@onready var mute_check := %MuteCheck as CheckButton
@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	initial_focus = master_volume
	focus_groups = [$PanelContainer/VBoxContainer/Grid as Control,
			$PanelContainer/VBoxContainer/Footer as Control]
	super()
	_bind(master_volume, master_volume_label, "master_volume")
	_bind(motors_volume, motors_volume_label, "motors_volume")
	_bind(car_volume, car_volume_label, "car_volume")
	_bind(ui_volume, ui_volume_label, "ui_volume")
	mute_check.button_pressed = bool(Audio.audio_settings["muted"])
	var _discard := mute_check.toggled.connect(_on_mute_toggled)
	bind_back_button(button_back)


func _bind(slider: HSlider, label: Label, key: String) -> void:
	slider.value = volume_to_slider(float(Audio.audio_settings[key]))
	label.text = update_slider_label(slider.value)
	var _discard := slider.value_changed.connect(_on_volume_changed.bind(label, key))


func _on_volume_changed(value: float, label: Label, key: String) -> void:
	label.text = update_slider_label(value)
	Audio.audio_settings[key] = slider_to_volume(value)
	Audio.update_volumes()
	Audio.save_audio_settings()


func _on_mute_toggled(pressed: bool) -> void:
	Audio.audio_settings["muted"] = pressed
	Audio.update_volumes()
	Audio.save_audio_settings()


func volume_to_slider(volume: float) -> float:
	return volume * 100.0


func slider_to_volume(value: float) -> float:
	return value / 100.0


func update_slider_label(value: float) -> String:
	return "%d%%" % [round(value)]
