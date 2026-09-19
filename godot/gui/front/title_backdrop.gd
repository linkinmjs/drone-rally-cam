## Live 3D behind the title and the main menu: a drone hovering over 40 m of gravel road
## among pines, seen by a camera in a slow orbit, with the materials and sky of the stages.
## Built in code; nothing here simulates (the drone is only a model).
class_name TitleBackdrop
extends Node3D


const DRONE := preload("res://drone/drones/drone1.tscn")
const TERRAIN := preload("res://world/materials/terrain.tres")
const ROAD := preload("res://world/materials/road.tres")
const TRUNK := preload("res://world/materials/trunk.tres")
const FOLIAGE := preload("res://world/materials/foliage.tres")
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
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.43, 0.7)
	sky_material.sky_horizon_color = Color(0.72, 0.7, 0.66)
	sky_material.ground_bottom_color = Color(0.18, 0.2, 0.16)
	sky_material.ground_horizon_color = Color(0.72, 0.7, 0.66)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.72, 0.72)
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.3
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	# A low, warm sun.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(-140.0), 0.0)
	add_child(sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	ground.mesh = plane
	ground.material_override = TERRAIN
	add_child(ground)
	var road := MeshInstance3D.new()
	var strip := PlaneMesh.new()
	strip.size = Vector2(7.0, 60.0)
	road.mesh = strip
	road.material_override = ROAD
	road.position = Vector3(0.0, 0.03, -12.0)
	road.rotation.y = deg_to_rad(18.0)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var transforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	while transforms.size() < 90:
		var spot := Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-90.0, 30.0))
		# Keep the road and the drone clear.
		var along_road := Vector2(spot.x, spot.z + 12.0).rotated(deg_to_rad(18.0))
		if absf(along_road.x) < 8.0 or spot.length() < 12.0:
			continue
		var scale := rng.randf_range(0.8, 1.4)
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), spot))
		colors.append(Color.from_hsv(rng.randf_range(0.26, 0.36), rng.randf_range(0.45, 0.7), rng.randf_range(0.28, 0.45)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.24
	trunk.height = 3.0
	trunk.radial_segments = 6
	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.0
	canopy.bottom_radius = 1.9
	canopy.height = 6.5
	canopy.radial_segments = 8
	add_child(_multimesh(trunk, TRUNK, transforms, Vector3(0.0, 1.5, 0.0), PackedColorArray()))
	add_child(_multimesh(canopy, FOLIAGE, transforms, Vector3(0.0, 5.0, 0.0), colors))


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
