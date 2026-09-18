## Builds a rally stage from a seed and a hand-placed road: heightmap terrain, the road
## flattened into it, the driving line for the cars, trees and rocks. Same seed and points,
## same stage. Everything it creates lives under a "Generated" child that is never saved.
@tool
class_name StageBuilder
extends Node3D


signal built

const GENERATED_NAME := "Generated"
const TERRAIN_LAYER := 1
const BOUNDS_LAYER := 32

@export_tool_button("Regenerar") var regenerate_button := build
## Build the stage when the scene is opened in the editor (takes a second or two).
@export var preview_in_editor := true

@export_group("Terrain")
@export var terrain_seed := 7
## Side of the square terrain, in meters.
@export var size := 768.0
## Distance between heightmap samples, in meters.
@export var resolution := 1.5
@export var hill_height := 22.0
@export var hill_frequency := 0.0025
@export var detail_height := 1.2
@export var detail_frequency := 0.03
## Width of the border where the terrain eases down to height 0.
@export var edge_falloff := 70.0

@export_group("Road")
## Control points of the road on the ground plane (X, Z). The road passes through all of them.
@export var road_points: PackedVector2Array = []
@export var road_width := 7.0
## Flat strip on each side of the road before the terrain blends back.
@export var shoulder := 1.5
## Distance over which the terrain goes from the road height back to its natural height.
@export var blend := 10.0
## Length of the window used to smooth the road profile, in meters.
@export var road_smoothing := 60.0
## Spacing of the driving line control points, in meters.
@export var driving_point_spacing := 6.0

@export_group("Scenery")
@export var tree_count := 500
## Minimum distance from the road edge to a tree trunk.
@export var tree_clearance := 6.0
@export var rock_count := 70
@export var scenery_seed := 11
## Nodes (like the player spawn) that must not end up inside a tree or a rock.
@export var clearings: Array[NodePath] = []
@export var clearing_radius := 12.0

@export_group("Materials")
@export var terrain_material: Material
@export var road_material: Material
@export var trunk_material: Material
@export var foliage_material: Material
@export var rock_material: Material

## Curve the cars follow, in this node's space, with the real road heights.
var driving_curve: Curve3D = null
## Road centre line sampled every `ROAD_STEP` meters.
var road_samples: PackedVector3Array = []
## Tree positions and canopy radii, for other systems that want to avoid them.
var tree_positions: PackedVector3Array = []

var _cells := 0
var _heights: PackedFloat32Array = []
var _road_distance: PackedFloat32Array = []
var _is_built := false

const ROAD_STEP := 2.0


func _ready() -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	build()


func is_built() -> bool:
	return _is_built


func build() -> void:
	var start := Time.get_ticks_msec()
	_clear_generated()
	_cells = int(round(size / resolution))
	_generate_heights()
	_build_road_line()
	_flatten_road()
	var generated := Node3D.new()
	generated.name = GENERATED_NAME
	add_child(generated)
	_build_terrain(generated)
	_build_road_mesh(generated)
	_build_bounds(generated)
	_build_scenery(generated)
	_is_built = true
	print("StageBuilder: stage built in %d ms (%d x %d samples, road %.0f m)" % [
			Time.get_ticks_msec() - start, _cells + 1, _cells + 1, get_road_length()])
	built.emit()


