## Root of a stage scene: the generated terrain and road, the cars and where the player
## starts. Hands the driving line to the cars once the builder is done.
class_name StageWorld
extends Node3D


@onready var builder := $StageBuilder as StageBuilder
@onready var car := $RallyCar as RallyCar
@onready var player_spawn := $PlayerSpawn as Marker3D


func _ready() -> void:
	if not builder.is_built():
		builder.build()
	car.setup(builder.driving_curve, builder.global_transform)


## Player start, placed on the ground.
func get_player_spawn_transform() -> Transform3D:
	var xform := player_spawn.global_transform
	xform.origin.y = get_ground_height(xform.origin) + 0.05
	return xform


## Terrain height below a world position.
func get_ground_height(world_position: Vector3) -> float:
	var local := builder.to_local(world_position)
	return builder.to_global(Vector3(local.x, builder.get_height(local.x, local.z), local.z)).y
