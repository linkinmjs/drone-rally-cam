## The stages of the game in championship order (stage_catalog.tres).
class_name StageCatalog
extends Resource


const DEFAULT_PATH := "res://world/stages/stage_catalog.tres"

@export var stages: Array[StageInfo] = []

static var _default: StageCatalog = null


static func get_default() -> StageCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH) as StageCatalog
	return _default


func find(id: StringName) -> StageInfo:
	for info in stages:
		if info.id == id:
			return info
	return null


## The stage played on the world scene `path` (a stage opened on its own).
func find_by_scene(path: String) -> StageInfo:
	for info in stages:
		if info.scene == path:
			return info
	return null


func index_of(id: StringName) -> int:
	for i in stages.size():
		if stages[i].id == id:
			return i
	return -1


## The stage after `id` in the championship, or null after the last one.
func next_after(id: StringName) -> StageInfo:
	var index := index_of(id)
	return stages[index + 1] if index >= 0 and index + 1 < stages.size() else null
