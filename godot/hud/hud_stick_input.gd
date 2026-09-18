class_name HUDStickInput
extends Control
## Stick position display: translucent box, dotted cross and a ring for the stick.
## `update_stick_input(Vector2)` keeps the same convention as before (-1..1 per axis).


const TRAVEL := 50.0

var stick := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(128, 128)


func update_stick_input(input: Vector2) -> void:
	var clamped := input.clampf(-1.0, 1.0)
	if not clamped.is_equal_approx(stick):
		stick = clamped
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.HUD_BOX
	box.set_corner_radius_all(4)
	draw_style_box(box, rect)
	var c := size / 2.0
	var dim := Color(HUDDraw.WHITE, 0.7)
	HUDDraw.dashed_polyline(self, PackedVector2Array([Vector2(8, c.y), Vector2(size.x - 8, c.y)]),
			5.0, 5.0, 1.5, dim)
	HUDDraw.dashed_polyline(self, PackedVector2Array([Vector2(c.x, 8), Vector2(c.x, size.y - 8)]),
			5.0, 5.0, 1.5, dim)
	draw_circle(c, 2.5, dim, true, -1.0, true)
	var p := c + stick * TRAVEL
	HUDDraw.circle(self, p, 7.0, 2.5)
	draw_circle(p, 2.5, HUDDraw.WHITE, true, -1.0, true)
