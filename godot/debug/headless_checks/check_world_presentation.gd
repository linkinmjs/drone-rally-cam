## The stylized world (plan 05): the same seed gives the same trees (the positions of before the
## new tree meshes) and the same props, no solid prop stands on the road, the arches let the car
## through at the start and the finish, StageFeedback answers every EventBus signal, the car
## throws dust only when it runs and turns its wheels, the case opens when deployed, and the
## shared environment keeps a low sun and no whitening fog.
extends HeadlessCheck


const STAGE_01 := preload("res://world/stages/stage_01.tscn")
const STAGE_SCENE := preload("res://game/stage.tscn")
const ENVIRONMENT := preload("res://world/environment/rally_env.tres")
const SUN := preload("res://world/environment/rally_sun.tscn")
## Tree positions of stage 1 before plan 05 (count and sum of the coordinates).
const TREES_BEFORE := {"count": 500, "sum": Vector3(4225.481, 332.606, -7339.413)}


func run() -> void:
	await _check_world()
	_check_environment()
	await _check_stage()


func _check_world() -> void:
	var first := STAGE_01.instantiate() as StageWorld
	add_child(first)
	var second := STAGE_01.instantiate() as StageWorld
	add_child(second)
	await process_frames(2)
	var builder := first.builder

	var sum := Vector3.ZERO
	for point in builder.tree_positions:
		sum += point
	note("%d trees (%d pine, %d leafy, %d bushes), %d grass tufts" % [builder.tree_positions.size(),
			builder.tree_kinds.count(TreeMesh.Kind.PINE), builder.tree_kinds.count(TreeMesh.Kind.LEAFY),
			builder.tree_kinds.count(TreeMesh.Kind.BUSH), builder.grass_count])
	expect(builder.tree_positions.size() == TREES_BEFORE["count"] and sum.distance_to(TREES_BEFORE["sum"]) < 0.05,
			"the trees stand where they stood before the new meshes (sum %s)" % sum)
	expect(builder.tree_positions == second.builder.tree_positions and builder.tree_kinds == second.builder.tree_kinds,
			"the same seed gives the same trees")
	for kind: int in TreeMesh.Kind.values():
		expect(builder.tree_kinds.has(kind), "the forest has trees of kind %d" % kind)
	expect(builder.grass_count > 500, "there is grass by the road (%d tufts)" % builder.grass_count)

	var props := builder.props
	expect(props != null, "the stage has its props")
	if props == null:
		return
	var same := props.transforms.keys() == second.builder.props.transforms.keys()
	for kind: String in props.transforms:
		same = same and props.transforms[kind] == second.builder.props.transforms.get(kind)
	expect(same, "the same seed places the same props")
	var counts := PackedStringArray()
	for kind: String in props.transforms:
		counts.append("%s %d" % [kind, (props.transforms[kind] as Array).size()])
	note("props: %s" % ", ".join(counts))
	for kind: String in ["ArchStart", "ArchFinish", "KmBoards", "Stakes", "Tape", "Bales", "Bodies", "Heads",
			"Flags", "Van", "Awning", "FencePosts"]:
		expect(props.transforms.has(kind), "the stage has %s" % kind)

	# Nothing solid on the road.
	var limit := builder.road_width * 0.5 + 1.0
	for kind: String in props.solid:
		var closest := INF
		for point: Vector3 in props.solid[kind]:
			closest = minf(closest, _road_distance(builder, point))
		expect(closest >= limit, "%s stay off the road (closest %.1f m, limit %.1f m)" % [kind, closest, limit])
	# The arches straddle the road at its ends, high enough for the car.
	var start: Transform3D = props.transforms["ArchStart"][0]
	var finish: Transform3D = props.transforms["ArchFinish"][0]
	expect(start.origin.distance_to(builder.road_samples[0]) < 10.0, "the start arch is at the start")
	expect(finish.origin.distance_to(builder.road_samples[-1]) < 10.0, "the finish banner is at the finish")
	expect(PropMeshes.ARCH_CLEARANCE > 5.0, "the arches leave more than 5 m of clearance")
	var post_offset := (builder.road_width + PropCatalog.ARCH_OFFSET * 2.0) * 0.5
	expect(post_offset > builder.road_width * 0.5 + 1.0, "the arch posts stand beside the road")
	first.queue_free()
	second.queue_free()
	await process_frames(2)


