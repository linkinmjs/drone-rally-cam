## Shared look of the on-screen text: the HUD's monospaced font with an outline, readable over
## sky and terrain alike.
class_name HudStyle
extends RefCounted


const WHITE := Color(0.95, 0.96, 0.97)
const DIM := Color(0.95, 0.96, 0.97, 0.55)
const RED := Color(0.95, 0.2, 0.18)
const AMBER := Color(1.0, 0.72, 0.2)
const GREEN := Color(0.35, 0.9, 0.45)

static var _font: Font = null


static func mono_font() -> Font:
	if not _font:
		_font = load(UIPalette.FONT_MONO) as Font
	return _font


static func make_label(text := "", font_size := 22, color := WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_override("font", mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", maxi(font_size / 6, 2))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Places `control` at a corner or edge of its parent with a margin. It grows inwards (or
## both ways when centred) as its text changes.
static func anchor(control: Control, preset: Control.LayoutPreset, margin := 28.0) -> void:
	control.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(margin))
	control.grow_horizontal = _grow_for(control.anchor_left, control.anchor_right)
	control.grow_vertical = _grow_for(control.anchor_top, control.anchor_bottom)


static func _grow_for(start: float, end: float) -> Control.GrowDirection:
	if is_equal_approx(start, 0.5) and is_equal_approx(end, 0.5):
		return Control.GROW_DIRECTION_BOTH
	if is_equal_approx(start, 1.0):
		return Control.GROW_DIRECTION_BEGIN
	return Control.GROW_DIRECTION_END


## Color from red (0) through amber to green (1).
static func score_color(score: float) -> Color:
	if score < 0.5:
		return RED.lerp(AMBER, score / 0.5)
	return AMBER.lerp(GREEN, (score - 0.5) / 0.5)


## "m:ss" for a duration in seconds.
static func format_time(seconds: float) -> String:
	var total := maxi(int(seconds), 0)
	return "%d:%02d" % [int(total / 60.0), total % 60]
