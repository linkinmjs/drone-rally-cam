## Who the player controls: walking with the drone packed, walking with the drone deployed,
## or piloting. While piloting the view is either the stabilized gimbal (what gets recorded)
## or the pilot camera fixed to the frame. Only one input reader is active at a time.
class_name ControlState
extends Node


signal state_changed(state: State)
signal view_changed(view: View)
## Something the player tried was refused; `reason` is shown on screen.
signal action_refused(reason: String)

enum State {WALKING_NO_DRONE, WALKING_DRONE_DEPLOYED, PILOTING}
## GIMBAL: the camera that records. PILOT: fixed to the frame, leans with the drone.
enum View {GIMBAL, PILOT}

const DRONE_CASE := preload("res://player/drone_case.tscn")

@export var player_path: NodePath
@export var drone_path: NodePath
@export var radio_path: NodePath
@export var recorder_path: NodePath
## Farthest the drone can be for the player to pack it.
@export var recover_distance := 2.6

var state := State.WALKING_NO_DRONE
var view := View.GIMBAL
var drone_case: Node3D = null

@onready var player := get_node(player_path) as Player
@onready var drone := get_node(drone_path) as Drone
@onready var radio := get_node(radio_path) as RadioController
@onready var recorder := get_node(recorder_path) as Recorder
@onready var gimbal := drone.get_node("Gimbal") as Gimbal
@onready var pilot_camera := drone.get_node("PilotCamera") as PilotCamera
@onready var pickup := drone.get_node("PickupZone") as Interactable


func _ready() -> void:
	var _discard := player.deploy_requested.connect(deploy)
	_discard = player.deploy_refused.connect(action_refused.emit)
	_discard = pickup.interacted.connect(_on_pickup_interacted)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pilot_toggle"):
		toggle_pilot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("change_camera") and state == State.PILOTING:
		change_camera()
		get_viewport().set_input_as_handled()


## Switches between the gimbal and the pilot camera. Only while piloting; recording always
## uses the gimbal.
func change_camera() -> bool:
	if state != State.PILOTING:
		return false
	set_view(View.PILOT if view == View.GIMBAL else View.GIMBAL)
	return true


func set_view(new_view: View) -> void:
	if new_view == view:
		return
	view = new_view
	_apply()
	view_changed.emit(view)


## Opens the case at `ground` (a flat spot facing away from the player) and sets the drone
## down next to it, disarmed.
func deploy(ground: Transform3D) -> bool:
	if state != State.WALKING_NO_DRONE:
		return false
	drone_case = DRONE_CASE.instantiate() as Node3D
	drone.get_parent().add_child(drone_case)
	drone_case.global_transform = ground
	var spot := (drone_case.get_node("DroneSpot") as Node3D).global_transform
	spot.origin.y = _ground_height_at(spot.origin, spot.origin.y)
	drone.deploy(spot)
	drone.flight_controller.select_flight_mode(drone.flight_controller.default_mode)
	gimbal.snap()
	player.has_kit = false
	_set_state(State.WALKING_DRONE_DEPLOYED)
	EventBus.drone_deployed.emit(drone)
	return true


func toggle_pilot() -> bool:
	match state:
		State.WALKING_DRONE_DEPLOYED:
			_set_state(State.PILOTING)
			return true
		State.PILOTING:
			# Letting go of the sticks in Attitude or Acro would drop the drone: switch it to
			# position hold, like a camera drone does when the pilot releases the controls.
			if drone.flight_controller.state_armed \
					and not drone.flight_controller.flight_mode is FlightModeTrack:
				drone.flight_controller.select_flight_mode(FlightMode.Type.TRACK)
			_set_state(State.WALKING_DRONE_DEPLOYED)
			return true
		State.WALKING_NO_DRONE:
			action_refused.emit("Primero desplegá el dron.")
	return false


## Packs the drone (and its case) back. Only possible with the drone landed, disarmed and
## within reach.
func recover() -> bool:
	if state != State.WALKING_DRONE_DEPLOYED:
		return false
	if drone.flight_controller.state_armed:
		action_refused.emit("Desarmá el dron antes de guardarlo.")
		return false
	if player.global_position.distance_to(drone.global_position) > recover_distance + 1.0:
		action_refused.emit("El dron está demasiado lejos.")
		return false
	drone.stow()
	(drone.get_node("Battery") as Battery).recharge()
	if drone_case:
		drone_case.queue_free()
		drone_case = null
	player.has_kit = true
	_set_state(State.WALKING_NO_DRONE)
	EventBus.drone_recovered.emit(drone)
	return true


func _on_pickup_interacted(_player: Node3D) -> void:
	var _recovered := recover()


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var was_piloting := state == State.PILOTING
	state = new_state
	if was_piloting and recorder.recording:
		recorder.stop()
	# Taking the controller always starts on the gimbal, the camera that records.
	var view_reset := view != View.GIMBAL
	view = View.GIMBAL
	_apply()
	if view_reset:
		view_changed.emit(view)
	state_changed.emit(state)
	EventBus.control_state_changed.emit(state)


func _apply() -> void:
	var piloting := state == State.PILOTING
	player.set_active(not piloting)
	radio.enabled = piloting
	gimbal.input_enabled = piloting
	recorder.input_enabled = piloting
	pickup.enabled = state == State.WALKING_DRONE_DEPLOYED
	if piloting and view == View.PILOT:
		pilot_camera.make_current()
	elif piloting:
		gimbal.camera.make_current()
	else:
		player.camera.make_current()


func _ground_height_at(point: Vector3, fallback: float) -> float:
	var from := point + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else fallback
