class_name GUIControllerAxis
extends TextureProgressBar


var texture_path := "res://Assets/GUI/ControlAxes.png"

var color_on := UIPalette.ACCENT
var color_off := UIPalette.SURFACE_PRESSED

func _ready() -> void:
	custom_minimum_size = Vector2(200, 14)
	set_range(-1.0, 1.0, 0.01)
	value = 0.0
	nine_patch_stretch = true
	stretch_margin_top = 5
	stretch_margin_bottom = 5
	stretch_margin_left = 5
	stretch_margin_right = 5
	texture_progress = ThemeBuilder.bar_texture()
	tint_progress = color_on
	texture_under = texture_progress
	tint_under = color_off
	tint_under.a = 1.0


func set_range(vmin: float, vmax: float, vstep: float) -> void:
	min_value = vmin
	max_value = vmax
	step = vstep
	value = clampf(value, min_value, max_value)


func set_color_on(color: Color, update_color_off: bool) -> void:
	color_on = color
	tint_progress = color_on
	if update_color_off:
		reset_color_off()


func set_color_off(color: Color) -> void:
	color_off = color
	tint_under = color_off


func reset_color_off() -> void:
	# Light theme: the "off" state is a pale version of the "on" color
	color_off = color_on.lerp(UIPalette.SURFACE, 0.82)
	color_off.a = 1.0
	tint_under = color_off
