## Thin horizontal bar for a 0..1 score, drawn by code so it keeps the HUD look instead of
## inheriting the menu theme. The fill goes from red through amber to green.
class_name ScoreBar
extends Control


@export_range(0.0, 1.0) var value := 0.0:
	set(new_value):
		value = clampf(new_value, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(180, 14)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(1, 1, 1, 0.12))
	if value > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * value, rect.size.y)),
				HudStyle.score_color(value))
	draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)
