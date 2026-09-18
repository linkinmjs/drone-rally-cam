# Modified from GodotDrone (GPL-3.0, (c) Cykyrios), 2026: removed the HUD, race/replay and
# checkpoint coupling, and added stow/deploy/reset_to so the game can pack the drone into
# its case. Rates, weight and default flight mode come from QuadSettings (Options > Drone).
class_name Drone
extends RigidBody3D


signal respawned
signal stowed
signal deployed


var motors: Array[Motor] = []
@onready var flight_controller := $FlightController as FlightController

@export var projected_area := Vector3(0.1, 0.1, 0.1)
@export var cd := Vector3(0.3, 1.3, 0.3)
## Physics layers that count as ground for the height readout and crash recovery.
@export_flags_3d_physics var ground_mask := 1

var _ground_query: PhysicsRayQueryParameters3D = null

## Where `reset()` puts the drone back. Updated by `reset_to()` and `deploy()`.
var respawn_transform := Transform3D.IDENTITY
var is_stowed := false

var drone_transform := Transform3D.IDENTITY
var drone_pos := Vector3.ZERO
var drone_basis := Basis.IDENTITY

var _collision_layer := 0
var _collision_mask := 0


func _ready() -> void:
	for shape: CollisionShape3D in $Frame.collision_shapes:
		$Frame.remove_child(shape)
		add_child(shape)
	motors = [$Motor1 as Motor, $Motor2 as Motor, $Motor3 as Motor, $Motor4 as Motor]
	flight_controller.set_motors(motors)
	var _discard := QuadSettings.settings_updated.connect(_on_quad_settings_updated)
	_on_quad_settings_updated()

	# Ground effect parameters
	var rad := motors[0].propeller.diameter * 0.0254 * 0.5 as float
	var d := minf((motors[0].transform.origin - motors[1].transform.origin).length(),
			(motors[0].transform.origin - motors[3].transform.origin).length())
	var b := (motors[0].transform.origin - motors[2].transform.origin).length()
	for motor in motors:
		motor.propeller.set_ground_effect_parameters(rad, d, b, 1)

	respawn_transform = global_transform
	_collision_layer = collision_layer
	_collision_mask = collision_mask


func _physics_process(_delta: float) -> void:
	drone_transform = global_transform
	drone_pos = drone_transform.origin
	drone_basis = drone_transform.basis
	_update_ground_distance()


func _update_ground_distance() -> void:
	if not _ground_query:
		_ground_query = PhysicsRayQueryParameters3D.new()
		_ground_query.collision_mask = ground_mask
		_ground_query.exclude = [get_rid()]
	_ground_query.from = drone_pos
	_ground_query.to = drone_pos + Vector3.DOWN * 500.0
	var hit := get_world_3d().direct_space_state.intersect_ray(_ground_query)
	var distance := INF
	if not hit.is_empty():
		distance = drone_pos.y - (hit["position"] as Vector3).y
	flight_controller.flight_state.ground_distance = distance


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var steps := 10
	if not flight_controller.state_armed:
		steps = 1
	var dt := state.step / (steps as float)

	var xform := drone_transform.orthonormalized()
	var pos := xform.origin
	var bas := xform.basis
	var lin_vel := state.linear_velocity
	var ang_vel := state.angular_velocity

	for i in steps:
		flight_controller.integrate_loop(dt, pos, bas)

		var vec_force := Vector3.ZERO
		var vec_torque := Vector3.ZERO

		for motor in motors:
			motor.update_thrust(dt)
			var prop := motor.propeller
			var prop_pos := prop.global_transform.origin - global_transform.origin
			var prop_xform := motor.transform * prop.transform
			var prop_local_pos := prop_pos * prop_xform
			prop.velocity = lin_vel * bas + (ang_vel * bas).cross(prop_local_pos)
			prop.update_forces()
			var prop_forces: Array[Vector3] = prop.forces
			var prop_thrust := bas * prop_forces[0]
			if motor.rpm < 0:
				prop_thrust = -prop_thrust / 2
			var prop_drag := bas * prop_forces[1]
			vec_force += prop_thrust + prop_drag
			vec_torque += motor.torque * bas.y
			vec_torque -= prop_thrust.cross(bas * prop_xform.origin)

		var drag := get_drag(lin_vel, ang_vel, bas)
		vec_force += drag[0]
		vec_torque += drag[1]

		# Integrate forces and velocities
		var a := vec_force * state.inverse_mass + Vector3(0, -9.81, 0)
		lin_vel += a * dt
		pos += lin_vel * dt

		var ang_a := vec_torque * state.inverse_inertia
		ang_vel += ang_a * dt
		var delta_ang_vel := ang_vel * dt
		if not delta_ang_vel.is_zero_approx():
			bas = bas.rotated(delta_ang_vel.normalized(), delta_ang_vel.length())

		xform = Transform3D(bas, pos)

	xform = xform.orthonormalized()
	state.linear_velocity = lin_vel
	state.angular_velocity = ang_vel


