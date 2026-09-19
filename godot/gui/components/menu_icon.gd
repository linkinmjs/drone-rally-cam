## Line icons of the options hub, drawn in code with the palette: the viewfinder frame (game
## and HUD), a speaker (audio), a gamepad (controls), a monitor (graphics).
@tool
class_name MenuIcon
extends Control


enum Kind {HUD, AUDIO, CONTROLS, GRAPHICS}

@export var kind := Kind.HUD:
	set(value):
		kind = value
		queue_redraw()
@export var color := UIPalette.ACCENT:
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(56, 56)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var w := maxf(s * 0.06, 2.0)
	match kind:
		Kind.HUD:
			var arm := s * 0.24
			for corner: Array in [[Vector2(0.08, 0.14), 1, 1], [Vector2(0.92, 0.14), -1, 1],
					[Vector2(0.08, 0.86), 1, -1], [Vector2(0.92, 0.86), -1, -1]]:
				var p := o + (corner[0] as Vector2) * s
				draw_polyline(PackedVector2Array([p + Vector2(corner[1] * arm, 0), p,
						p + Vector2(0, corner[2] * arm)]), UIPalette.TEXT, w, true)
			var c := o + Vector2(0.5, 0.5) * s
			draw_arc(c, s * 0.13, 0.0, TAU, 32, color, w, true)
			draw_circle(o + Vector2(0.8, 0.26) * s, s * 0.05, UIPalette.HUD_REC, true, -1.0, true)
		Kind.AUDIO:
			var body := PackedVector2Array([o + Vector2(0.12, 0.38) * s, o + Vector2(0.3, 0.38) * s,
					o + Vector2(0.5, 0.2) * s, o + Vector2(0.5, 0.8) * s, o + Vector2(0.3, 0.62) * s,
					o + Vector2(0.12, 0.62) * s, o + Vector2(0.12, 0.38) * s])
			draw_polyline(body, UIPalette.TEXT, w, true)
			var c := o + Vector2(0.5, 0.5) * s
			draw_arc(c, s * 0.18, -0.8, 0.8, 16, color, w, true)
			draw_arc(c, s * 0.33, -0.85, 0.85, 20, color, w, true)
		Kind.CONTROLS:
			var body := StyleBoxFlat.new()
			body.draw_center = false
			body.set_border_width_all(int(w))
			body.border_color = UIPalette.TEXT
			body.set_corner_radius_all(int(s * 0.18))
			body.anti_aliasing = true
			draw_style_box(body, Rect2(o + Vector2(0.06, 0.24) * s, Vector2(0.88, 0.52) * s))
			var cross := o + Vector2(0.3, 0.5) * s
			var arm := s * 0.08
			draw_line(cross - Vector2(arm, 0), cross + Vector2(arm, 0), color, w, true)
			draw_line(cross - Vector2(0, arm), cross + Vector2(0, arm), color, w, true)
			draw_circle(o + Vector2(0.66, 0.44) * s, s * 0.045, color, true, -1.0, true)
			draw_circle(o + Vector2(0.76, 0.56) * s, s * 0.045, color, true, -1.0, true)
		Kind.GRAPHICS:
			var screen := StyleBoxFlat.new()
			screen.draw_center = false
			screen.set_border_width_all(int(w))
			screen.border_color = UIPalette.TEXT
			screen.set_corner_radius_all(int(s * 0.06))
			screen.anti_aliasing = true
			draw_style_box(screen, Rect2(o + Vector2(0.08, 0.16) * s, Vector2(0.84, 0.54) * s))
			draw_line(o + Vector2(0.5, 0.7) * s, o + Vector2(0.5, 0.84) * s, UIPalette.TEXT, w, true)
			draw_line(o + Vector2(0.32, 0.84) * s, o + Vector2(0.68, 0.84) * s, UIPalette.TEXT, w, true)
			draw_polyline(PackedVector2Array([o + Vector2(0.2, 0.6) * s, o + Vector2(0.4, 0.36) * s,
					o + Vector2(0.55, 0.52) * s, o + Vector2(0.66, 0.42) * s, o + Vector2(0.8, 0.6) * s]),
					color, w, true)
