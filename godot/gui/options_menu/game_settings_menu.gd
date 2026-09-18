# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: no language or sky,
# gamepad stick navigation, L1/R1 switch tabs.
extends MenuScreen


## Order of the stick navigation options (StickNavigation.Scheme values), gamepad first.
const NAV_SCHEMES: Array[int] = [2, 0, 1]
const NAV_NAMES: Array[String] = ["GAME_STICK_NAVIGATION_GAMEPAD",
		"GAME_STICK_NAVIGATION_BETAFLIGHT", "GAME_STICK_NAVIGATION_YAW"]
const NAV_HELP: Array[String] = ["GAME_STICK_NAVIGATION_HELP_GAMEPAD",
		"GAME_STICK_NAVIGATION_HELP_BETAFLIGHT", "GAME_STICK_NAVIGATION_HELP_YAW"]


@onready var button_back := %ButtonBack as Button
@onready var tab_container := %TabContainer as TabContainer
@onready var nav_options := %NavOptions as OptionButton
@onready var nav_help := %NavHelp as Label


func _ready() -> void:
	initial_focus = nav_options
	section_tabs = tab_container
	super()
	tab_container.set_tab_title(0, "GAME_TAB_GAMEPLAY")
	tab_container.set_tab_title(1, "GAME_TAB_HUD")

	for nav_name in NAV_NAMES:
		nav_options.add_item(nav_name)
	nav_options.select(maxi(NAV_SCHEMES.find(GameSettings.get_nav_scheme()), 0))
	_update_nav_help()
	var _discard := nav_options.item_selected.connect(_on_nav_scheme_selected)

	bind_back_button(button_back)


func _on_nav_scheme_selected(idx: int) -> void:
	GameSettings.set_nav_scheme(NAV_SCHEMES[idx])
	_update_nav_help()


func _update_nav_help() -> void:
	nav_help.text = NAV_HELP[maxi(NAV_SCHEMES.find(GameSettings.get_nav_scheme()), 0)]
