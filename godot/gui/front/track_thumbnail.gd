## Drawing of a stage's road for the menus, from its control points (StageInfo.road_points),
## without building the stage: the line, the start (green) and the finish (checkered).
@tool
class_name TrackThumbnail
extends Control


@export var points: PackedVector2Array = []:
	set(value):
		points = value
		_line = StageBuilder.spline_points(points, 8) if points.size() >= 2 else PackedVector2Array()
		queue_redraw()
@export var line_color := UIPalette.TEXT
@export var line_width := 4.0

var _line: PackedVector2Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if _line.size() < 2:
		return
	var bounds := Rect2(_line[0], Vector2.ZERO)
	for point in _line:
		bounds = bounds.expand(point)
	var margin := line_width * 3.0
	var area := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)
	var scale := minf(area.size.x / maxf(bounds.size.x, 1.0), area.size.y / maxf(bounds.size.y, 1.0))
	var offset := area.position + (area.size - bounds.size * scale) / 2.0
	var mapped := PackedVector2Array()
	for point in _line:
		mapped.append(offset + (point - bounds.position) * scale)
	draw_polyline(mapped, Color(UIPalette.BG, 0.8), line_width + 4.0, true)
	draw_polyline(mapped, line_color, line_width, true)
	var radius := line_width * 1.6
	draw_circle(mapped[0], radius + 2.0, UIPalette.BG, true, -1.0, true)
	draw_circle(mapped[0], radius, UIPalette.SUCCESS, true, -1.0, true)
	# Finish: a small checkered square.
	var end := mapped[mapped.size() - 1]
	var cell := radius * 0.8
	draw_rect(Rect2(end - Vector2(cell, cell) - Vector2(2, 2), Vector2(cell, cell) * 2.0 + Vector2(4, 4)), UIPalette.BG)
	for i in 2:
		for j in 2:
			draw_rect(Rect2(end - Vector2(cell, cell) + Vector2(i, j) * cell, Vector2(cell, cell)),
					UIPalette.TEXT if (i + j) % 2 == 0 else UIPalette.SURFACE_PRESSED)