## Shortest distance on the ground from `point` to the road's centre line.
func _road_distance(builder: StageBuilder, point: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	var best := INF
	var samples := builder.road_samples
	for i in samples.size() - 1:
		var a := Vector2(samples[i].x, samples[i].z)
		var b := Vector2(samples[i + 1].x, samples[i + 1].z)
		best = minf(best, flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, a, b)))
	return best


func _check_environment() -> void:
	var sun := SUN.instantiate() as DirectionalLight3D
	note("sun %.1f, fog %.4f, volumetric %s" % [sun.light_energy, ENVIRONMENT.fog_density,
			ENVIRONMENT.volumetric_fog_enabled])
	expect(sun.light_energy >= 1.2 and sun.light_energy <= 2.0, "the sun is bright but not burnt")
	expect(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
			"the sun casts four-split shadows")
	var direction := -sun.transform.basis.z
	var elevation := rad_to_deg(asin(-direction.y))
	expect(absf(elevation - 32.0) < 3.0, "the sun is low, about 32° (%.1f°)" % elevation)
	expect(not ENVIRONMENT.volumetric_fog_enabled, "no volumetric fog whitening the distance")
	expect(ENVIRONMENT.fog_density < 0.002, "the depth fog is light")
	sun.free()


func _check_stage() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	add_child(stage)
	await physics_frames(20)
	expect(stage.feedback.is_connected_to_all(), "StageFeedback answers every signal of its table")

	# The car: no dust standing still, dust and turning wheels when it runs.
	var car := stage.world.car
	expect(not car.dust[0].emitting and not car.dust[1].emitting, "no dust from a car standing still")
	var wheel := car.get_node("WheelFrontLeft") as Node3D
	var before := wheel.transform.basis
	car.start()
	car.distance = 200.0
	await physics_frames(30)
	note("car at %.1f m/s" % car.speed)
	expect(car.speed > 5.0 and car.dust[0].emitting and car.dust[1].emitting, "a running car throws dust")
	expect(not wheel.transform.basis.is_equal_approx(before), "the front wheel turns")

	# The case opens when the drone is deployed.
	var spot := Transform3D(stage.player.global_basis, stage.player.global_position - stage.player.global_basis.z * 2.0)
	expect(stage.control.deploy(spot), "the drone deploys")
	var drone_case := stage.control.drone_case
	var hinge := drone_case.get_node("LidHinge") as Node3D if drone_case else null
	var closed := hinge.rotation.x if hinge else 0.0
	await process_frames(80)
	expect(hinge != null and hinge.rotation.x < closed - 1.0, "the lid of the case opens (%.2f → %.2f)"
			% [closed, hinge.rotation.x if hinge else 0.0])

	# A crash throws sparks and dust.
	var played := stage.feedback.effects_played
	EventBus.drone_crashed.emit(stage.drone, 8.0)
	await process_frames(2)
	expect(stage.feedback.effects_played - played == 2, "a crash throws sparks and dust (%d effects)"
			% (stage.feedback.effects_played - played))

	# Footsteps know the ground.
	var road_point := stage.world.builder.to_global(stage.world.builder.road_samples[100])
	expect(stage._surface_at(road_point) == &"gravel", "steps on the road are on gravel")
	expect(stage._surface_at(road_point + Vector3(30, 0, 30)) == &"grass"
			or stage.world.builder.get_road_distance(road_point.x + 30.0, road_point.z + 30.0) < 5.0,
			"steps off the road are on grass")
	stage.queue_free()
	await process_frames(2)
