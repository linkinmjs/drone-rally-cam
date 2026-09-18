## Frame-by-frame measurements of a shot: where the subject sits in the image, how big it is,
## how steady the camera is and whether something hides it. Pure functions, no state.
class_name ShotScorer
extends RefCounted


## Points of interest of the rule of thirds, in normalized screen coordinates.
const THIRDS: Array[Vector2] = [
	Vector2(1.0 / 3.0, 1.0 / 3.0), Vector2(2.0 / 3.0, 1.0 / 3.0),
	Vector2(1.0 / 3.0, 2.0 / 3.0), Vector2(2.0 / 3.0, 2.0 / 3.0),
]
## Weights of each metric in the per-frame score (before visibility multiplies it).
const WEIGHT_FRAMING := 0.35
const WEIGHT_SIZE := 0.30
const WEIGHT_STABILITY := 0.25
const WEIGHT_CONTINUITY := 0.10
## Seconds of good footage in a row needed for full continuity.
const CONTINUITY_SECONDS := 3.0
## Per-frame score considered "good" for continuity streaks.
const GOOD_SCORE := 0.6


## Projects a world-space box to the screen. Returns a rect in normalized coordinates
## (0..1, may exceed the screen) or an empty rect when the box is behind the camera.
static func project_aabb(camera: Camera3D, box: AABB) -> Rect2:
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	var in_front := 0
	for i in 8:
		var corner := box.get_endpoint(i)
		if camera.is_position_behind(corner):
			continue
		in_front += 1
		var screen := camera.unproject_position(corner) / viewport_size
		min_point = min_point.min(screen)
		max_point = max_point.max(screen)
	if in_front == 0:
		return Rect2()
	return Rect2(min_point, max_point - min_point)


## 1 when the subject's centre sits on the centre or on a rule-of-thirds point, falling to 0
## a third of the screen away from both.
static func framing_score(rect: Rect2) -> float:
	if not rect.has_area():
		return 0.0
	var centre := rect.get_center()
	var distance := centre.distance_to(Vector2(0.5, 0.5))
	for point in THIRDS:
		distance = minf(distance, centre.distance_to(point))
	return 1.0 - clampf(distance / 0.35, 0.0, 1.0)


## Fraction of the screen covered by the visible part of the subject.
static func screen_fraction(rect: Rect2) -> float:
	return rect.intersection(Rect2(0, 0, 1, 1)).get_area()


## True when the subject spills over the edges of the frame.
static func is_cropped(rect: Rect2) -> bool:
	return rect.has_area() and not Rect2(0, 0, 1, 1).encloses(rect)


## Best between 1 % and 25 % of the screen (a car 5 to 15 m away with the standard lens).
## Falls to 0 at 0.1 % (a speck) and at 60 % (filling the frame), on a log scale below.
## A subject cut by the frame edge scores half.
static func size_score(fraction: float, cropped: bool) -> float:
	var score := 0.0
	if fraction <= 0.001 or fraction >= 0.6:
		score = 0.0
	elif fraction < 0.01:
		score = inverse_lerp(log(0.001), log(0.01), log(fraction))
	elif fraction <= 0.25:
		score = 1.0
	else:
		score = inverse_lerp(0.6, 0.25, fraction)
	if cropped:
		score *= 0.5
	return score


## 1 for a still camera, 0 when it turns at 1.2 rad/s or faster.
static func stability_score(angular_speed: float) -> float:
	return 1.0 - clampf(angular_speed / 1.2, 0.0, 1.0)


## Fraction of sample points of the subject reachable by a ray from the camera. `exclude`
## holds RIDs to ignore (the drone itself). Rays hitting the subject count as visible.
static func visibility(camera: Camera3D, subject: CollisionObject3D, box: AABB,
		exclude: Array[RID], collision_mask: int) -> float:
	var space := camera.get_world_3d().direct_space_state
	var points: Array[Vector3] = [box.get_center()]
	for i: int in [2, 3, 6, 7]:
		# Upper corners of the box, pulled 20 % towards the centre.
		points.append(box.get_endpoint(i).lerp(box.get_center(), 0.2))
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = collision_mask
	query.exclude = exclude
	var origin := camera.global_position
	var visible := 0
	for point in points:
		query.from = origin
		query.to = point
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit["collider"] == subject:
			visible += 1
	return visible / float(points.size())


## Combines the metrics of one frame. `continuity` is 0..1 (see CONTINUITY_SECONDS).
static func frame_score(framing: float, size: float, stability: float, continuity: float,
		visible: float) -> float:
	var base := WEIGHT_FRAMING * framing + WEIGHT_SIZE * size + WEIGHT_STABILITY * stability \
			+ WEIGHT_CONTINUITY * continuity
	return base * visible
