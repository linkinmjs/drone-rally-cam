## Detects hard impacts on the parent drone. Requires contact_monitor on the drone body.
## A crash disarms the drone and loses the clip being recorded. The impact speed is relative
## to what was hit, so a car running into a hovering drone counts too.
class_name CrashSensor
extends Node


signal crashed(speed: float)

## Impact speed, in m/s, above which a collision counts as a crash.
@export var crash_speed := 4.0

var _drone: Drone = null
var _previous_velocity := Vector3.ZERO


func _ready() -> void:
	_drone = get_parent() as Drone
	if not _drone.contact_monitor:
		push_warning("CrashSensor needs contact_monitor enabled on the drone.")
	var _discard := _drone.body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	# Runs before the physics step, so this is the velocity right before any impact.
	_previous_velocity = _drone.linear_velocity


func _on_body_entered(body: Node) -> void:
	var other_velocity := Vector3.ZERO
	if body.has_method("get_velocity"):
		other_velocity = body.call("get_velocity")
	var speed := (_previous_velocity - other_velocity).length()
	if speed < crash_speed:
		return
	if _drone.flight_controller.state_armed:
		_drone.flight_controller._on_disarm_input()
	crashed.emit(speed)
	EventBus.drone_crashed.emit(_drone, speed)
