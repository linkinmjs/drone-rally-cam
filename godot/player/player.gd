## The camera operator on foot: walks, jogs and crouches (no jumping), slower uphill.
## Carries the drone kit and asks to deploy it where it is looking.
class_name Player
extends CharacterBody3D


## Emitted when the player wants to set the kit down. `ground` is a flat spot in front of them.
signal deploy_requested(ground: Transform3D)
signal deploy_refused(reason: String)

## Render layer of what only the player's own camera sees (the case in their hand).
const VIEW_MODEL_LAYER := 512

@export var walk_speed := 2.2
@export var sprint_speed := 4.5
@export var crouch_speed := 1.2
@export var acceleration := 10.0
@export var gravity := 9.81
## Every degree of slope costs speed: at this slope the player walks at 40 % of the speed.
@export var slowest_slope_deg := 35.0
@export var mouse_sensitivity := 0.0025
## Gamepad look speed at full stick deflection, in rad/s.
@export var stick_look_speed := 2.6
@export var stand_eye_height := 1.65
@export var crouch_eye_height := 1.0
## Steepest ground, in degrees, where the drone case can be opened.
@export var max_deploy_slope_deg := 15.0
## Head bob at walking speed (m) and steps per meter.
@export var bob_amount := 0.035
@export var steps_per_meter := 0.75
## How far in front of the feet the drone is set down.
@export var deploy_distance := 1.4

## False while the player holds the drone controller: no walking or looking around.
var active := true
## True while the player carries the drone in its case.
var has_kit := true
var is_crouching := false
## The ground under a position: &"gravel" or &"grass" (set by the stage, for the footsteps).
var ground_surface := func(_at: Vector3) -> StringName: return &"grass"

var _step_phase := 0.0

@onready var head := $Head as Node3D
@onready var camera := $Head/Camera3D as Camera3D
@onready var interact_ray := $Head/InteractRay as RayCast3D
@onready var held_case := $Head/HeldCase as Node3D


func _ready() -> void:
	head.position.y = stand_eye_height


func set_active(value: bool) -> void:
	active = value
	if not active:
		velocity.x = 0.0
		velocity.z = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_look(motion.relative * mouse_sensitivity)
	elif event.is_action_pressed("interact"):
		interact()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var move := Vector2.ZERO
	if active:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		_look(stick * stick_look_speed * delta)
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		is_crouching = Input.is_action_pressed("crouch")

	var eye := crouch_eye_height if is_crouching else stand_eye_height
	head.position.y = lerpf(head.position.y, eye, 1.0 - exp(-10.0 * delta))

	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif Input.is_action_pressed("sprint") and active:
		speed = sprint_speed
	speed *= _slope_factor()

	var direction := (global_basis * Vector3(move.x, 0.0, move.y))
	direction.y = 0.0
	direction = direction.normalized() * minf(move.length(), 1.0)
	var target := direction * speed
	var weight := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)
	move_and_slide()
	_bob(delta)
	held_case.visible = has_kit


## The camera bobs with the steps, less when crouching, and every step is announced.
func _bob(delta: float) -> void:
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or ground_speed < 0.3:
		camera.position = camera.position.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
		return
	var previous := _step_phase
	_step_phase += ground_speed * steps_per_meter * delta * PI
	if floori(_step_phase / PI) != floori(previous / PI):
		EventBus.player_step.emit(ground_surface.call(global_position))
	var amount := bob_amount * clampf(ground_speed / walk_speed, 0.0, 1.6) * (0.5 if is_crouching else 1.0)
	camera.position = Vector3(sin(_step_phase) * amount * 0.5, -absf(cos(_step_phase)) * amount, 0.0)


## The interactable the player is looking at, if any.
func get_aimed_interactable() -> Interactable:
	if not interact_ray.is_colliding():
		return null
	var target := interact_ray.get_collider() as Interactable
	if target and target.can_interact(self):
		return target
	return null


## Short text for the on-screen prompt: what "interact" would do right now.
func get_prompt() -> String:
	var target := get_aimed_interactable()
	if target:
		return target.prompt
	if has_kit:
		return "Desplegar el dron"
	return ""


func interact() -> void:
	var target := get_aimed_interactable()
	if target:
		target.interact(self)
	elif has_kit:
		var spot: Variant = find_deploy_spot()
		if spot is Transform3D:
			deploy_requested.emit(spot)
		else:
			deploy_refused.emit(spot as String)


## A flat spot in front of the player, facing away from them, or a String with the reason
## why there is none.
func find_deploy_spot() -> Variant:
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var above := global_position + forward * deploy_distance + Vector3.UP * 1.5
	var query := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 4.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "No hay suelo donde apoyar la maleta."
	var normal := hit["normal"] as Vector3
	if normal.angle_to(Vector3.UP) > deg_to_rad(max_deploy_slope_deg):
		return "El terreno está muy inclinado para abrir la maleta."
	var basis := Basis.looking_at(forward, Vector3.UP)
	return Transform3D(basis, hit["position"] as Vector3)


func _look(amount: Vector2) -> void:
	rotate_y(-amount.x)
	head.rotation.x = clampf(head.rotation.x - amount.y, deg_to_rad(-85.0), deg_to_rad(85.0))


## 1 on flat ground, lower on slopes (uphill and downhill alike).
func _slope_factor() -> float:
	if not is_on_floor():
		return 1.0
	var slope := get_floor_normal().angle_to(Vector3.UP)
	return lerpf(1.0, 0.4, clampf(slope / deg_to_rad(slowest_slope_deg), 0.0, 1.0))
