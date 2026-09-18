## Procedural rally engine: a pulse train at the firing frequency with fake gear changes,
## plus gravel noise. Heard before the car is seen, which is what builds the anticipation.
class_name EngineAudio
extends AudioStreamPlayer3D


const MIX_RATE := 22050.0
## Wheel speed (m/s) to engine RPM for each gear.
const GEAR_RATIOS: Array[float] = [260.0, 190.0, 150.0, 124.0, 106.0, 94.0]
const IDLE_RPM := 1100.0
const SHIFT_UP_RPM := 7200.0
const SHIFT_DOWN_RPM := 4200.0
## Beyond this distance to the listener the generator stops (silence) to save work.
const AUDIBLE_DISTANCE := 900.0

@export var car_path: NodePath = ^".."

var _car: RallyCar = null
var _playback: AudioStreamGeneratorPlayback = null
var _gear := 0
var _rpm := IDLE_RPM
var _phase := 0.0
var _previous_speed := 0.0
var _throttle := 0.0
var _filtered := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_car = get_node(car_path) as RallyCar
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.15
	stream = generator
	bus = &"Car"
	unit_size = 12.0
	max_distance = AUDIBLE_DISTANCE
	attenuation_filter_cutoff_hz = 3500.0
	doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _exit_tree() -> void:
	stop()
	_playback = null


func _process(delta: float) -> void:
	if not _playback or delta <= 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_to(global_position) > AUDIBLE_DISTANCE:
		return

	var speed := _car.speed if _car else 0.0
	var acceleration := (speed - _previous_speed) / delta
	_previous_speed = speed
	_throttle = lerpf(_throttle, clampf(0.35 + acceleration * 0.25, 0.1, 1.0), 1.0 - exp(-6.0 * delta))

	var target_rpm := IDLE_RPM
	if speed > 0.5:
		target_rpm = maxf(IDLE_RPM, speed * GEAR_RATIOS[_gear])
		if target_rpm > SHIFT_UP_RPM and _gear < GEAR_RATIOS.size() - 1:
			_gear += 1
		elif target_rpm < SHIFT_DOWN_RPM and _gear > 0:
			_gear -= 1
		target_rpm = maxf(IDLE_RPM, speed * GEAR_RATIOS[_gear])
	else:
		_gear = 0
	_rpm = lerpf(_rpm, target_rpm, 1.0 - exp(-8.0 * delta))
	_fill_buffer(speed)


func _fill_buffer(speed: float) -> void:
	# Four cylinders, four strokes: two firing pulses per revolution.
	var frequency := _rpm / 60.0 * 2.0
	var increment := frequency / MIX_RATE
	var volume := 0.25 + 0.55 * _throttle
	var gravel := clampf(speed / 30.0, 0.0, 1.0) * 0.18
	var frames := _playback.get_frames_available()
	for _i in frames:
		_phase = fmod(_phase + increment, 1.0)
		var pulse := 1.0 - 2.0 * _phase
		var buzz := 1.0 if _phase < 0.3 else -0.4
		var raw := 0.6 * pulse + 0.4 * buzz + gravel * _rng.randf_range(-1.0, 1.0)
		# One-pole low-pass: engine rumble rather than a square wave.
		_filtered += (raw - _filtered) * 0.35
		var sample := _filtered * volume
		_playback.push_frame(Vector2(sample, sample))
