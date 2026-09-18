# Modified from GodotDrone (GPL-3.0, (c) Cykyrios), 2026: can be disabled while the pilot
# walks (the drone then gets a neutral "hold" command), stick deadzone for gamepads (Options >
# Controls) and the mouse as an optional right stick, ignored while a gamepad is in use.
extends Node
class_name RadioController


signal reset_requested
signal mode_changed
signal arm_input
signal disarm_input


@export var target_path: NodePath = ^""
var target: Drone = null

## When false the sticks are ignored and the drone receives a neutral command, so a drone in
## a hold mode stays where it is while the pilot does something else.
@export var enabled := true:
	set(value):
		enabled = value
		mouse_stick = Vector2.ZERO
## Radial deadzone of both sticks. Gamepad sticks rest a few percent off-centre; use 0 for a
## real radio transmitter. Taken from Options > Controls.
@export_range(0.0, 0.5) var stick_deadzone := 0.08
## While the mouse is captured, moving it deflects the right stick (pitch and roll).
@export var mouse_stick_enabled := true
## Stick deflection per pixel of mouse movement.
@export var mouse_sensitivity := 0.004
## How fast the mouse stick springs back to the centre, per second.
@export var mouse_recenter_rate := 4.0
## Faster spring in Acro, where a held deflection keeps the drone rotating: the mouse gives
## short flicks of rotation instead of leaving the drone spinning.
@export var mouse_recenter_rate_acro := 12.0
## Only read the mouse while it is captured by the game window.
@export var mouse_requires_capture := true

var input := FlightCommand.new()
var mouse_stick := Vector2.ZERO

var axis_bindings: Array[ControllerAction] = []


func _ready() -> void:
	target = get_node(target_path)

	var action_list := Controls.action_list
	for controller_action in action_list:
		if controller_action.type == ControllerAction.Type.AXIS:
			axis_bindings.append(controller_action)

	stick_deadzone = GameSettings.get_stick_deadzone()
	var _discard := GameSettings.game_settings_updated.connect(_on_game_settings_updated)
	_discard = Controls.input_device_changed.connect(_on_input_device_changed)
	_discard = reset_requested.connect(target._on_reset)
	_discard = mode_changed.connect(target.flight_controller._on_cycle_flight_modes)
	_discard = arm_input.connect(target.flight_controller._on_arm_input)
	_discard = disarm_input.connect(target.flight_controller._on_disarm_input)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion:
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not mouse_requires_capture
		if mouse_stick_enabled and captured and not Controls.using_gamepad:
			var relative := (event as InputEventMouseMotion).relative
			mouse_stick = (mouse_stick + relative * mouse_sensitivity).clampf(-1.0, 1.0)
	elif event is InputEventJoypadMotion:
		var controller_action: ControllerAction = null
		for i in axis_bindings.size():
			if event.axis == axis_bindings[i].axis:
				controller_action = axis_bindings[i]
				var action: String = controller_action.action_name
				var bound_low: float = controller_action.axis_min
				var bound_high: float = controller_action.axis_max
				var axis_value: float = event.axis_value
				if !Input.is_action_pressed(action) and axis_value >= bound_low and axis_value <= bound_high:
					Input.parse_input_event(simulate_action_event(action, true))
				elif Input.is_action_pressed(action) and (axis_value < bound_low or axis_value > bound_high):
					Input.parse_input_event(simulate_action_event(action, false))
	elif event.is_action_pressed("respawn"):
		reset_requested.emit()
	elif event.is_action_pressed("cycle_flight_modes"):
		mode_changed.emit()
	elif event.is_action_pressed("toggle_arm"):
		if target.flight_controller.state_armed == false:
			arm_input.emit()
		else:
			disarm_input.emit()
	elif event.is_action("arm"):
		if event.is_action_pressed("arm"):
			arm_input.emit()
		elif event.is_action_released("arm"):
			disarm_input.emit()


func _physics_process(delta: float) -> void:
	if enabled:
		read_input(delta)
	else:
		write_neutral_input()

	if target is Drone:
		target.flight_controller.input = input


func read_input(delta: float) -> void:
	var left := apply_deadzone(Vector2(Input.get_axis("yaw_left", "yaw_right"),
			Input.get_axis("throttle_down", "throttle_up")))
	var right := apply_deadzone(Vector2(Input.get_axis("roll_left", "roll_right"),
			Input.get_axis("pitch_down", "pitch_up")))

	var rate := mouse_recenter_rate_acro if target.flight_controller.flight_mode is FlightModeAcro \
			else mouse_recenter_rate
	mouse_stick = mouse_stick.lerp(Vector2.ZERO, 1.0 - exp(-rate * delta))
	right = (right + mouse_stick).clampf(-1.0, 1.0)

	input.power = (left.y + 1) / 2
	input.yaw = left.x
	input.roll = right.x
	input.pitch = right.y


## Centred sticks with the throttle where the current flight mode expects it at rest.
func write_neutral_input() -> void:
	var flight_mode := target.flight_controller.flight_mode
	input.power = flight_mode.idle_power() if flight_mode else 0.0
	input.yaw = 0.0
	input.roll = 0.0
	input.pitch = 0.0


func _on_game_settings_updated() -> void:
	stick_deadzone = GameSettings.get_stick_deadzone()


func _on_input_device_changed(gamepad: bool) -> void:
	if gamepad:
		mouse_stick = Vector2.ZERO


func apply_deadzone(stick: Vector2) -> Vector2:
	var length := stick.length()
	if length <= stick_deadzone:
		return Vector2.ZERO
	var scaled := (minf(length, 1.0) - stick_deadzone) / (1.0 - stick_deadzone)
	return stick / length * scaled


func simulate_action_event(action_name: String, action_pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = action_pressed
	return event
