## Main menu: Play (the last unlocked stage), Stages, Options, Help and Quit, with a card on
## the progress: the stage Play leads to, its map, stages completed and the best grade.
class_name MainMenu
extends MenuScreen


var packed_stage_select := preload("res://gui/front/stage_select.tscn")
var packed_options_menu := preload("res://gui/options_menu/options_menu.tscn")
var packed_help_page := preload("res://gui/help_page.tscn")

@onready var button_play := %ButtonPlay as Button
@onready var button_stages := %ButtonStages as Button
@onready var button_options := %ButtonOptions as Button
@onready var button_help := %ButtonHelp as Button
@onready var button_quit := %ButtonQuit as Button
@onready var layout := %Layout as Control
@onready var next_title := %NextTitle as Label
@onready var thumbnail := %Thumbnail as TrackThumbnail
@onready var completed := %Completed as Label
@onready var best := %Best as Label


func _ready() -> void:
	allow_back = false
	initial_focus = button_play
	super()
	var _discard := button_play.pressed.connect(_on_play_pressed)
	_discard = button_stages.pressed.connect(open_submenu.bind(packed_stage_select, layout))
	_discard = button_options.pressed.connect(open_submenu.bind(packed_options_menu, layout))
	_discard = button_help.pressed.connect(open_submenu.bind(packed_help_page, layout))
	_discard = button_quit.pressed.connect(_on_quit_pressed)
	_discard = Progress.progress_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var stage := Progress.current_stage()
	next_title.text = stage.title() if stage else ""
	thumbnail.points = stage.road_points() if stage else PackedVector2Array()
	completed.text = "%d / %d" % [Progress.completed_count(), StageCatalog.get_default().stages.size()]
	var grade := Progress.overall_best()
	best.text = grade if not grade.is_empty() else "—"
	best.add_theme_color_override(&"font_color",
			UIPalette.grade_color(grade) if not grade.is_empty() else UIPalette.TEXT_2)


func _on_play_pressed() -> void:
	SceneTransition.start_stage(Progress.current_stage())


func _on_quit_pressed() -> void:
	var confirmed: bool = await UI.confirm("MENU_QUIT_CONFIRM", "MENU_QUIT", "UI_CANCEL", true)
	if confirmed:
		get_tree().quit()
