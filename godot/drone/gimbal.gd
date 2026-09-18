## Stabilized camera mount. Follows the drone's position and heading but cancels its roll and
## pitch, so the image stays level while the drone banks. The pilot controls the tilt.
class_name Gimbal
extends Node3D


## Render layers used by the drone's own meshes, hidden from the gimbal camera so the
## propellers never show up in the shot.
const DRONE_BODY_LAYER := 2

## Where the camera sits relative to the drone's centre, in the drone's local space. Above
## the centre: a landed drone rests almost on its centre, and a lower camera would end up
## inside the ground.
@export var mount_offset := Vector3(0.0, 0.04, -0.1)
## Tilt limits in degrees: negative looks down.
@export_range(-90.0, 0.0) var min_tilt_deg := -90.0
@export_range(0.0, 45.0) var max_tilt_deg := 25.0
@export var tilt_speed_deg := 60.0
## Degrees per mouse wheel notch.
@export var wheel_step_deg := 3.0
## Higher is snappier. The same value smooths the heading and the tilt.
@export_range(1.0, 30.0) var smoothing := 6.0
@export var start_tilt_deg := -10.0

## Only reads the gimbal actions while true (while the player holds the controller).
var input_enabled := false
var tilt := 0.0
## Angular speed of the camera in rad/s, measured every frame. Used to score stability.
var angular_speed := 0.0

var _drone: Node3D = null
var _heading := 0.0
var _previous_basis := Basis.IDENTITY

@onready var camera := $Camera3D as Camera3D


func _ready() -> void:
	_drone = get_parent() as Node3D
	top_level = true
	tilt = deg_to_rad(start_tilt_deg)
	camera.cull_mask &= ~DRONE_BODY_LAYER
	_hide_drone_body(_drone)
	snap()


func _process(delta: float) -> void:
	if input_enabled:
		var tilt_input := Input.get_axis("gimbal_down", "gimbal_up")
		tilt += deg_to_rad(tilt_speed_deg) * tilt_input * delta
	tilt = clampf(tilt, deg_to_rad(min_tilt_deg), deg_to_rad(max_tilt_deg))

	var drone_xform := _drone.global_transform
	global_position = drone_xform * mount_offset

	var heading := _get_drone_heading(drone_xform.basis)
	var target := Basis.from_euler(Vector3(tilt, heading, 0.0))
	var weight := 1.0 - exp(-smoothing * delta)
	global_basis = global_basis.orthonormalized().slerp(target, weight)

	if delta > 0.0:
		var change := _previous_basis.inverse() * global_basis
		angular_speed = change.get_rotation_quaternion().get_angle() / delta
	_previous_basis = global_basis


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		tilt += deg_to_rad(wheel_step_deg)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		tilt -= deg_to_rad(wheel_step_deg)


## Jumps to the target orientation without smoothing (after a respawn or deploy).
func snap() -> void:
	if not _drone:
		return
	var drone_xform := _drone.global_transform
	_heading = _get_drone_heading(drone_xform.basis)
	global_transform = Transform3D(Basis.from_euler(Vector3(tilt, _heading, 0.0)),
			drone_xform * mount_offset)
	_previous_basis = global_basis
	angular_speed = 0.0


func get_tilt_degrees() -> float:
	return rad_to_deg(tilt)


func _get_drone_heading(drone_basis: Basis) -> float:
	var forward := -drone_basis.z
	forward.y = 0.0
	# Looking straight up or down: keep the last heading instead of spinning.
	if forward.length_squared() > 0.01:
		_heading = atan2(-forward.x, -forward.z)
	return _heading


func _hide_drone_body(node: Node) -> void:
	for child in node.get_children():
		if child == self:
			continue
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = DRONE_BODY_LAYER
		_hide_drone_body(child)
