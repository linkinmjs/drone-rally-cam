## Wordmark of the game: "DRONE RALLY" over "CAM" in Recursive Bold, between the corner
## brackets of a camera frame, with the red REC dot in the top right corner. Drawn in code;
## it fits its rect, so the pause menu uses it small and the title screen big.
@tool
class_name Logo
extends Control


## Height of the logo when laid out (its minimum size follows).
@export var logo_height := 120.0:
	set(value):
		logo_height = value
		update_minimum_size()
		queue_redraw()
## Show the REC dot blinking, like a camera that is recording.
@export var blink := false

## Proportions at a height of 1: text size, gap between text and frame, bracket arm and width.
const TEXT := 0.26
const PAD := 0.13
const ARM := 0.2
const STROKE := 0.035
const DOT := 0.055
const LINES := ["DRONE RALLY", "CAM"]

static var _font: Font = null

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(blink and not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_time = fmod(_time + delta, 1.2)
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(width_for(logo_height), logo_height)


static func font() -> Font:
	if _font == null:
		_font = load(UIPalette.FONT_BOLD) as Font
	return _font


## Width of the logo drawn `height` pixels tall.
static func width_for(height: float) -> float:
	var font_size := int(round(height * TEXT))
	var text_width := 0.0
	for line: String in LINES:
		text_width = maxf(text_width, font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return ceilf(text_width + height * PAD * 2.0 + height * STROKE * 2.0)


func _draw() -> void:
	var height := minf(size.y, size.x * logo_height / maxf(width_for(logo_height), 1.0))
	var width := width_for(height)
	var origin := Vector2((size.x - width) / 2.0, (size.y - height) / 2.0)
	var frame := Rect2(origin, Vector2(width, height))
	var stroke := maxf(height * STROKE, 1.5)
	var arm := height * ARM

	# Corner brackets of the camera frame.
	var inner := frame.grow(-stroke / 2.0)
	var corners := [
		[inner.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(inner.end.x, inner.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(inner.position.x, inner.end.y), Vector2(1, 0), Vector2(0, -1)],
		[inner.end, Vector2(-1, 0), Vector2(0, -1)],
	]
	for corner: Array in corners:
		var p: Vector2 = corner[0]
		draw_polyline(PackedVector2Array([p + corner[1] * arm, p, p + corner[2] * arm]),
				UIPalette.TEXT, stroke, true)

	# The two lines of text, left aligned inside the frame; CAM in the accent color.
	var font_size := int(round(height * TEXT))
	var f := font()
	var line_height := f.get_ascent(font_size) + f.get_descent(font_size) * 0.2
	var text_x := frame.position.x + stroke + height * PAD
	var block := line_height * LINES.size()
	var baseline := frame.position.y + (height - block) / 2.0 + f.get_ascent(font_size)
	for i in LINES.size():
		var color := UIPalette.ACCENT if i == LINES.size() - 1 else UIPalette.TEXT
		draw_string(f, Vector2(text_x, baseline + i * line_height), LINES[i], HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, color)

	# REC dot in the top right corner, inside the brackets.
	var dot_alpha := 1.0 if not blink or _time < 0.8 else 0.25
	var dot_center := Vector2(inner.end.x - arm * 0.55, inner.position.y + arm * 0.55)
	draw_circle(dot_center, height * DOT, Color(UIPalette.HUD_REC, dot_alpha), true, -1.0, true)
