## Root of a stage scene: the generated terrain and road, the cars and where the player
## starts. Hands the driving line to the cars once the builder is done.
##
## Opened on its own (editor, checks, tour) it builds at once in _ready. The loading screen
## calls defer_build() before adding it to the tree and then awaits build_ready(), which builds
## in steps (StageBuilder.build_async) so the window keeps drawing.
class_name StageWorld
extends Node3D


## The terrain, road and scenery are built and the cars know their route.
signal world_ready

var build_async := false
var is_ready := false

@onready var builder := $StageBuilder as StageBuilder
@onready var car := $RallyCar as RallyCar
@onready var player_spawn := $PlayerSpawn as Marker3D


func _ready() -> void:
	if build_async:
		return
	if not builder.is_built():
		builder.build()
	_finish()


## Call before the world enters the tree: it then builds in steps when build_ready() is awaited.
func defer_build() -> void:
	build_async = true
	(get_node("StageBuilder") as StageBuilder).build_on_ready = false


## Builds the world if it is not built yet (in steps) and sets up the cars.
func build_ready() -> void:
	if is_ready:
		return
	if not builder.is_built():
		await builder.build_async()
	_finish()


func _finish() -> void:
	car.setup(builder.driving_curve, builder.global_transform)
	is_ready = true
	world_ready.emit()


## Player start, placed on the ground.
func get_player_spawn_transform() -> Transform3D:
	var xform := player_spawn.global_transform
	xform.origin.y = get_ground_height(xform.origin) + 0.05
	return xform


## Terrain height below a world position.
func get_ground_height(world_position: Vector3) -> float:
	var local := builder.to_local(world_position)
	return builder.to_global(Vector3(local.x, builder.get_height(local.x, local.z), local.z)).y