## Terrain height at a point of this node's XZ plane (bilinear).
func get_height(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var fx := clampf((x + size * 0.5) / resolution, 0.0, _cells - 0.001)
	var fz := clampf((z + size * 0.5) / resolution, 0.0, _cells - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var row := _cells + 1
	var h00 := _heights[iz * row + ix]
	var h10 := _heights[iz * row + ix + 1]
	var h01 := _heights[(iz + 1) * row + ix]
	var h11 := _heights[(iz + 1) * row + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Distance from a point to the road centre line, from the nearest heightmap sample.
func get_road_distance(x: float, z: float) -> float:
	if _road_distance.is_empty():
		return INF
	var ix := clampi(int(round((x + size * 0.5) / resolution)), 0, _cells)
	var iz := clampi(int(round((z + size * 0.5) / resolution)), 0, _cells)
	return _road_distance[iz * (_cells + 1) + ix]


func get_road_length() -> float:
	return driving_curve.get_baked_length() if driving_curve else 0.0


func _clear_generated() -> void:
	var old := get_node_or_null(GENERATED_NAME)
	if old:
		remove_child(old)
		old.free()
	_is_built = false


func _generate_heights() -> void:
	var hills := FastNoiseLite.new()
	hills.seed = terrain_seed
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = hill_frequency
	hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	hills.fractal_octaves = 4
	var detail := FastNoiseLite.new()
	detail.seed = terrain_seed + 1
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = detail_frequency
	detail.fractal_octaves = 2

	var row := _cells + 1
	_heights.resize(row * row)
	var half := size * 0.5
	for iz in row:
		var z := iz * resolution - half
		for ix in row:
			var x := ix * resolution - half
			var h := hills.get_noise_2d(x, z) * hill_height + detail.get_noise_2d(x, z) * detail_height
			var border := minf(minf(x + half, half - x), minf(z + half, half - z))
			if border < edge_falloff:
				h *= smoothstep(0.0, edge_falloff, border)
			_heights[iz * row + ix] = h


## Samples a centripetal Catmull-Rom spline through the control points every ROAD_STEP
## meters, with heights that follow the terrain smoothly.
func _build_road_line() -> void:
	road_samples.clear()
	driving_curve = Curve3D.new()
	if road_points.size() < 2:
		return

	var dense: PackedVector2Array = []
	var count := road_points.size()
	for i in count - 1:
		var p0 := road_points[maxi(i - 1, 0)]
		var p1 := road_points[i]
		var p2 := road_points[i + 1]
		var p3 := road_points[mini(i + 2, count - 1)]
		if i == 0:
			p0 = p1 - (p2 - p1)
		if i + 2 >= count:
			p3 = p2 + (p2 - p1)
		for step in 24:
			dense.append(_catmull_rom(p0, p1, p2, p3, step / 24.0))
	dense.append(road_points[count - 1])

	# Resample at a constant spacing along the line.
	var flat: PackedVector2Array = [dense[0]]
	var carried := 0.0
	for i in range(1, dense.size()):
		var a := dense[i - 1]
		var b := dense[i]
		var segment := a.distance_to(b)
		var along := ROAD_STEP - carried
		while along <= segment:
			flat.append(a.lerp(b, along / segment))
			along += ROAD_STEP
		carried = segment - (along - ROAD_STEP)

	var raw: PackedFloat32Array = []
	for point in flat:
		raw.append(get_height(point.x, point.y))
	var half_window := maxi(int(road_smoothing / ROAD_STEP / 2.0), 1)
	var smooth := _moving_average(_moving_average(raw, half_window), half_window)

	for i in flat.size():
		road_samples.append(Vector3(flat[i].x, smooth[i], flat[i].y))

	# Driving line: fewer points with Catmull-Rom tangents, so the curve stays smooth.
	var stride := maxi(int(driving_point_spacing / ROAD_STEP), 1)
	var indices: PackedInt32Array = []
	for i in range(0, road_samples.size(), stride):
		indices.append(i)
	if indices[-1] != road_samples.size() - 1:
		indices.append(road_samples.size() - 1)
	for k in indices.size():
		var point := road_samples[indices[k]]
		var previous := road_samples[indices[maxi(k - 1, 0)]]
		var next := road_samples[indices[mini(k + 1, indices.size() - 1)]]
		var tangent := (next - previous) / 6.0
		if k == 0 or k == indices.size() - 1:
			tangent /= 2.0
		driving_curve.add_point(point, -tangent, tangent)


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# Centripetal parametrization (alpha 0.5) avoids loops and cusps.
	var t0 := 0.0
	var t1 := t0 + sqrt(maxf(p0.distance_to(p1), 0.001))
	var t2 := t1 + sqrt(maxf(p1.distance_to(p2), 0.001))
	var t3 := t2 + sqrt(maxf(p2.distance_to(p3), 0.001))
	var u := lerpf(t1, t2, t)
	var a1 := p0 * (t1 - u) / (t1 - t0) + p1 * (u - t0) / (t1 - t0)
	var a2 := p1 * (t2 - u) / (t2 - t1) + p2 * (u - t1) / (t2 - t1)
	var a3 := p2 * (t3 - u) / (t3 - t2) + p3 * (u - t2) / (t3 - t2)
	var b1 := a1 * (t2 - u) / (t2 - t0) + a2 * (u - t0) / (t2 - t0)
	var b2 := a2 * (t3 - u) / (t3 - t1) + a3 * (u - t1) / (t3 - t1)
	return b1 * (t2 - u) / (t2 - t1) + b2 * (u - t1) / (t2 - t1)


func _moving_average(values: PackedFloat32Array, half_window: int) -> PackedFloat32Array:
	var result: PackedFloat32Array = []
	result.resize(values.size())
	var count := values.size()
	for i in count:
		var total := 0.0
		var samples := 0
		for j in range(maxi(i - half_window, 0), mini(i + half_window + 1, count)):
			total += values[j]
			samples += 1
		result[i] = total / samples
	return result


## Stamps the road into the heightmap: flat under the road and shoulders, blending back to
## the natural terrain further away. Also records each sample's distance to the road.
func _flatten_road() -> void:
	var row := _cells + 1
	_road_distance.resize(row * row)
	_road_distance.fill(INF)
	var road_height: PackedFloat32Array = []
	road_height.resize(row * row)
	if road_samples.size() < 2:
		return

	var half := size * 0.5
	var reach := road_width * 0.5 + shoulder + blend
	var reach_cells := int(ceil(reach / resolution))
	for i in road_samples.size() - 1:
		var a := road_samples[i]
		var b := road_samples[i + 1]
		var a2 := Vector2(a.x, a.z)
		var ab := Vector2(b.x, b.z) - a2
		var ab_length_sq := ab.length_squared()
		var cx := int(round((a.x + half) / resolution))
		var cz := int(round((a.z + half) / resolution))
		for iz in range(maxi(cz - reach_cells, 0), mini(cz + reach_cells + 2, row)):
			var z := iz * resolution - half
			for ix in range(maxi(cx - reach_cells, 0), mini(cx + reach_cells + 2, row)):
				var x := ix * resolution - half
				var t := clampf((Vector2(x, z) - a2).dot(ab) / ab_length_sq, 0.0, 1.0)
				var closest := a2 + ab * t
				var distance := Vector2(x, z).distance_to(closest)
				var index := iz * row + ix
				if distance < _road_distance[index]:
					_road_distance[index] = distance
					road_height[index] = lerpf(a.y, b.y, t)

	var flat_edge := road_width * 0.5 + shoulder
	for index in _heights.size():
		var distance := _road_distance[index]
		if distance < reach:
			var weight := smoothstep(flat_edge, reach, distance)
			_heights[index] = lerpf(road_height[index] - 0.04, _heights[index], weight)


func _build_terrain(parent: Node3D) -> void:
	var row := _cells + 1
	var half := size * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	vertices.resize(row * row)
	normals.resize(row * row)
	colors.resize(row * row)
	uvs.resize(row * row)
	for iz in row:
		for ix in row:
			var index := iz * row + ix
			var h := _heights[index]
			var x := ix * resolution - half
			var z := iz * resolution - half
			vertices[index] = Vector3(x, h, z)
			var left := _heights[iz * row + maxi(ix - 1, 0)]
			var right := _heights[iz * row + mini(ix + 1, _cells)]
			var up := _heights[maxi(iz - 1, 0) * row + ix]
			var down := _heights[mini(iz + 1, _cells) * row + ix]
			normals[index] = Vector3(left - right, 2.0 * resolution, up - down).normalized()
			# Red channel: 1 = natural ground, 0 = loose dirt near the road. Meshes without
			# vertex colors read white, so they render as natural ground.
			var dirt := 1.0 - smoothstep(road_width * 0.5, road_width * 0.5 + 5.0, _road_distance[index])
			colors[index] = Color(1.0 - dirt, 1.0, 1.0)
			uvs[index] = Vector2(x, z) / 8.0

	var indices := PackedInt32Array()
	indices.resize(_cells * _cells * 6)
	var k := 0
	for iz in _cells:
		for ix in _cells:
			var a := iz * row + ix
			var b := a + 1
			var c := a + row
			var d := c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if terrain_material:
		mesh.surface_set_material(0, terrain_material)

	var terrain := MeshInstance3D.new()
	terrain.name = "TerrainMesh"
	terrain.mesh = mesh
	parent.add_child(terrain)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = TERRAIN_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var heightmap := HeightMapShape3D.new()
	heightmap.map_width = row
	heightmap.map_depth = row
	var scaled: PackedFloat32Array = []
	scaled.resize(_heights.size())
	for index in _heights.size():
		scaled[index] = _heights[index] / resolution
	heightmap.map_data = scaled
	shape.shape = heightmap
	# A uniform scale keeps the shape valid for every physics engine.
	shape.scale = Vector3.ONE * resolution
	body.add_child(shape)
	parent.add_child(body)


func _build_road_mesh(parent: Node3D) -> void:
	if road_samples.size() < 2:
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var travelled := 0.0
	var count := road_samples.size()
	for i in count:
		var point := road_samples[i]
		var previous := road_samples[maxi(i - 1, 0)]
		var next := road_samples[mini(i + 1, count - 1)]
		var forward := Vector3(next.x - previous.x, 0.0, next.z - previous.z).normalized()
		var side := Vector3(-forward.z, 0.0, forward.x)
		if i > 0:
			travelled += point.distance_to(previous)
		var centre := point + Vector3.UP * 0.04
		vertices.append(centre - side * road_width * 0.5)
		vertices.append(centre + side * road_width * 0.5)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, travelled / 4.0))
		uvs.append(Vector2(1.0, travelled / 4.0))
		if i > 0:
			var a := (i - 1) * 2
			# Clockwise seen from above.
			indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if road_material:
		mesh.surface_set_material(0, road_material)
	var road := MeshInstance3D.new()
	road.name = "RoadMesh"
	road.mesh = mesh
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(road)


## Flat ground around the terrain so the world does not end at a cliff, and invisible walls
## that keep the player inside.
func _build_bounds(parent: Node3D) -> void:
	var half := size * 0.5
	var far := 3000.0
	# Four strips around the square, just below the terrain border (height 0). A single big
	# plane would show through the valleys that dip below 0. They are solid, so a drone flown
	# past the terrain lands on them instead of falling forever.
	var far_body := StaticBody3D.new()
	far_body.name = "FarGroundBody"
	far_body.collision_layer = TERRAIN_LAYER
	far_body.collision_mask = 0
	parent.add_child(far_body)
	for side in 4:
		var strip := MeshInstance3D.new()
		strip.name = "FarGround%d" % side
		var mesh := PlaneMesh.new()
		var along := far * 2.0 if side < 2 else size
		mesh.size = Vector2(along, far - half) if side < 2 else Vector2(far - half, along)
		strip.mesh = mesh
		if terrain_material:
			strip.material_override = terrain_material
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var offset := (far + half) * 0.5
		match side:
			0: strip.position = Vector3(0.0, -0.05, -offset)
			1: strip.position = Vector3(0.0, -0.05, offset)
			2: strip.position = Vector3(-offset, -0.05, 0.0)
			3: strip.position = Vector3(offset, -0.05, 0.0)
		parent.add_child(strip)
		var solid := CollisionShape3D.new()
		var slab := BoxShape3D.new()
		slab.size = Vector3(mesh.size.x, 1.0, mesh.size.y)
		solid.shape = slab
		solid.position = strip.position - Vector3(0.0, 0.5, 0.0)
		far_body.add_child(solid)

	var walls := StaticBody3D.new()
	walls.name = "Bounds"
	walls.collision_layer = BOUNDS_LAYER
	walls.collision_mask = 0
	for side in 4:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var margin := 20.0
		box.size = Vector3(size, 200.0, 2.0) if side < 2 else Vector3(2.0, 200.0, size)
		shape.shape = box
		var edge := half - margin
		match side:
			0: shape.position = Vector3(0.0, 0.0, -edge)
			1: shape.position = Vector3(0.0, 0.0, edge)
			2: shape.position = Vector3(-edge, 0.0, 0.0)
			3: shape.position = Vector3(edge, 0.0, 0.0)
		walls.add_child(shape)
	parent.add_child(walls)


func _build_scenery(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = scenery_seed
	var forest := FastNoiseLite.new()
	forest.seed = scenery_seed
	forest.frequency = 0.008
	var half := size * 0.5 - edge_falloff * 0.5

	var clear_points: PackedVector2Array = []
	for path in clearings:
		var node := get_node_or_null(path) as Node3D
		if node:
			var local := to_local(node.global_position)
			clear_points.append(Vector2(local.x, local.z))

	tree_positions.clear()
	var tree_transforms: Array[Transform3D] = []
	var tree_colors: PackedColorArray = []
	var attempts := 0
	while tree_transforms.size() < tree_count and attempts < tree_count * 20:
		attempts += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		# Denser in some areas, clearings in others.
		if forest.get_noise_2d(x, z) + rng.randf_range(-0.35, 0.35) < 0.0:
			continue
		if get_road_distance(x, z) < road_width * 0.5 + tree_clearance:
			continue
		if _slope_at(x, z) > 0.55 or _in_clearing(x, z, clear_points):
			continue
		var scale := rng.randf_range(0.75, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(0.9, 1.2), scale))
		var position := Vector3(x, get_height(x, z) - 0.2, z)
		tree_transforms.append(Transform3D(basis, position))
		tree_positions.append(position)
		tree_colors.append(Color.from_hsv(rng.randf_range(0.26, 0.36), rng.randf_range(0.45, 0.7), rng.randf_range(0.28, 0.45)))

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 3.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.0
	canopy_mesh.bottom_radius = 1.9
	canopy_mesh.height = 6.5
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 2
	var trunk_offset := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	var canopy_offset := Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 0.0))
	parent.add_child(_multimesh("Trunks", trunk_mesh, trunk_material, tree_transforms, trunk_offset, PackedColorArray()))
	parent.add_child(_multimesh("Canopies", canopy_mesh, foliage_material, tree_transforms, canopy_offset, tree_colors))

	# Collision follows each tree's visible trunk and cone, with its own scale.
	var tree_body := StaticBody3D.new()
	tree_body.name = "TreeColliders"
	tree_body.collision_layer = TERRAIN_LAYER
	tree_body.collision_mask = 0
	for xform in tree_transforms:
		var scale := xform.basis.get_scale()
		var trunk := CollisionShape3D.new()
		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = trunk_mesh.bottom_radius * scale.x
		trunk_shape.height = trunk_mesh.height * scale.y
		trunk.shape = trunk_shape
		trunk.position = xform * trunk_offset.origin
		tree_body.add_child(trunk)
		var canopy := CollisionShape3D.new()
		canopy.shape = _cone_shape(canopy_mesh.bottom_radius * scale.x, canopy_mesh.height * scale.y)
		canopy.position = xform * canopy_offset.origin
		tree_body.add_child(canopy)
	parent.add_child(tree_body)

	var rock_transforms: Array[Transform3D] = []
	attempts = 0
	while rock_transforms.size() < rock_count and attempts < rock_count * 20:
		attempts += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if get_road_distance(x, z) < road_width * 0.5 + 2.5 or _in_clearing(x, z, clear_points):
			continue
		var scale := Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.4, 1.3), rng.randf_range(0.6, 2.2))
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(scale)
		rock_transforms.append(Transform3D(basis, Vector3(x, get_height(x, z) - 0.15, z)))
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.8
	rock_mesh.height = 1.2
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	parent.add_child(_multimesh("Rocks", rock_mesh, rock_material, rock_transforms, Transform3D.IDENTITY, PackedColorArray()))
	var rock_body := StaticBody3D.new()
	rock_body.name = "RockColliders"
	rock_body.collision_layer = TERRAIN_LAYER
	rock_body.collision_mask = 0
	var rock_points := rock_mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX] as PackedVector3Array
	for xform in rock_transforms:
		var shape := CollisionShape3D.new()
		var hull := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for point in rock_points:
			points.append(xform.basis * point)
		hull.points = points
		shape.shape = hull
		shape.position = xform.origin
		rock_body.add_child(shape)
	parent.add_child(rock_body)


## Convex cone standing on its base, centred on its middle height.
func _cone_shape(radius: float, height: float, sides := 12) -> ConvexPolygonShape3D:
	var points := PackedVector3Array([Vector3(0.0, height * 0.5, 0.0)])
	for i in sides:
		var angle := TAU * i / sides
		points.append(Vector3(cos(angle) * radius, -height * 0.5, sin(angle) * radius))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


func _multimesh(node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D],
		offset: Transform3D, colors: PackedColorArray) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i] * offset)
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	if material:
		instance.material_override = material
	return instance


func _in_clearing(x: float, z: float, points: PackedVector2Array) -> bool:
	for point in points:
		if point.distance_to(Vector2(x, z)) < clearing_radius:
			return true
	return false


func _slope_at(x: float, z: float) -> float:
	var step := resolution
	var dx := get_height(x + step, z) - get_height(x - step, z)
	var dz := get_height(x, z + step) - get_height(x, z - step)
	return Vector2(dx, dz).length() / (2.0 * step)
