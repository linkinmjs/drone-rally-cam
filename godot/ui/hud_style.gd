## The one visual recipe of everything drawn over the game view (viewfinder, flight HUD,
## on-foot overlay, tablet): layout grid, five text sizes, one panel, colors and one legibility
## treatment (an outline that reads over sky and terrain alike).
## The menus have their own theme (gui/theme); only REC, the accent and the fonts are shared
## with it, through UIPalette.
class_name HudStyle
extends RefCounted


## Layout grid, in pixels at 1920×1080.
const MARGIN := 48.0
const GUTTER := 16.0
const COLUMN_W := 440.0
## Top of the clip summary, under the right column of readouts.
const SUMMARY_TOP := 380.0

## Text sizes.
const SIZE_XS := 14
const SIZE_S := 18
const SIZE_M := 22
const SIZE_L := 28
const SIZE_XL := 44
## Only for the big grade letter of a clip.
const SIZE_DISPLAY := 64

const WHITE := Color(0.95, 0.96, 0.97)
## Secondary text. Opaque: a translucent fill lets the outline show through the glyphs, which
## then read grey and blurry over a bright image.
const DIM := Color(0.74, 0.76, 0.79)
const RED := UIPalette.HUD_REC
const AMBER := Color(1.0, 0.72, 0.2)
const GREEN := Color(0.35, 0.9, 0.45)
const ACCENT := UIPalette.ACCENT
const SKY := Color(0.55, 0.85, 1.0)
## Outline behind every text and line, for legibility over a bright or busy image.
const OUTLINE := Color(0, 0, 0, 0.6)
## Soft edge behind vector strokes (lines, rings).
const SHADOW := Color(0, 0, 0, 0.35)
const PANEL_BG := Color(0.02, 0.03, 0.04, 0.55)

static var _mono: Font = null
static var _bold: Font = null


static func mono_font() -> Font:
	if not _mono:
		_mono = load(UIPalette.FONT_MONO) as Font
	return _mono


static func bold_font() -> Font:
	if not _bold:
		_bold = load(UIPalette.FONT_BOLD) as Font
	return _bold


static func outline_size(font_size: int) -> int:
	return maxi(int(font_size / 6.0), 3)


## A text label with the HUD look: mono for values and messages, bold for titles.
static func make_label(text := "", font_size := SIZE_M, color := WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_override("font", bold_font() if bold else mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", outline_size(font_size))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Changes a label's color only when it differs: a theme override invalidates the theme cache.
static func set_color(label: Label, color: Color) -> void:
	if label.get_theme_color("font_color") != color:
		label.add_theme_color_override("font_color", color)


## The panel behind groups of HUD text.
static func panel(alpha := PANEL_BG.a, radius := 8, margin := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG, alpha)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## Places `control` at a corner or edge of its parent with a margin. It grows inwards (or
## both ways when centred) as its content changes.
static func anchor(control: Control, preset: Control.LayoutPreset, margin := MARGIN) -> void:
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


## "m:ss" for a countdown or a stage time.
static func format_time(seconds: float) -> String:
	var total := maxi(int(seconds), 0)
	return "%d:%02d" % [int(total / 60.0), total % 60]


## Length of a clip: tenths of a second under a minute ("12,4 s"), "m:ss" above.
static func format_duration(seconds: float) -> String:
	if seconds < 60.0:
		return "%s s" % decimal(maxf(seconds, 0.0))
	return format_time(seconds)


## A number with `digits` decimals and the decimal separator of the language ("0,7" in Spanish).
static func decimal(value: float, digits := 1) -> String:
	var number := ("%." + str(digits) + "f") % value
	if TranslationServer.get_locale().begins_with("es"):
		number = number.replace(".", ",")
	return number
