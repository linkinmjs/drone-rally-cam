# From drone-simulator (GPL-3.0), 2026: renamed from TutorialStickHint, "to the centre" target,
# stick and target set separately, HUD panel style. It is the only stick widget on screen.
class_name StickHint
extends Control
## Small stick box: a ring shows where the stick is now and a pulsing arrow shows where it
## should go (a pulsing ring when it should go to the centre).
## Screen convention: up = Vector2(0, -1).


const TRAVEL_RATIO := 0.36
const TARGET_COLOR := HudStyle.SKY

var stick := Vector2.ZERO
var target := Vector2.ZERO
## When true the suggestion is "to the centre" (target is ignored).
var centre_target := false
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96, 96)


func set_values(current: Vector2, suggested: Vector2) -> void:
	stick = current.clampf(-1.0, 1.0)
	target = suggested.clampf(-1.0, 1.0)
	queue_redraw()


## Where the stick is now.
func set_stick(current: Vector2) -> void:
	var clamped := current.clampf(-1.0, 1.0)
	if clamped != stick:
		stick = clamped
		if is_visible_in_tree():
			queue_redraw()


## Where the stick should go: a direction, the centre, or nothing (Vector2.ZERO, false).
func set_target(suggested: Vector2, to_centre := false) -> void:
	var clamped := suggested.clampf(-1.0, 1.0)
	if clamped == target and to_centre == centre_target:
		return
	target = clamped
	centre_target = to_centre
	queue_redraw()


func has_target() -> bool:
	return target != Vector2.ZERO or centre_target


func _process(delta: float) -> void:
	if (target != Vector2.ZERO or centre_target) and is_visible_in_tree():
		_time += delta
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var box := HudStyle.panel(0.35)
	draw_style_box(box, rect)
	var center := size / 2.0
	var travel := minf(size.x, size.y) * TRAVEL_RATIO
	var dim := Color(HUDDraw.WHITE, 0.45)
	HUDDraw.dashed_polyline(self, PackedVector2Array([Vector2(10, center.y), Vector2(size.x - 10, center.y)]),
			4.0, 5.0, 1.2, dim)
	HUDDraw.dashed_polyline(self, PackedVector2Array([Vector2(center.x, 10), Vector2(center.x, size.y - 10)]),
			4.0, 5.0, 1.2, dim)

	if centre_target:
		var ring := fmod(_time, 1.1) / 1.1
		draw_arc(center, 22.0 - 12.0 * ring, 0.0, TAU, 32, Color(TARGET_COLOR, 0.35 + 0.6 * ring), 3.0, true)
		draw_circle(center, 5.0, TARGET_COLOR, true, -1.0, true)
	elif target != Vector2.ZERO:
		var pulse := fmod(_time, 1.1) / 1.1
		var tip := center + target * travel
		var head := center + target * travel * (0.25 + 0.75 * pulse)
		draw_line(center, tip, Color(TARGET_COLOR, 0.35), 6.0, true)
		draw_circle(head, 9.0, Color(TARGET_COLOR, 0.35 + 0.5 * (1.0 - pulse)), true, -1.0, true)
		var direction := target.normalized()
		var side := Vector2(-direction.y, direction.x) * 9.0
		var arrow := PackedVector2Array([tip + direction * 10.0, tip - direction * 4.0 + side,
				tip - direction * 4.0 - side])
		draw_colored_polygon(arrow, TARGET_COLOR)

	var p := center + stick * travel
	HUDDraw.circle(self, p, 8.0, 2.5)
	draw_circle(p, 3.0, HUDDraw.WHITE, true, -1.0, true)
