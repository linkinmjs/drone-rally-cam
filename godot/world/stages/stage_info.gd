## One stage of the game for the menus: name, the world scene to load, a line of description,
## its length and what unlocks it.
class_name StageInfo
extends Resource


@export var id: StringName = &""
## Position in the championship ("Etapa 2").
@export var number := 1
@export var display_name := ""
## World scene (a StageWorld) the stage is played on.
@export_file("*.tscn") var scene := ""
@export_multiline var description := ""
@export var length_km := 0.0
## Stage whose clips unlock this one; empty when it is open from the start.
@export var unlock_after: StringName = &""
## Grade (or better) of a clip delivered on `unlock_after` that unlocks this stage.
@export var unlock_grade := "B"


## "Etapa 2 · Lomas del valle"
func title() -> String:
	return "Etapa %d · %s" % [number, display_name]


## Control points of the road, read from the world scene without building it (for the maps
## of the menus).
func road_points() -> PackedVector2Array:
	var packed := load(scene) as PackedScene
	if packed == null:
		return PackedVector2Array()
	var state := packed.get_state()
	for node in state.get_node_count():
		for property in state.get_node_property_count(node):
			if state.get_node_property_name(node, property) == &"road_points":
				return state.get_node_property_value(node, property)
	return PackedVector2Array()
