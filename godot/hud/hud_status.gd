# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: empty battery and centred throttle
# arming messages.
class_name HUDStatus
extends Label


enum Status {DISARMED, ARMED, LAUNCH, TURTLE, RECOVERY}


var status := Status.DISARMED:
	set(s):
		if s < Status.size():
			status = s
			var status_text := ""
			match status:
				Status.DISARMED:
					status_text = "HUD_STATUS_DISARMED"
				Status.ARMED:
					status_text = "HUD_STATUS_ARMED"
					message_timer.start(1.0)
				Status.LAUNCH:
					status_text = "HUD_STATUS_LAUNCH"
				Status.TURTLE:
					status_text = "HUD_STATUS_TURTLE"
				Status.RECOVERY:
					status_text = "HUD_STATUS_RECOVERY"
			if status != Status.ARMED and not message_timer.is_stopped():
				message_timer.stop()
			set_message(status_text)
var message_timer := Timer.new()


func _ready() -> void:
	add_child(message_timer)
	message_timer.one_shot = true
	var _discard := message_timer.timeout.connect(_on_message_timer_timeout)

	set_message("HUD_STATUS_DISARMED")


func set_message(msg: String = "") -> void:
	# Positioned below the crosshair by the HUD layout (no leading blank lines needed)
	text = tr(msg)


func clear_message() -> void:
	set_message()


func _on_message_timer_timeout() -> void:
	clear_message()
	if status == Status.DISARMED:
		status = Status.DISARMED


func _on_armed(mode: FlightMode) -> void:
	match mode:
		FlightMode.Type.TURTLE:
			self.status = Status.TURTLE
		FlightMode.Type.LAUNCH:
			self.status = Status.LAUNCH
		_:
			self.status = Status.ARMED


func _on_disarmed() -> void:
	self.status = Status.DISARMED


## Set by the viewfinder: the throttle position the current flight mode needs to arm.
var throttle_centered_to_arm := false


func _on_arm_failed(reason: int) -> void:
	var reason_msg := ""
	match reason:
		FlightController.ArmFail.THROTTLE_HIGH:
			reason_msg = "HUD_STATUS_THROTTLE_TO_CENTER" if throttle_centered_to_arm \
					else "HUD_STATUS_THROTTLE_HIGH"
		FlightController.ArmFail.CRASH_RECOVERY_MODE:
			reason_msg = "HUD_STATUS_RECOVERY_MODE"
		FlightController.ArmFail.BLOCKED:
			reason_msg = "HUD_STATUS_BATTERY_EMPTY"
	set_message("*** %s ***" % [tr(reason_msg)])
	message_timer.start(2)


func _on_mode_changed(mode: FlightMode) -> void:
	if status == Status.DISARMED:
		return
	if not mode is FlightModeTurtle and not mode is FlightModeLaunch \
			and (status == Status.TURTLE or status == Status.LAUNCH):
		clear_message()
	elif mode is FlightModeRecover:
		self.status = Status.RECOVERY
	else:
		clear_message()
