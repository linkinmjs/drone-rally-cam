## Live 3D behind the title and the main menu: a drone hovering over a stretch of gravel road
## among the trees of the stages, seen by a camera in a slow orbit, with the environment, sun
## and materials of the stages. Built in code; nothing here simulates (the drone is a model).
class_name TitleBackdrop
extends Node3D


const DRONE := preload("res://drone/drones/drone1.tscn")
const TERRAIN := preload("res://world/materials/terrain.tres")
const ROAD := preload("res://world/materials/road.tres")
const TRUNK := preload("res://world/materials/trunk.tres")
const FOLIAGE := preload("res://world/materials/foliage.tres")
const ENVIRONMENT := preload("res://world/environment/rally_env.tres")
const SUN := preload("res://world/environment/rally_sun.tscn")
const ROAD_WIDTH := 7.0
const ORBIT_RADIUS := 1.35
const ORBIT_HEIGHT := 0.4
const ORBIT_SPEED := 0.08
const HOVER_HEIGHT := 2.4

var camera: Camera3D
var drone: Node3D

var _time := 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_trees()
	drone = DRONE.instantiate() as Node3D
	# Only a model: no physics, no flight controller, no motor sounds.
	drone.process_mode = Node.PROCESS_MODE_DISABLED
	if drone is RigidBody3D:
		(drone as RigidBody3D).freeze = true
	drone.position = Vector3(0.0, HOVER_HEIGHT, 0.0)
	add_child(drone)
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.near = 0.05
	# Shallow focus, like a long lens: the drone sharp, the forest soft behind it.
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 4.0
	attributes.dof_blur_far_transition = 10.0
	attributes.dof_blur_amount = 0.08
	camera.attributes = attributes
	add_child(camera)
	camera.make_current()
	_place(0.0)


func _process(delta: float) -> void:
	_time += delta
	_place(_time)


func _place(time: float) -> void:
	var angle := 0.6 + time * ORBIT_SPEED
	drone.position.y = HOVER_HEIGHT + sin(time * 1.3) * 0.06
	drone.rotation = Vector3(sin(time * 0.9) * 0.03, 0.4 + sin(time * 0.25) * 0.15, sin(time * 1.1) * 0.03)
	camera.position = drone.position + Vector3(cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(angle) * ORBIT_RADIUS)
	# Frame the drone off-centre, with the road running away behind it.
	camera.look_at(drone.position + Vector3(0.0, 0.05, 0.0), Vector3.UP)
	# The drone on the right third, clear of the logo.
	camera.rotate_object_local(Vector3.UP, 0.22)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = ENVIRONMENT
	add_child(world_environment)
	# The sun of the stages, a little lower: long shadows across the road.
	var sun := SUN.instantiate() as DirectionalLight3D
	sun.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(-140.0), 0.0)
	add_child(sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	ground.mesh = plane
	ground.material_override = TERRAIN
	add_child(ground)
	# A straight stretch of the stages' road: same cross-section and UVs (meters across).
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := [[-ROAD_WIDTH * 0.5 - 1.2, 0.0], [-ROAD_WIDTH * 0.5, 0.04], [0.0, 0.1],
			[ROAD_WIDTH * 0.5, 0.04], [ROAD_WIDTH * 0.5 + 1.2, 0.0]]
	for row in 31:
		var z := 30.0 - row * 2.0
		for column: Array in across:
			surface.set_uv(Vector2(column[0], row * 0.5))
			surface.add_vertex(Vector3(column[0], column[1] + 0.02, z))
	for row in 30:
		for c in across.size() - 1:
			var a := row * across.size() + c
			var b := a + across.size()
			for index in [a, b, a + 1, a + 1, b, b + 1]:
				surface.add_index(index)
	surface.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh = surface.commit()
	road.material_override = ROAD
	road.position = Vector3(0.0, 0.0, -12.0)
	road.rotation.y = deg_to_rad(18.0)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var kinds: Array[int] = []
	var transforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	var placed := 0
	while placed < 110:
		var spot := Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-90.0, 30.0))
		# Keep the road and the drone clear.
		var along_road := Vector2(spot.x, spot.z + 12.0).rotated(deg_to_rad(18.0))
		if absf(along_road.x) < 8.0 or spot.length() < 12.0:
			continue
		var scale := rng.randf_range(0.8, 1.4)
		var roll := rng.randf()
		var kind := TreeMesh.Kind.PINE if roll < 0.6 else (TreeMesh.Kind.LEAFY if roll < 0.85 else TreeMesh.Kind.BUSH)
		kinds.append(kind)
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), spot))
		colors.append(Color.from_hsv(rng.randf_range(0.24, 0.34), rng.randf_range(0.45, 0.7),
				rng.randf_range(0.3, 0.48)))
		placed += 1
	for kind: int in TreeMesh.Kind.values():
		var of_kind: Array[Transform3D] = []
		var tints := PackedColorArray()
		for i in kinds.size():
			if kinds[i] == kind:
				of_kind.append(transforms[i])
				tints.append(colors[i])
		if TreeMesh.TRUNK_HEIGHT.has(kind):
			add_child(_multimesh(TreeMesh.trunk(kind), TRUNK, of_kind, Vector3.ZERO, PackedColorArray()))
		add_child(_multimesh(TreeMesh.canopy(kind), FOLIAGE, of_kind, Vector3.ZERO, tints))


func _multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D], offset: Vector3,
		colors: PackedColorArray) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i] * Transform3D(Basis.IDENTITY, offset))
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	return instance
