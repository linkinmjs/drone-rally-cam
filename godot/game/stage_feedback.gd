## How the stage answers the EventBus: sparks and dust where the drone crashes (and a shake of
## the pilot view), a puff of dust when the drone is set down or packed, a dust ring when it
## lands, and a sound for every event through Audio.play_event (the table of sounds is plan 06).
## Particles come from small pools, so nothing is created while playing.
class_name StageFeedback
extends Node


const DUST_PUFF := preload("res://vfx/dust_puff.tscn")
const SPARKS := preload("res://vfx/sparks.tscn")
const LANDING_RING := preload("res://vfx/landing_ring.tscn")
const POOL_SIZE := 3
## EventBus signal → method that answers it.
const TABLE := {
	&"drone_crashed": &"_on_drone_crashed",
	&"drone_deployed": &"_on_drone_deployed",
	&"drone_recovered": &"_on_drone_recovered",
	&"recording_started": &"_on_recording_started",
	&"recording_stopped": &"_on_recording_stopped",
	&"recording_aborted": &"_on_recording_aborted",
	&"battery_low": &"_on_battery_low",
	&"battery_depleted": &"_on_battery_depleted",
	&"car_started": &"_on_car_started",
	&"car_finished": &"_on_car_finished",
	&"player_step": &"_on_player_step",
	&"case_opened": &"_on_case_opened",
	&"case_closed": &"_on_case_closed",
}
## Heights (m) above the ground of a drone in the air, and of a drone touching down.
const AIRBORNE := 0.6
const TOUCHDOWN := 0.15
## Shake of the pilot view at full strength, in screen offset units.
const SHAKE := 0.05

## Landings seen and effects played (for the checks).
var landings := 0
var effects_played := 0
var stage: Stage = null

var _pools := {}
var _next := {}
var _airborne := false
var _shake := 0.0


func _ready() -> void:
	stage = get_parent() as Stage
	for signal_name: StringName in TABLE:
		var _discard := EventBus.connect(signal_name, Callable(self, TABLE[signal_name]))
	for packed: PackedScene in [DUST_PUFF, SPARKS, LANDING_RING]:
		var pool: Array[GPUParticles3D] = []
		for i in POOL_SIZE:
			var particles := packed.instantiate() as GPUParticles3D
			add_child(particles)
			pool.append(particles)
		_pools[packed] = pool
		_next[packed] = 0


## True when every signal of TABLE is answered.
func is_connected_to_all() -> bool:
	for signal_name: StringName in TABLE:
		if not EventBus.is_connected(signal_name, Callable(self, TABLE[signal_name])):
			return false
	return true


## Plays one of the pooled effects at `position`.
func spawn(packed: PackedScene, position: Vector3) -> GPUParticles3D:
	var pool: Array[GPUParticles3D] = _pools[packed]
	var index: int = _next[packed]
	_next[packed] = (index + 1) % pool.size()
	var particles := pool[index]
	particles.global_position = position
	particles.restart()
	particles.emitting = true
	effects_played += 1
	return particles


func _physics_process(delta: float) -> void:
	if stage == null or not stage.is_stage_ready:
		return
	_watch_landing()
	_update_shake(delta)


## A dust ring when the armed drone comes down to the ground from the air.
func _watch_landing() -> void:
	var fc := stage.drone.flight_controller
	var height := fc.flight_state.ground_distance
	if not fc.state_armed or not is_finite(height):
		return
	if height > AIRBORNE:
		_airborne = true
	elif _airborne and height < TOUCHDOWN and fc.lin_vel.y < 0.1:
		_airborne = false
		landings += 1
		var ground := stage.drone.global_position
		ground.y = stage.world.get_ground_height(ground) + 0.05
		spawn(LANDING_RING, ground)
		Audio.play_event(&"drone_land", ground)


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = move_toward(_shake, 0.0, delta * 2.5)
	var camera := stage.drone.get_node_or_null("PilotCamera") as Camera3D
	if camera:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * SHAKE
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * SHAKE
		if _shake <= 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0


func _on_drone_crashed(drone: Drone, speed: float) -> void:
	spawn(SPARKS, drone.global_position)
	spawn(DUST_PUFF, drone.global_position)
	if stage.control.state == ControlState.State.PILOTING and stage.control.view == ControlState.View.PILOT:
		_shake = clampf(speed / 10.0, 0.4, 1.0)
	Audio.play_event(&"drone_crash", drone.global_position)


func _on_drone_deployed(drone: Drone) -> void:
	spawn(DUST_PUFF, drone.global_position)
	Audio.play_event(&"drone_deploy", drone.global_position)


func _on_drone_recovered(drone: Drone) -> void:
	spawn(DUST_PUFF, drone.global_position)
	Audio.play_event(&"drone_recover", drone.global_position)


func _on_recording_started() -> void:
	Audio.play_event(&"rec_start")


func _on_recording_stopped(_report: ShotReport) -> void:
	Audio.play_event(&"rec_stop")


func _on_recording_aborted(_reason: String) -> void:
	Audio.play_event(&"rec_abort")


func _on_battery_low() -> void:
	Audio.play_event(&"battery_low")


func _on_battery_depleted() -> void:
	Audio.play_event(&"battery_depleted")


func _on_car_started(car: Node3D) -> void:
	Audio.play_event(&"car_start", car.global_position)


func _on_car_finished(car: Node3D) -> void:
	Audio.play_event(&"car_finish", car.global_position)


func _on_player_step(surface: StringName) -> void:
	Audio.play_event(StringName("step_%s" % surface), stage.player.global_position)


func _on_case_opened(position: Vector3) -> void:
	Audio.play_event(&"case_open", position)


func _on_case_closed(position: Vector3) -> void:
	Audio.play_event(&"case_close", position)
