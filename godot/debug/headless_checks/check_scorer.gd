## Shot scoring with a fixed camera and a car-sized box: framing, size, occlusion and
## stability, and the grades a ShotReport gives to synthetic clips.
extends HeadlessCheck


const CAR_SIZE := Vector3(4.2, 1.4, 1.8)


func run() -> void:
	var camera := Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	camera.make_current()
	await process_frames(2)

	# A car seen from the side, 12 m ahead and centred.
	var centred := AABB(Vector3(0, 0, -12) - CAR_SIZE * 0.5, CAR_SIZE)
	var rect := ShotScorer.project_aabb(camera, centred)
	var framing := ShotScorer.framing_score(rect)
	var fraction := ShotScorer.screen_fraction(rect)
	var size := ShotScorer.size_score(fraction, ShotScorer.is_cropped(rect))
	note("centred at 12 m: framing %.2f, %.2f %% of the screen, size score %.2f" % [framing, fraction * 100.0, size])
	expect(framing > 0.9, "a centred car should frame well")
	expect(size > 0.9, "a car 12 m away should have a good size")

	# The same car near the top-left corner.
	var corner := AABB(Vector3(-9.5, 5.3, -12) - CAR_SIZE * 0.5, CAR_SIZE)
	var corner_framing := ShotScorer.framing_score(ShotScorer.project_aabb(camera, corner))
	note("near the corner: framing %.2f" % corner_framing)
	expect(corner_framing < 0.4, "a car in the corner should frame badly")

	# Far away it becomes a speck.
	var far := AABB(Vector3(0, 0, -150) - CAR_SIZE * 0.5, CAR_SIZE)
	var far_size := ShotScorer.size_score(ShotScorer.screen_fraction(ShotScorer.project_aabb(camera, far)), false)
	note("at 150 m: size score %.2f" % far_size)
	expect(far_size < 0.2, "a car 150 m away is too small")

	# Behind the camera nothing is scored.
	var behind := AABB(Vector3(0, 0, 12) - CAR_SIZE * 0.5, CAR_SIZE)
	expect(not ShotScorer.project_aabb(camera, behind).has_area(), "a car behind the camera must not project")

	# Occlusion: a wall between the camera and the car.
	var car := _box_body(Vector3(0, 0, -12), CAR_SIZE, 4)
	var exclude: Array[RID] = []
	await physics_frames(2)
	var clear := ShotScorer.visibility(camera, car, centred, exclude, 1 | 4)
	var wall := _box_body(Vector3(0, 0, -6), Vector3(20, 10, 0.5), 1)
	await physics_frames(2)
	var hidden := ShotScorer.visibility(camera, car, centred, exclude, 1 | 4)
	note("visibility: %.2f in the open, %.2f behind a wall" % [clear, hidden])
	expect(clear > 0.99, "nothing hides the car in the open")
	expect(hidden < 0.01, "the wall should hide the car")
	wall.queue_free()

	expect(ShotScorer.stability_score(0.0) == 1.0, "a still camera is fully stable")
	expect(ShotScorer.stability_score(3.0) < 0.2, "a camera turning at 3 rad/s is not stable")

	expect(_grade_for(0.95, 4.0) == "S", "a long excellent clip should be S")
	expect(_grade_for(0.75, 4.0) == "A", "a good clip should be A")
	expect(_grade_for(0.55, 4.0) == "B", "an average clip should be B")
	expect(_grade_for(0.3, 4.0) == "C", "a poor clip should be C")
	expect(_grade_for(0.95, 1.0) == "C", "a clip under 1.5 s should be C")
	var crashed := _report(0.95, 4.0)
	crashed.aborted = true
	crashed.finalize()
	expect(crashed.grade == "C", "a crashed clip should be C")


func _grade_for(score: float, seconds: float) -> String:
	return _report(score, seconds).grade


func _report(score: float, seconds: float) -> ShotReport:
	var report := ShotReport.new()
	report.sample_interval = 0.05
	report.duration = seconds
	for _i in int(seconds / report.sample_interval):
		report.add_sample(score, score, score, 1.0, score)
	report.finalize()
	return report


func _box_body(centre: Vector3, box_size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = centre
	return body
