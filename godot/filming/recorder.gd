## Records clips from the drone camera. While recording it samples the shot a few times per
## second with ShotScorer and builds a ShotReport. A crash loses the clip.
class_name Recorder
extends Node


signal recording_started
signal recording_stopped(report: ShotReport)
signal recording_aborted(reason: String)
## Emitted every sample with the current frame score (0..1) for the viewfinder.
signal score_updated(score: float)

@export var samples_per_second := 20.0
@export var max_clip_seconds := 30.0
## Layers that can hide the subject: terrain and scenery, and the car itself.
@export_flags_3d_physics var occlusion_mask := 1 | 4

## Only reads the record button while true (the player holds the controller).
var input_enabled := false
var recording := false
var elapsed := 0.0
var last_score := 0.0
var report: ShotReport = null
# Metrics of the last sampled frame, for the live bars and tips of the viewfinder.
var last_framing := 0.0
var last_size := 0.0
var last_stability := 0.0
var last_visible := 0.0
var last_fraction := 0.0
var last_cropped := false

var drone: Drone = null
var camera: Camera3D = null
var gimbal: Gimbal = null
var subject: RallyCar = null

var _sample_timer := 0.0
var _streak := 0.0
var _smoothed_angular_speed := 0.0


func setup(new_drone: Drone, new_subject: RallyCar) -> void:
	drone = new_drone
	gimbal = drone.get_node("Gimbal") as Gimbal
	camera = gimbal.camera
	subject = new_subject
	var _discard := EventBus.drone_crashed.connect(_on_drone_crashed)


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("rec_toggle"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if recording:
		stop()
	else:
		start()


func start() -> void:
	if recording or not camera:
		return
	recording = true
	elapsed = 0.0
	_sample_timer = 0.0
	_streak = 0.0
	_smoothed_angular_speed = 0.0
	last_score = 0.0
	report = ShotReport.new()
	report.sample_interval = 1.0 / samples_per_second
	recording_started.emit()
	EventBus.recording_started.emit()


func stop() -> void:
	if not recording:
		return
	recording = false
	report.duration = elapsed
	report.finalize()
	recording_stopped.emit(report)
	EventBus.recording_stopped.emit(report)


## Ends the clip without keeping it.
func abort(reason: String) -> void:
	if not recording:
		return
	recording = false
	report.duration = elapsed
	report.aborted = true
	report.finalize()
	recording_aborted.emit(reason)
	EventBus.recording_aborted.emit(reason)


func _process(delta: float) -> void:
	if not recording:
		return
	elapsed += delta
	_smoothed_angular_speed = lerpf(_smoothed_angular_speed, gimbal.angular_speed, 1.0 - exp(-10.0 * delta))
	_sample_timer -= delta
	# At low frame rates take several samples in one frame, but never try to catch up on
	# more than a quarter of a second.
	_sample_timer = maxf(_sample_timer, -0.25)
	while _sample_timer <= 0.0:
		_sample_timer += report.sample_interval
		last_score = sample_frame(report.sample_interval)
	score_updated.emit(last_score)
	EventBus.shot_score_updated.emit(last_score)
	if elapsed >= max_clip_seconds:
		stop()


## Scores the current frame and adds it to the report. Returns the frame score.
func sample_frame(interval: float) -> float:
	var framing := 0.0
	var size := 0.0
	var visible := 0.0
	var fraction := 0.0
	var cropped := false
	if subject and subject.is_inside_tree():
		var box := subject.get_scoring_aabb()
		var rect := ShotScorer.project_aabb(camera, box)
		framing = ShotScorer.framing_score(rect)
		fraction = ShotScorer.screen_fraction(rect)
		cropped = ShotScorer.is_cropped(rect)
		size = ShotScorer.size_score(fraction, cropped)
		if fraction > 0.0:
			var exclude: Array[RID] = [drone.get_rid()]
			visible = ShotScorer.visibility(camera, subject, box, exclude, occlusion_mask)
	var stability := ShotScorer.stability_score(_smoothed_angular_speed)
	last_framing = framing
	last_size = size
	last_stability = stability
	last_visible = visible
	last_fraction = fraction
	last_cropped = cropped
	var continuity := clampf(_streak / ShotScorer.CONTINUITY_SECONDS, 0.0, 1.0)
	var score := ShotScorer.frame_score(framing, size, stability, continuity, visible)
	if score >= ShotScorer.GOOD_SCORE:
		_streak += interval
	else:
		_streak = 0.0
	report.add_sample(framing, size, stability, visible, score)
	return score


func _on_drone_crashed(crashed_drone: Drone, _speed: float) -> void:
	if crashed_drone == drone:
		abort("El dron se estrelló: se perdió la toma.")
