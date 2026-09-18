## Flight test range: flat floor, the rally drone ready to fly and a car lapping an oval.
## Use it to try controls, the gimbal, the battery and shot scoring without the full stage.
## "Tomar/soltar control" switches between the drone camera and a chase camera.
extends Node3D


@export var oval_radius := Vector2(70.0, 40.0)

@onready var drone := $RallyDrone as Drone
@onready var car := $RallyCar as RallyCar
@onready var recorder := $Recorder as Recorder
@onready var chase_camera := $FollowCamera as Camera3D
@onready var visor := $UI/DroneVisor as DroneVisor
@onready var summary := $UI/ClipSummary as ClipSummary
@onready var gimbal := $RallyDrone/Gimbal as Gimbal


func _ready() -> void:
	var _message := Controls.load_input_map(true)
	var curve := Curve3D.new()
	var points := 48
	for i in points + 1:
		var angle := TAU * i / points
		var point := Vector3(cos(angle) * oval_radius.x, 0.0, sin(angle) * oval_radius.y - 60.0)
		var tangent := Vector3(-sin(angle) * oval_radius.x, 0.0, cos(angle) * oval_radius.y) * TAU / points / 3.0
		curve.add_point(point, -tangent, tangent)
	car.setup(curve)
	car.start()
	var _discard := car.finished.connect(func() -> void:
		car.setup(curve)
		car.start())
	recorder.setup(drone, car)
	recorder.input_enabled = true
	_discard = recorder.recording_stopped.connect(summary.show_report)
	visor.setup(drone, recorder, chase_camera)
	gimbal.input_enabled = true
	gimbal.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pilot_toggle"):
		if gimbal.camera.is_current():
			chase_camera.make_current()
		else:
			gimbal.camera.make_current()
		visor.visible = gimbal.camera.is_current()
