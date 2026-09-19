## First scene of the game: the title over a live 3D backdrop, then the main menu, from which
## the stages start (SceneTransition). Coming back from a stage it opens the menu directly.
class_name Main
extends Node


const MAIN_MENU := preload("res://gui/front/main_menu.tscn")

var main_menu: MainMenu = null

@onready var screens := $Screens as CanvasLayer
@onready var title_screen := $Screens/TitleScreen as TitleScreen
@onready var backdrop := $TitleBackdrop as TitleBackdrop


func _ready() -> void:
	get_tree().paused = false
	UI.show_mouse()
	if SceneTransition.current_payload().get("screen", "") == "menu":
		show_menu()
	else:
		var _discard := title_screen.start_pressed.connect(show_menu)


func show_menu() -> void:
	if main_menu:
		return
	if is_instance_valid(title_screen):
		title_screen.queue_free()
	main_menu = MAIN_MENU.instantiate() as MainMenu
	screens.add_child(main_menu)
