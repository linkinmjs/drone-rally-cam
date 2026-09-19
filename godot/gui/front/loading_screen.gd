## Shown while a stage is built (SceneTransition.start_stage): the stage, its map, the real
## progress of StageBuilder.build_async, a tip and the main controls of the device in use.
class_name LoadingScreen
extends Control


const TIPS: Array[String] = ["TIP_TABLET", "TIP_THIRDS", "TIP_STABLE", "TIP_BATTERY", "TIP_STREAK",
		"TIP_CRASH", "TIP_GIMBAL", "TIP_STABILIZED"]

@onready var stage_number := %StageNumber as Label
@onready var stage_name := %StageName as Label
@onready var description := %Description as Label
@onready var thumbnail := %Thumbnail as TrackThumbnail
@onready var bar := %ProgressBar as ProgressBar
@onready var step := %Step as Label
@onready var tip := %Tip as Label
@onready var controls := %Controls as HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tip.text = TIPS[randi() % TIPS.size()]
	for control: Array in PauseMenu.CONTROLS.slice(0, 4):
		var key := KeyCap.new()
		key.action = control[0]
		key.menu = false
		controls.add_child(key)
		var label := Label.new()
		label.theme_type_variation = &"HintLabel"
		label.text = control[1]
		controls.add_child(label)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(18, 0)
		controls.add_child(gap)
	set_progress(0.0, "LOADING_TERRAIN")


func show_stage(info: StageInfo) -> void:
	if not is_node_ready():
		await ready
	stage_number.text = tr("STAGE_NUMBER") % info.number
	stage_name.text = info.display_name
	description.text = info.description
	thumbnail.points = info.road_points()


## Progress of the build, 0 to 1, and a translation key saying what is being built.
func set_progress(fraction: float, label: String) -> void:
	if not is_node_ready():
		return
	bar.value = maxf(bar.value, clampf(fraction, 0.0, 1.0) * 100.0)
	step.text = label


func get_progress() -> float:
	return bar.value / 100.0
