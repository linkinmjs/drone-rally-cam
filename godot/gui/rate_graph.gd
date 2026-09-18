extends Control


var _pitch: Array[Vector2] = []
var _roll: Array[Vector2] = []
var _yaw: Array[Vector2] = []

var color_background := UIPalette.SURFACE_ALT
var color_frame := UIPalette.BORDER
var color_lines := UIPalette.GRAPH_GRID.darkened(0.08)
var color_pitch := UIPalette.GRAPH_PITCH
var color_roll := UIPalette.GRAPH_ROLL
var color_yaw := UIPalette.GRAPH_YAW

var graph_size := 300

var max_rates_label: RichTextLabel = null


func _ready() -> void:
	custom_minimum_size = Vector2(graph_size, graph_size)
	max_rates_label = RichTextLabel.new()
	add_child(max_rates_label)
	max_rates_label.position = Vector2(14, 12)
	max_rates_label.bbcode_enabled = true
	max_rates_label.fit_content = true
	max_rates_label.scroll_active = false
	max_rates_label.clip_contents = false
	max_rates_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	max_rates_label.add_theme_font_size_override(&"normal_font_size", 18)
	max_rates_label.custom_minimum_size = Vector2(graph_size * 0.5, 0)
	queue_redraw()


func update_rates(pitch: Array[Vector2], roll: Array[Vector2], yaw: Array[Vector2]) -> void:
	_pitch.clear()
	_roll.clear()
	_yaw.clear()
	_pitch = pitch
	_roll = roll
	_yaw = yaw
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(graph_size, graph_size))
	# Background and frame
	draw_style_box(ThemeBuilder.flat(color_background, 12, Vector4.ZERO, color_frame, 1), rect)
	# Grid
	for i in range(1, 4):
		var p := graph_size * i / 4.0
		var width := 1.5 if i == 2 else 1.0
		draw_line(Vector2(0, p), Vector2(graph_size, p), color_lines, width)
		draw_line(Vector2(p, 0), Vector2(p, graph_size), color_lines, width)
	if _pitch.is_empty():
		return
	# Rates
	var num_points := _pitch.size()
	var max_rate := maxf(maxf(maxf(_pitch[-1].y, _roll[-1].y), _yaw[-1].y), 1.0)
	var get_chart_point := func get_chart_point(point: Vector2) -> Vector2:
		var x := (point.x + 1) * graph_size / 2
		var y := (2 - (point.y / max_rate + 1)) * graph_size / 2
		return Vector2(x, y)
	var pitch: Array[Vector2] = []
	var roll: Array[Vector2] = []
	var yaw: Array[Vector2] = []
	for i in num_points:
		pitch.append(get_chart_point.call(_pitch[i]))
		roll.append(get_chart_point.call(_roll[i]))
		yaw.append(get_chart_point.call(_yaw[i]))
	draw_polyline(PackedVector2Array(yaw), color_yaw, 2.5, true)
	draw_polyline(PackedVector2Array(roll), color_roll, 2.5, true)
	draw_polyline(PackedVector2Array(pitch), color_pitch, 2.5, true)
	# Max rates
	max_rates_label.text = "[color=#%s]P  %d[/color]\n" % [color_pitch.to_html(false), _pitch[-1].y] \
			+ "[color=#%s]R  %d[/color]\n" % [color_roll.to_html(false), _roll[-1].y] \
			+ "[color=#%s]Y  %d[/color]" % [color_yaw.to_html(false), _yaw[-1].y]
