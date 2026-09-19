# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: no longer a label
# under the crosshair. It keeps the armed state for the mode chip and reports refused arming
# to the viewfinder's message line; turtle and launch are detected by flight mode class.
class_name HUDStatus
extends Node
## Armed state of the drone (shown in the mode chip) and why arming was refused.


## The state or the text changed.
signal changed
## Arming was refused: `text` says why (throttle position, recovery, battery).
signal arm_refused(text: String)

enum Status {DISARMED, ARMED, LAUNCH, TURTLE, RECOVERY}

const STATE_KEYS := {
	Status.DISARMED: "HUD_STATUS_DISARMED",
	Status.ARMED: "HUD_STATUS_ARMED",
	Status.LAUNCH: "HUD_STATUS_LAUNCH",
	Status.TURTLE: "HUD_STATUS_TURTLE",
	Status.RECOVERY: "HUD_STATUS_RECOVERY",
}
## Seconds a refusal stays in `text`.
const REFUSAL_SECONDS := 2.0

var status := Status.DISARMED
## The state, or the last refusal for a couple of seconds.
var text := ""
## Set by the viewfinder: the throttle position the current flight mode needs to arm.
var throttle_centered_to_arm := false
var _refusal_time := 0.0


func _ready() -> void:
	text = tr(state_key())


func state_key() -> String:
	return STATE_KEYS[status]


func is_armed() -> bool:
	return status != Status.DISARMED


func _process(delta: float) -> void:
	if _refusal_time <= 0.0:
		return
	_refusal_time -= delta
	if _refusal_time <= 0.0:
		text = tr(state_key())
		changed.emit()


func _set_status(new_status: Status) -> void:
	status = new_status
	_refusal_time = 0.0
	text = tr(state_key())
	changed.emit()


func _on_armed(mode: FlightMode) -> void:
	if mode is FlightModeTurtle:
		_set_status(Status.TURTLE)
	elif mode is FlightModeLaunch:
		_set_status(Status.LAUNCH)
	else:
		_set_status(Status.ARMED)


func _on_disarmed() -> void:
	_set_status(Status.DISARMED)


func _on_arm_failed(reason: int) -> void:
	var key := ""
	match reason:
		FlightController.ArmFail.THROTTLE_HIGH:
			key = "HUD_STATUS_THROTTLE_TO_CENTER" if throttle_centered_to_arm else "HUD_STATUS_THROTTLE_HIGH"
		FlightController.ArmFail.CRASH_RECOVERY_MODE:
			key = "HUD_STATUS_RECOVERY_MODE"
		FlightController.ArmFail.BLOCKED:
			key = "HUD_STATUS_BATTERY_EMPTY"
	text = tr(key)
	_refusal_time = REFUSAL_SECONDS
	changed.emit()
	arm_refused.emit(text)


func _on_mode_changed(mode: FlightMode) -> void:
	if status == Status.DISARMED:
		return
	if mode is FlightModeRecover:
		_set_status(Status.RECOVERY)
	elif mode is FlightModeTurtle:
		_set_status(Status.TURTLE)
	elif mode is FlightModeLaunch:
		_set_status(Status.LAUNCH)
	elif status != Status.ARMED:
		_set_status(Status.ARMED)
