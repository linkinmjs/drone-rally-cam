## A rally car that follows the driving line instead of simulating tyres: the speed comes
## from a precomputed profile, a driver adds skill and noise, and a visual layer opens and
## closes the line in corners and slides the body on the dirt. The wheels spin and steer
## (counter-steering in a slide), the body rolls and pitches, and the rear wheels throw dust.
class_name RallyCar
extends AnimatableBody3D


signal started
signal finished

@export var car_number := 7
@export var driver_name := "Auto 7"

@export_group("Driver")
## Fraction of the ideal speed profile the driver achieves (0.85 to 1.0).
@export_range(0.5, 1.0) var skill := 0.93
## Amplitude of the slow speed variation, as a fraction of the speed.
@export_range(0.0, 0.2) var speed_noise := 0.05
@export var noise_seed := 3

@export_group("Car")
@export var grip := 0.75
@export var top_speed := 38.0
@export var brake := 9.0
@export var accel := 6.0

@export_group("Visual")
## How far from the centre line the car moves to open and close corners.
@export var max_lateral_offset := 1.6
## Extra yaw into the corner per g of lateral acceleration (the rear stepping out).
@export var drift_gain := 0.35
@export var max_drift_deg := 25.0
## Height of the body origin above the road surface.
@export var ride_height := 0.0
## The profile ends at 0 m/s at the finish; the car never goes slower than this before it,
## or it would creep towards the line forever.
@export var min_speed := 3.0
## Body roll (rad) per g of lateral acceleration and pitch (rad) per m/s² of acceleration.
@export var roll_per_g := 0.06
@export var pitch_per_accel := 0.012
## Above this speed (m/s) the rear wheels throw dust.
@export var dust_speed := 5.0

const WHEEL_RADIUS := 0.33
const WHEELBASE := 2.7

var profile: SpeedProfile = null
var distance := 0.0
var speed := 0.0
var running := false
var has_finished := false

var _curve: Curve3D = null
## Transform from the curve's space to the world.
var _curve_to_world := Transform3D.IDENTITY
var _lateral := 0.0
var _drift := 0.0
var _noise := FastNoiseLite.new()
var _wheel_spin := 0.0
var _steer := 0.0
var _roll := 0.0
var _pitch := 0.0
var _previous_speed := 0.0
var _wheel_bases: Array[Transform3D] = []

@onready var _shape := $CollisionShape3D as CollisionShape3D
@onready var chassis := $Chassis as Node3D
## Front left, front right, rear left, rear right.
@onready var wheels: Array[Node3D] = [$WheelFrontLeft as Node3D, $WheelFrontRight as Node3D,
		$WheelRearLeft as Node3D, $WheelRearRight as Node3D]
@onready var dust: Array[GPUParticles3D] = [$DustLeft as GPUParticles3D, $DustRight as GPUParticles3D]


func _ready() -> void:
	sync_to_physics = true
	for wheel in wheels:
		_wheel_bases.append(wheel.transform)
	for label: Label3D in [$Chassis/NumberLeft, $Chassis/NumberRight, $Chassis/NumberRoof]:
		label.text = str(car_number)
	_noise.seed = noise_seed
	_noise.frequency = 0.01


## Puts the car at the start of `curve` (in the space given by `curve_to_world`).
func setup(curve: Curve3D, curve_to_world := Transform3D.IDENTITY) -> void:
	_curve = curve
	_curve_to_world = curve_to_world
	profile = SpeedProfile.build(curve, grip, top_speed, brake, accel)
	distance = 0.0
	speed = 0.0
	running = false
	has_finished = false
	_place(0.0)
	_set_dust(false)


func start() -> void:
	if not _curve or running:
		return
	running = true
	started.emit()
	EventBus.car_started.emit(self)


## Seconds the car needs from the start to `at_distance`, following the driver's pace.
func expected_time_at(at_distance: float) -> float:
	return profile.time_at(at_distance) / skill if profile else 0.0


func get_route_length() -> float:
	return profile.length if profile else 0.0


