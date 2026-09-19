## Row of a setting (label, slider and value) that lights up with the accent bar while the
## control inside it has the focus: a slider alone only recolors its grabber, too little to
## see from the couch.
class_name SliderRow
extends PanelContainer


func _ready() -> void:
	theme_type_variation = &"SliderRow"
	var _discard := get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _exit_tree() -> void:
	if get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
		get_viewport().gui_focus_changed.disconnect(_on_focus_changed)


func has_focus_inside() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus != null and is_ancestor_of(focus)


func _on_focus_changed(_control: Control) -> void:
	if has_focus_inside():
		add_theme_stylebox_override(&"panel", get_theme_stylebox(&"focus", &"SliderRow"))
	else:
		remove_theme_stylebox_override(&"panel")
