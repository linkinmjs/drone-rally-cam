## Marks a thing in the world on screen, for the current camera: a diamond with a label when
## it is in view, an arrow on the edge of the screen pointing toward it otherwise.
## Adapted from drone-simulator's HUDGateMarker (GPL-3.0).
class_name WorldMarker
extends Control


const EDGE_MARGIN := 0.8
## Room between the edge arrow and its label.
const LABEL_GAP := 14.0

var target: Node3D = null
## Added to the target's position, to mark above it instead of at its base.
var offset := Vector3.ZERO
var text := ""
var color := Color(0.55, 0.85, 1.0)
## True when the last draw found the target inside the screen.
var is_on_screen := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func distance_to_camera() -> float:
	var camera := get_viewport().get_camera_3d()
	if not camera or not is_instance_valid(target):
		return INF
	return camera.global_position.distance_to(target.global_position + offset)


func _draw() -> void:
	is_on_screen = false
	var camera := get_viewport().get_camera_3d()
	if not camera or not is_instance_valid(target):
		return
	var to_target := target.global_position + offset - camera.global_position
	if to_target.length() < 0.3:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var center := inverse * (viewport_size / 2.0)
	var projected := HUDDraw.project_direction(camera, to_target)
	var local := camera.global_transform.basis.inverse() * to_target.normalized()
	var screen_rect := Rect2(Vector2.ZERO, viewport_size).grow(-40.0)
	if local.z < 0.0 and projected.is_finite() and screen_rect.has_point(projected):
		is_on_screen = true
		var p := inverse * projected
		var diamond := PackedVector2Array([p + Vector2(0, -12), p + Vector2(12, 0),
				p + Vector2(0, 12), p + Vector2(-12, 0), p + Vector2(0, -12)])
		draw_polyline(diamond, HUDDraw.SHADOW, 6.0, true)
		draw_polyline(diamond, color, 3.0, true)
		HUDDraw.text(self, HUDDraw.font_mono(), p + Vector2(-140, -22), text, HudStyle.SIZE_S,
				HORIZONTAL_ALIGNMENT_CENTER, 280.0, color)
		return
	# Off screen: an arrow on an ellipse around the centre, pointing toward the target.
	var direction := Vector2(local.x, -local.y)
	if direction.length_squared() < 1e-6:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var radii := viewport_size / 2.0 * EDGE_MARGIN
	var edge := center + Vector2(direction.x * radii.x, direction.y * radii.y)
	var tip := edge + direction * 18.0
	var side := Vector2(-direction.y, direction.x) * 12.0
	var arrow := PackedVector2Array([tip, edge - direction * 6.0 + side, edge - direction * 6.0 - side])
	draw_colored_polygon(arrow, color)
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), HUDDraw.SHADOW, 2.0, true)
	var font := HUDDraw.font_mono()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, HudStyle.SIZE_S)
	var label_center := label_center_for(edge, direction, text_size)
	HUDDraw.text(self, font, label_center + Vector2(-140, 7), text, HudStyle.SIZE_S,
			HORIZONTAL_ALIGNMENT_CENTER, 280.0, color)


## Center of the label of an edge arrow at `edge` pointing along `direction`: inside the screen,
## far enough back that the text box (`text_size`) never covers the arrow.
static func label_center_for(edge: Vector2, direction: Vector2, text_size: Vector2) -> Vector2:
	var reach := absf(direction.x) * text_size.x / 2.0 + absf(direction.y) * text_size.y / 2.0
	return edge - direction * (reach + 6.0 + LABEL_GAP)
