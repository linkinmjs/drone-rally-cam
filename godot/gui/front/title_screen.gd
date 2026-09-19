## First screen of the game: the logo over the live backdrop and "Press ✕ to start" (Enter on
## the keyboard, or a click). Any accept goes on to the main menu.
class_name TitleScreen
extends Control


signal start_pressed

var _started := false

@onready var prompt := %Prompt as Control
@onready var version := %Version as Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	var _a := tween.tween_property(prompt, "modulate:a", 0.45, 0.9)
	var _b := tween.tween_property(prompt, "modulate:a", 1.0, 0.9)


func _input(event: InputEvent) -> void:
	if _started or not is_visible_in_tree():
		return
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed(&"ui_accept", false, true) or click:
		get_viewport().set_input_as_handled()
		_started = true
		UI.play("click")
		start_pressed.emit()