## Total thrust of the four propellers, in newtons.
func get_total_thrust() -> float:
	var total := 0.0
	for motor in motors:
		total += motor.propeller.forces[0].length()
	return total


## Rates, expo, weight and default flight mode edited in Options > Drone.
func _on_quad_settings_updated() -> void:
	mass = QuadSettings.dry_weight + QuadSettings.battery_weight
	flight_controller.set_control_profile(QuadSettings.control_profile)
	flight_controller.set_hover_thrust(mass / 4 * 9.81)
	flight_controller.default_mode = QuadSettings.default_mode


func reset() -> void:
	_on_reset()


## Stores a new respawn transform and moves the drone there, disarmed and at rest.
func reset_to(xform: Transform3D) -> void:
	respawn_transform = xform
	_on_reset()


func _on_reset() -> void:
	var target := respawn_transform.translated(Vector3(0, 0.1, 0))
	await get_tree().physics_frame
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = target
	drone_transform = target
	flight_controller.reset()

	respawned.emit()


## Packs the drone away: disarmed, frozen, invisible and without collisions.
func stow() -> void:
	if flight_controller.state_armed:
		flight_controller._on_disarm_input()
	is_stowed = true
	visible = false
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	for motor in motors:
		motor.rpm = 0
	process_mode = Node.PROCESS_MODE_DISABLED
	stowed.emit()


## Takes the drone out of its case and puts it at `xform`, disarmed.
func deploy(xform: Transform3D) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	is_stowed = false
	# Move first so the body does not wake up wherever it was packed away.
	global_transform = xform.translated(Vector3(0, 0.1, 0))
	drone_transform = global_transform
	visible = true
	freeze = false
	collision_layer = _collision_layer
	collision_mask = _collision_mask
	reset_to(xform)
	deployed.emit()


func get_drag(lin_vel: Vector3, ang_vel: Vector3, orientation: Basis) -> Array[Vector3]:
	var drag: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var local_vel := lin_vel * orientation
	var local_ang := ang_vel * orientation
	var local_drag := [Vector3.ZERO, Vector3.ZERO]
	local_drag[0] = -local_vel.length() * local_vel * projected_area * cd / 2.0 * 1.225
	local_drag[1] = -local_ang.length() * local_ang * projected_area * cd / 200.0 * 1.225
	drag[0] = orientation * local_drag[0]
	drag[1] = orientation * local_drag[1]
	return drag


func _on_flight_mode_changed(flight_mode: FlightMode) -> void:
	var led := $LEDMode as ModeLED
	led.blink_pattern = []
	if flight_mode is FlightModeAcro:
		led.change_color(Color(1, 0, 0))
	elif flight_mode is FlightModeHorizon:
		led.change_color(Color(0.2, 0.2, 1))
	elif flight_mode is FlightModeSpeed:
		led.change_color(Color(1, 1, 0))
	elif flight_mode is FlightModeTrack:
		led.change_color(Color(0, 1, 0))
	elif flight_mode is FlightModeRecover:
		led.change_color(Color(1, 0, 0))
		led.blink_pattern = [Vector2(0.25, 0.25)]
	elif flight_mode is FlightModeTurtle:
		led.change_color(Color(1, 0, 0))
		led.blink_pattern = [Vector2(0.1, 0.1), Vector2(0.1, 0.7)]
	elif flight_mode is FlightModeLaunch:
		led.change_color(Color(1, 0, 0))
		led.blink_pattern = [Vector2(0.15, 0.15), Vector2(0.55, 0.15)]
	EventBus.flight_mode_changed.emit(flight_mode)
