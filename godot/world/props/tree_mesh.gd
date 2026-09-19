## Low-poly faceted meshes for the scenery, built in code (no alpha cards): pines of stacked
## cones, leafy trees of clustered spheres, bushes, trunks and grass tufts. Vertex colors carry
## a light gradient (darker below, lighter on top); the MultiMesh instance color tints them.
## Each mesh is built once and shared.
class_name TreeMesh
extends RefCounted


enum Kind {PINE, LEAFY, BUSH}

## Trunk heights by kind: the trunk mesh is placed at half this height.
const TRUNK_HEIGHT := {Kind.PINE: 3.0, Kind.LEAFY: 3.4}
## Canopy collision by kind: [shape, radius, height, centre height].
const CANOPY_SHAPE := {
	Kind.PINE: ["cone", 1.95, 5.0, 4.2],
	Kind.LEAFY: ["sphere", 1.9, 0.0, 4.6],
	Kind.BUSH: ["sphere", 1.0, 0.0, 0.45],
}

static var _cache := {}


static func canopy(kind: Kind) -> ArrayMesh:
	var id := "canopy_%d" % kind
	if not _cache.has(id):
		match kind:
			Kind.PINE:
				_cache[id] = _pine()
			Kind.LEAFY:
				_cache[id] = _leafy()
			_:
				_cache[id] = _bush()
	return _cache[id]


static func trunk(kind: Kind) -> ArrayMesh:
	var id := "trunk_%d" % kind
	if not _cache.has(id):
		var height: float = TRUNK_HEIGHT.get(kind, 3.0)
		var surface := _begin()
		_cylinder(surface, Vector3.ZERO, 0.24 if kind == Kind.PINE else 0.3, 0.14 if kind == Kind.PINE else 0.2,
				height, 6, Color.WHITE, Color.WHITE)
		_cache[id] = _end(surface)
	return _cache[id]


## A tuft of grass: five thin blades, dark at the base and light at the tip.
static func grass_tuft() -> ArrayMesh:
	if not _cache.has("grass"):
		var surface := _begin()
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for blade in 5:
			var angle := TAU * blade / 5.0 + rng.randf_range(-0.3, 0.3)
			var base := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.02, 0.1)
			var lean := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.05, 0.16)
			var side := Vector3(-sin(angle), 0.0, cos(angle)) * 0.045
			var tip := base + lean + Vector3.UP * rng.randf_range(0.3, 0.55)
			_triangle(surface, base - side, base + side, tip, Color(0.62, 0.62, 0.62), Color(0.62, 0.62, 0.62),
					Color(1.0, 1.0, 1.0))
			# Back face, so the blade shows from both sides without disabling culling.
			_triangle(surface, base + side, base - side, tip, Color(0.62, 0.62, 0.62), Color(0.62, 0.62, 0.62),
					Color(1.0, 1.0, 1.0))
		_cache["grass"] = _end(surface)
	return _cache["grass"]


# --- Shapes --------------------------------------------------------------------------------

static func _pine() -> ArrayMesh:
	var surface := _begin()
	var tiers := [[1.95, 2.9, 1.7], [1.55, 2.6, 3.0], [1.1, 2.4, 4.3]]
	for i in tiers.size():
		var tier: Array = tiers[i]
		var dark := Color.WHITE.darkened(0.28 - i * 0.06)
		var light := Color.WHITE.lightened(0.02 + i * 0.04)
		_cone(surface, Vector3(0.0, tier[2], 0.0), tier[0], tier[1], 7, i * 0.45, dark, light)
	return _end(surface)


static func _leafy() -> ArrayMesh:
	var surface := _begin()
	var blobs := [[Vector3(0.0, 4.6, 0.0), 1.7], [Vector3(0.9, 4.0, 0.4), 1.3], [Vector3(-0.8, 4.2, -0.5), 1.35],
			[Vector3(0.2, 5.4, -0.3), 1.2], [Vector3(-0.3, 3.7, 0.9), 1.1]]
	for blob: Array in blobs:
		_sphere(surface, blob[0], blob[1], 0.85, 6, 4, 3.0, 6.6)
	return _end(surface)


