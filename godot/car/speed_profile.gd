## Precomputed speed along a road: the fastest a car can take each point given the grip, then
## limited by how hard it can brake before each corner and accelerate out of it. Being
## deterministic, it also tells when a car will reach any point of the stage.
class_name SpeedProfile
extends RefCounted


const GRAVITY := 9.81

## Distance between samples, in meters.
var step := 1.0
var length := 0.0
var speeds: PackedFloat32Array = []
## Seconds from the start to each sample.
var times: PackedFloat32Array = []
## Signed horizontal curvature in 1/m: positive turns left.
var curvature: PackedFloat32Array = []


## `grip` is the tyre friction coefficient (gravel ~0.7, tarmac ~1.0). Accelerations in m/s².
static func build(curve: Curve3D, grip: float, top_speed: float, brake: float, accel: float,
		sample_step := 1.0, start_speed := 0.0, end_speed := 0.0) -> SpeedProfile:
	var profile := SpeedProfile.new()
	profile.step = sample_step
	profile.length = curve.get_baked_length()
	var count := int(profile.length / sample_step) + 1
	profile.speeds.resize(count)
	profile.times.resize(count)
	profile.curvature.resize(count)

	var raw_curvature: PackedFloat32Array = []
	raw_curvature.resize(count)
	var span := 5.0
	for i in count:
		var s := i * sample_step
		var p0 := curve.sample_baked(maxf(s - span, 0.0), true)
		var p1 := curve.sample_baked(s, true)
		var p2 := curve.sample_baked(minf(s + span, profile.length), true)
		raw_curvature[i] = signed_curvature(Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), Vector2(p2.x, p2.z))
	# Light smoothing: the car reacts to the corner, not to the noise of the baked points.
	var window := maxi(int(4.0 / sample_step), 1)
	for i in count:
		var total := 0.0
		var samples := 0
		for j in range(maxi(i - window, 0), mini(i + window + 1, count)):
			total += raw_curvature[j]
			samples += 1
		profile.curvature[i] = total / samples

	for i in count:
		var k := absf(profile.curvature[i])
		var corner_speed := sqrt(grip * GRAVITY / k) if k > 0.0001 else top_speed
		profile.speeds[i] = minf(top_speed, corner_speed)

	profile.speeds[count - 1] = minf(profile.speeds[count - 1], end_speed)
	for i in range(count - 2, -1, -1):
		var reachable := sqrt(profile.speeds[i + 1] ** 2 + 2.0 * brake * sample_step)
		profile.speeds[i] = minf(profile.speeds[i], reachable)

	profile.speeds[0] = minf(profile.speeds[0], start_speed)
	for i in range(1, count):
		var reachable := sqrt(profile.speeds[i - 1] ** 2 + 2.0 * accel * sample_step)
		profile.speeds[i] = minf(profile.speeds[i], reachable)

	profile.times[0] = 0.0
	for i in range(1, count):
		var average := maxf((profile.speeds[i] + profile.speeds[i - 1]) * 0.5, 0.5)
		profile.times[i] = profile.times[i - 1] + sample_step / average
	return profile


## Menger curvature of three points on the ground plane (X, Z), positive for a left turn.
static func signed_curvature(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab := b - a
	var bc := c - b
	var ac := c - a
	var denominator := ab.length() * bc.length() * ac.length()
	if denominator < 0.000001:
		return 0.0
	# In (x, z) a left turn gives a negative cross product (Z points backwards).
	return -2.0 * ab.cross(bc) / denominator


func speed_at(distance: float) -> float:
	return _sample(speeds, distance)


func time_at(distance: float) -> float:
	return _sample(times, distance)


func curvature_at(distance: float) -> float:
	return _sample(curvature, distance)


func total_time() -> float:
	return times[-1] if not times.is_empty() else 0.0


func _sample(values: PackedFloat32Array, distance: float) -> float:
	if values.is_empty():
		return 0.0
	var f := clampf(distance / step, 0.0, values.size() - 1.0)
	var i := int(f)
	if i >= values.size() - 1:
		return values[-1]
	return lerpf(values[i], values[i + 1], f - i)
