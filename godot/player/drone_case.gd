## The drone case set on the ground: its lid swings open when it is put down and closes before
## it is packed away (EventBus.case_opened / case_closed).
class_name DroneCase
extends Node3D


## Lid angle (around the hinge, rad) when closed and when open.
const CLOSED := deg_to_rad(90.0)
const OPEN := deg_to_rad(-15.0)
const OPEN_SECONDS := 0.6
const CLOSE_SECONDS := 0.35

@onready var hinge := $LidHinge as Node3D


func _ready() -> void:
	hinge.rotation.x = CLOSED
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var _step := tween.tween_property(hinge, "rotation:x", OPEN, OPEN_SECONDS).set_delay(0.1)
	EventBus.case_opened.emit(global_position)


## Closes the lid and removes the case.
func close_and_free() -> void:
	EventBus.case_closed.emit(global_position)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var _close := tween.tween_property(hinge, "rotation:x", CLOSED, CLOSE_SECONDS)
	var _free := tween.tween_callback(queue_free)