static func _bush() -> ArrayMesh:
	var surface := _begin()
	_sphere(surface, Vector3(0.0, 0.45, 0.0), 1.0, 0.65, 6, 4, 0.0, 1.2)
	_sphere(surface, Vector3(0.6, 0.35, 0.35), 0.7, 0.7, 6, 3, 0.0, 1.2)
	return _end(surface)


# --- Builders ------------------------------------------------------------------------------

static func _begin() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flat normals: the faceted low-poly look.
	surface.set_smooth_group(-1)
	return surface


static func _end(surface: SurfaceTool) -> ArrayMesh:
	surface.generate_normals()
	return surface.commit()


## Clockwise seen from the front, like every Godot mesh.
static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color_a: Color,
		color_b: Color, color_c: Color) -> void:
	surface.set_color(color_a)
	surface.add_vertex(a)
	surface.set_color(color_b)
	surface.add_vertex(b)
	surface.set_color(color_c)
	surface.add_vertex(c)


## A cone standing on its base centre `base`, with a closed bottom.
static func _cone(surface: SurfaceTool, base: Vector3, radius: float, height: float, sides: int,
		twist: float, bottom_color: Color, top_color: Color) -> void:
	var tip := base + Vector3.UP * height
	for i in sides:
		var a0 := twist + TAU * i / sides
		var a1 := twist + TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a0), 0.0, sin(a0)) * radius
		var p1 := base + Vector3(cos(a1), 0.0, sin(a1)) * radius
		_triangle(surface, p0, p1, tip, bottom_color, bottom_color, top_color)
		_triangle(surface, p1, p0, base, bottom_color, bottom_color, bottom_color.darkened(0.2))


static func _cylinder(surface: SurfaceTool, base: Vector3, bottom_radius: float, top_radius: float,
		height: float, sides: int, bottom_color: Color, top_color: Color) -> void:
	var top := base + Vector3.UP * height
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var b0 := base + d0 * bottom_radius
		var b1 := base + d1 * bottom_radius
		var t0 := top + d0 * top_radius
		var t1 := top + d1 * top_radius
		_triangle(surface, b0, b1, t0, bottom_color, bottom_color, top_color)
		_triangle(surface, b1, t1, t0, bottom_color, top_color, top_color)
		_triangle(surface, t0, t1, top, top_color, top_color, top_color)


## A low-poly sphere (squashed vertically by `flatten`), colored from `low` to `high` height.
static func _sphere(surface: SurfaceTool, centre: Vector3, radius: float, flatten: float, sides: int,
		rings: int, low: float, high: float) -> void:
	var points := []
	for ring in rings + 1:
		var polar := PI * ring / rings
		var row := []
		for i in sides:
			var azimuth := TAU * i / sides + (0.5 if ring % 2 == 1 else 0.0) * TAU / sides
			row.append(centre + Vector3(sin(polar) * cos(azimuth), cos(polar) * flatten, sin(polar) * sin(azimuth)) * radius)
		points.append(row)
	for ring in rings:
		for i in sides:
			var a: Vector3 = points[ring][i]
			var b: Vector3 = points[ring][(i + 1) % sides]
			var c: Vector3 = points[ring + 1][i]
			var d: Vector3 = points[ring + 1][(i + 1) % sides]
			_triangle(surface, a, c, b, _shade(a.y, low, high), _shade(c.y, low, high), _shade(b.y, low, high))
			_triangle(surface, b, c, d, _shade(b.y, low, high), _shade(c.y, low, high), _shade(d.y, low, high))


static func _shade(height: float, low: float, high: float) -> Color:
	var t := clampf(inverse_lerp(low, high, height), 0.0, 1.0)
	return Color.WHITE.darkened(0.3).lerp(Color.WHITE.lightened(0.08), t)