## World velocity, for impacts (see CrashSensor).
func get_velocity() -> Vector3:
	return -global_basis.z * speed


## World-space box used to score shots of this car.
func get_scoring_aabb() -> AABB:
	var box := _shape.shape as BoxShape3D
	var local := AABB(-box.size * 0.5, box.size)
	return _shape.global_transform * local


func _physics_process(delta: float) -> void:
	if not running or not profile:
		return
	var variation := 1.0 + speed_noise * _noise.get_noise_1d(distance)
	# The profile starts and ends at 0 m/s: the minimum speed gets the car off the line and
	# across the finish.
	speed = maxf(profile.speed_at(distance) * skill * variation, min_speed)
	distance += speed * delta
	if distance >= profile.length:
		distance = profile.length
		speed = 0.0
		running = false
		has_finished = true
		_set_dust(false)
		finished.emit()
		EventBus.car_finished.emit(self)
	_place(delta)
	_animate(delta)


## Wheels, body and dust for the current speed and corner.
func _animate(delta: float) -> void:
	_wheel_spin = fmod(_wheel_spin - speed * delta / WHEEL_RADIUS, TAU)
	var curvature := profile.curvature_at(distance)
	# Steer into the corner, and against the slide (the rear stepping out).
	var target_steer := clampf(atan(curvature * WHEELBASE) - _drift * 0.8, -0.45, 0.45)
	_steer = lerpf(_steer, target_steer, 1.0 - exp(-8.0 * delta))
	for i in wheels.size():
		var base := _wheel_bases[i]
		var steer := _steer if i < 2 else 0.0
		# The wheel mesh turns about its own Y axis (the axle).
		wheels[i].transform = Transform3D(Basis(Vector3.UP, steer) * base.basis * Basis(Vector3.UP, _wheel_spin),
				base.origin)
	var lateral_g := speed * speed * curvature / 9.81
	var acceleration := (speed - _previous_speed) / maxf(delta, 0.001)
	_previous_speed = speed
	var weight := 1.0 - exp(-4.0 * delta)
	# The body leans out of the corner, squats when accelerating and dives when braking.
	_roll = lerpf(_roll, clampf(-lateral_g * roll_per_g, -0.08, 0.08), weight)
	_pitch = lerpf(_pitch, clampf(acceleration * pitch_per_accel, -0.05, 0.05), weight)
	chassis.rotation = Vector3(_pitch, 0.0, _roll)
	_set_dust(speed > dust_speed)
	for emitter in dust:
		emitter.amount_ratio = clampf(speed / 30.0, 0.25, 1.0)


func _set_dust(on: bool) -> void:
	for emitter in dust:
		if emitter.emitting != on:
			emitter.emitting = on


func _place(delta: float) -> void:
	var here := profile.curvature_at(distance)
	var ahead := profile.curvature_at(distance + 20.0)
	# Positive offset is to the right: go wide before a corner, cut the apex inside.
	var target_lateral := clampf(ahead * 40.0 - here * 60.0, -1.0, 1.0) * max_lateral_offset
	var target_drift := clampf(speed * speed * here / 9.81 * drift_gain, -1.0, 1.0) \
			* deg_to_rad(max_drift_deg)
	if delta > 0.0:
		_lateral = lerpf(_lateral, target_lateral, 1.0 - exp(-1.5 * delta))
		_drift = lerpf(_drift, target_drift, 1.0 - exp(-3.0 * delta))
	else:
		_lateral = target_lateral
		_drift = 0.0

	var length := _curve.get_baked_length()
	var position := _curve.sample_baked(distance, true)
	var behind := _curve.sample_baked(maxf(distance - 1.0, 0.0), true)
	var front := _curve.sample_baked(minf(distance + 1.0, length), true)
	var forward := (front - behind).normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward)
	var basis := Basis(right, up, -forward).rotated(up, _drift)
	var local := Transform3D(basis, position + right * _lateral + up * ride_height)
	global_transform = _curve_to_world * local
