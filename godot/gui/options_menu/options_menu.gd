# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: no graphics menu.
extends MenuScreen


var packed_game_settings_menu := preload("res://gui/options_menu/game_settings_menu.tscn")
var packed_audio_menu := preload("res://gui/options_menu/audio_menu.tscn")
var packed_controls_menu := preload("res://gui/options_menu/controls_menu/controls_menu.tscn")


@onready var button_game := %ButtonGame as Button
@onready var button_audio := %ButtonAudio as Button
@onready var button_controls := %ButtonControls as Button
@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	initial_focus = button_game
	super()
	var _discard := button_game.pressed.connect(_on_game_settings_pressed)
	_discard = button_audio.pressed.connect(_on_audio_pressed)
	_discard = button_controls.pressed.connect(_on_controls_pressed)
	bind_back_button(button_back)


# Sub screens are added next to this one (as before) and this hub hides meanwhile.
func _on_game_settings_pressed() -> void:
	open_submenu(packed_game_settings_menu, self, get_parent())


func _on_audio_pressed() -> void:
	open_submenu(packed_audio_menu, self, get_parent())


func _on_controls_pressed() -> void:
	open_submenu(packed_controls_menu, self, get_parent())
