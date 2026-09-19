## The saved progress of the player: one StageProgress per stage id. Saved as a .tres by the
## Progress autoload.
class_name SaveData
extends Resource


const VERSION := 1

@export var version := VERSION
@export var stages: Dictionary[StringName, StageProgress] = {}
