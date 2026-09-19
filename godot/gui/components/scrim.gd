## Dark backdrop of the menus shown over the 3D stage: the scene behind, blurred and darkened
## (UIPalette.SCRIM). With the blur turned off in GameSettings it is the plain dark color.
## MenuScreen draws it itself through `blur_material()`; overlays add this node.
class_name Scrim
extends ColorRect


const SHADER := preload("res://gui/theme/scrim_blur.gdshader")

static var _material: ShaderMaterial = null


## The shared blur material, tinted with UIPalette.SCRIM.
static func blur_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter(&"tint", UIPalette.SCRIM)
	return _material


## The material a scrim should use now: the blur, or none (plain color) when turned off.
static func current_material() -> ShaderMaterial:
	return blur_material() if GameSettings.menu_blur_enabled() else null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = UIPalette.SCRIM
	_apply_settings()
	var _discard := GameSettings.game_settings_updated.connect(_apply_settings)


func _apply_settings() -> void:
	material = current_material()
