## Top view of the stage for the tablet: the road with its start and finish, the spot the car
## will pass closest to the player, and where the player, the drone and the car are.
## North (-Z) is up.
class_name StageMap
extends Control


const GROUND := Color(0.16, 0.21, 0.15)
const ROAD := Color(0.9, 0.8, 0.6)
const START := Color(0.4, 0.9, 0.45)
const FINISH := Color(0.95, 0.95, 0.95)
const PLAYER := Color(1.0, 1.0, 1.0)
const DRONE := Color(0.55, 0.85, 1.0)
const CAR := Color(1.0, 0.35, 0.3)
const SPOT := Color(1.0, 0.75, 0.25)
const MARGIN := 28.0

var stage: Stage = null
var _road: PackedVector2Array = []
var _bounds := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func setup(new_stage: Stage) -> void:
	stage = new_stage
	var builder := stage.world.builder
	_road.clear()
	for sample in builder.road_samples:
		var world := builder.to_global(sample)
		_road.append(Vector2(world.x, world.z))
	_bounds = Rect2(_road[0], Vector2.ZERO) if not _road.is_empty() else Rect2()
	for point in _road:
		_bounds = _bounds.expand(point)
	_bounds = _bounds.grow(40.0)
	queue_redraw()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


## Map position of a world position.
func to_map(world: Vector3) -> Vector2:
	var area := Rect2(Vector2.ONE * MARGIN, size - Vector2.ONE * MARGIN * 2.0)
	if _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0 or area.size.x <= 0.0:
		return size / 2.0
	var scale := minf(area.size.x / _bounds.size.x, area.size.y / _bounds.size.y)
	var used := _bounds.size * scale
	var origin := area.position + (area.size - used) / 2.0
	return origin + (Vector2(world.x, world.z) - _bounds.position) * scale


func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GROUND
	style.set_corner_radius_all(10)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	if not stage or _road.size() < 2:
		return

	var points := PackedVector2Array()
	for point in _road:
		points.append(to_map(Vector3(point.x, 0.0, point.y)))
	draw_polyline(points, Color(0, 0, 0, 0.45), 10.0, true)
	draw_polyline(points, ROAD, 5.0, true)

	var font := HUDDraw.font_mono()
	_draw_flag(points[0], START, "LARGADA", font)
	_draw_flag(points[-1], FINISH, "META", font)

	# Where the car passes closest to the player (or to the drone once it is out).
	var builder := stage.world.builder
	var offset := stage.reference_route_offset()
	var spot := builder.to_global(builder.driving_curve.sample_baked(offset))
	var spot_map := to_map(spot)
	draw_circle(spot_map, 9.0, Color(0, 0, 0, 0.5))
	draw_arc(spot_map, 9.0, 0.0, TAU, 24, SPOT, 3.0, true)

	if stage.control.state != ControlState.State.WALKING_NO_DRONE:
		var d := to_map(stage.drone.global_position)
		var diamond := PackedVector2Array([d + Vector2(0, -8), d + Vector2(8, 0), d + Vector2(0, 8),
				d + Vector2(-8, 0)])
		draw_colored_polygon(diamond, DRONE)

	var car := stage.world.car
	var c := to_map(car.global_position)
	draw_circle(c, 9.0, Color(0, 0, 0, 0.6))
	draw_circle(c, 7.0, CAR)
	HUDDraw.text(self, font, c + Vector2(12, 6), str(car.car_number), HudStyle.SIZE_S, HORIZONTAL_ALIGNMENT_LEFT, -1, CAR)

	var p := to_map(stage.player.global_position)
	var forward := -stage.player.global_basis.z
	var heading := Vector2(forward.x, forward.z).normalized()
	if heading.length_squared() < 0.5:
		heading = Vector2.UP
	var side := Vector2(-heading.y, heading.x)
	var arrow := PackedVector2Array([p + heading * 13.0, p - heading * 8.0 + side * 8.0,
			p - heading * 4.0, p - heading * 8.0 - side * 8.0])
	draw_colored_polygon(arrow, Color(0, 0, 0, 0.6))
	var inner := PackedVector2Array()
	for point in arrow:
		inner.append(p + (point - p) * 0.75)
	draw_colored_polygon(inner, PLAYER)

	# Legend.
	var y := size.y - 16.0
	HUDDraw.text(self, font, Vector2(16, y), "▲ vos   ◆ dron   ● auto   ○ tu punto del camino", HudStyle.SIZE_XS,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Color(1, 1, 1, 0.8))


func _draw_flag(at: Vector2, color: Color, label: String, font: Font) -> void:
	draw_circle(at, 8.0, Color(0, 0, 0, 0.6))
	draw_circle(at, 6.0, color)
	HUDDraw.text(self, font, at + Vector2(12, -8), label, HudStyle.SIZE_XS, HORIZONTAL_ALIGNMENT_LEFT, -1, color)
