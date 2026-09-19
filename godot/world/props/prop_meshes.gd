## Low-poly meshes of the rally props, built in code with vertex colors so they all share one
## material (world/materials/props.tres): start and finish arch, kilometre board, tape and
## stakes, hay bale, spectator (body and head), marshal's flag, service van, awning and fence.
## Each mesh stands on its origin; its front faces +Z. Built once and shared.
class_name PropMeshes
extends RefCounted


const RED := Color(0.86, 0.16, 0.12)
const WHITE := Color(0.94, 0.93, 0.9)
const ORANGE := Color(1.0, 0.42, 0.17)
const DARK := Color(0.12, 0.12, 0.13)
const STRAW := Color(0.86, 0.72, 0.42)
const WOOD := Color(0.42, 0.3, 0.2)
const SKIN := Color(0.86, 0.68, 0.55)
const YELLOW := Color(0.96, 0.8, 0.2)
## Clear height under the arch banner.
const ARCH_CLEARANCE := 5.6

static var _cache := {}


## Arch over the road: two striped posts `width` apart and a banner on top.
static func arch(width: float) -> ArrayMesh:
	var id := "arch_%.1f" % width
	if not _cache.has(id):
		var surface := _begin()
		for sign: float in [-1.0, 1.0]:
			for segment in 7:
				var color := RED if segment % 2 == 0 else WHITE
				_box(surface, Vector3(sign * width * 0.5, 0.45 + segment * 0.9, 0.0), Vector3(0.32, 0.9, 0.32), color)
		var banner_y := ARCH_CLEARANCE + 0.55
		_box(surface, Vector3(0.0, banner_y, 0.0), Vector3(width + 0.4, 1.1, 0.16), ORANGE)
		_box(surface, Vector3(0.0, banner_y + 0.6, 0.0), Vector3(width + 0.6, 0.1, 0.2), DARK)
		_box(surface, Vector3(0.0, banner_y - 0.6, 0.0), Vector3(width + 0.6, 0.1, 0.2), DARK)
		_cache[id] = _end(surface)
	return _cache[id]


## Kilometre board: a post and a yellow panel facing +Z.
static func km_board() -> ArrayMesh:
	return _cached("km_board", func(surface: SurfaceTool) -> void:
		_box(surface, Vector3(0.0, 0.8, 0.0), Vector3(0.1, 1.6, 0.1), WOOD)
		_box(surface, Vector3(0.0, 1.75, 0.03), Vector3(0.95, 0.62, 0.05), YELLOW)
		_box(surface, Vector3(0.0, 1.75, 0.0), Vector3(1.02, 0.7, 0.03), DARK))


static func stake() -> ArrayMesh:
	return _cached("stake", func(surface: SurfaceTool) -> void:
		_box(surface, Vector3(0.0, 0.35, 0.0), Vector3(0.06, 0.7, 0.06), WHITE)
		_box(surface, Vector3(0.0, 0.85, 0.0), Vector3(0.06, 0.3, 0.06), RED))


## One metre of red and white tape along +X (scaled to the gap between two stakes).
static func tape() -> ArrayMesh:
	return _cached("tape", func(surface: SurfaceTool) -> void:
		for stripe in 4:
			_box(surface, Vector3(stripe * 0.25 + 0.125, 0.0, 0.0), Vector3(0.25, 0.07, 0.01),
					RED if stripe % 2 == 0 else WHITE))


## A round bale lying with its axis along Z.
static func hay_bale() -> ArrayMesh:
	return _cached("bale", func(surface: SurfaceTool) -> void:
		_cylinder_z(surface, Vector3(0.0, 0.6, 0.0), 0.6, 1.2, 10, STRAW, STRAW.darkened(0.25)))


## A spectator's body (legs, torso, arms): white torso, tinted per instance.
static func person_body() -> ArrayMesh:
	return _cached("person_body", func(surface: SurfaceTool) -> void:
		_box(surface, Vector3(-0.1, 0.43, 0.0), Vector3(0.15, 0.86, 0.2), DARK.lightened(0.3))
		_box(surface, Vector3(0.1, 0.43, 0.0), Vector3(0.15, 0.86, 0.2), DARK.lightened(0.3))
		_box(surface, Vector3(0.0, 1.15, 0.0), Vector3(0.46, 0.62, 0.26), WHITE)
		_box(surface, Vector3(-0.29, 1.1, 0.02), Vector3(0.11, 0.56, 0.12), WHITE)
		_box(surface, Vector3(0.29, 1.1, 0.02), Vector3(0.11, 0.56, 0.12), WHITE))


static func person_head() -> ArrayMesh:
	return _cached("person_head", func(surface: SurfaceTool) -> void:
		_box(surface, Vector3(0.0, 1.62, 0.0), Vector3(0.22, 0.25, 0.22), SKIN)
		_box(surface, Vector3(0.0, 1.77, -0.01), Vector3(0.24, 0.07, 0.26), DARK))


## The marshal's flag, held at the right hand.
static func flag() -> ArrayMesh:
	return _cached("flag", func(surface: SurfaceTool) -> void:
		_box(surface, Vector3(0.36, 1.35, 0.1), Vector3(0.03, 1.5, 0.03), WOOD)
		_box(surface, Vector3(0.62, 1.9, 0.1), Vector3(0.5, 0.36, 0.02), YELLOW))


## Service van, front towards +Z.
static func van() -> ArrayMesh:
	return _cached("van", func(surface: SurfaceTool) -> void:
		_box(surface, Vector3(0.0, 1.25, -0.4), Vector3(2.0, 1.9, 3.6), WHITE)
		_box(surface, Vector3(0.0, 0.95, 1.9), Vector3(1.95, 1.3, 1.2), WHITE)
		_box(surface, Vector3(0.0, 1.35, 2.35), Vector3(1.8, 0.5, 0.35), DARK)
		_box(surface, Vector3(0.0, 1.0, -0.4), Vector3(2.02, 0.28, 3.62), ORANGE)
		for x: float in [-0.95, 0.95]:
			for z: float in [-1.5, 1.7]:
				_cylinder_x(surface, Vector3(x, 0.38, z), 0.38, 0.28, 10, DARK, DARK))


## Awning over a table: four posts and an orange roof.
static func awning() -> ArrayMesh:
	return _cached("awning", func(surface: SurfaceTool) -> void:
		for x: float in [-1.4, 1.4]:
			for z: float in [-1.4, 1.4]:
				_box(surface, Vector3(x, 1.1, z), Vector3(0.06, 2.2, 0.06), DARK)
		_box(surface, Vector3(0.0, 2.25, 0.0), Vector3(3.0, 0.08, 3.0), ORANGE)
		_box(surface, Vector3(0.0, 2.08, 1.5), Vector3(3.0, 0.3, 0.02), WHITE)
		_box(surface, Vector3(0.0, 0.75, 0.0), Vector3(1.6, 0.05, 0.7), WOOD)
		_box(surface, Vector3(0.0, 0.37, 0.0), Vector3(1.4, 0.74, 0.05), WOOD))


static func fence_post() -> ArrayMesh:
	return _cached("fence_post", func(surface: SurfaceTool) -> void:
		_box(surface, Vector3(0.0, 0.6, 0.0), Vector3(0.1, 1.2, 0.1), WOOD))


## One metre of two wires along +X.
static func fence_wire() -> ArrayMesh:
	return _cached("fence_wire", func(surface: SurfaceTool) -> void:
		_box(surface, Vector3(0.5, 0.55, 0.0), Vector3(1.0, 0.02, 0.02), DARK.lightened(0.35))
		_box(surface, Vector3(0.5, 1.0, 0.0), Vector3(1.0, 0.02, 0.02), DARK.lightened(0.35)))


# --- Builders ------------------------------------------------------------------------------

static func _cached(id: String, build: Callable) -> ArrayMesh:
	if not _cache.has(id):
		var surface := _begin()
		build.call(surface)
		_cache[id] = _end(surface)
	return _cache[id]


static func _begin() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	return surface


static func _end(surface: SurfaceTool) -> ArrayMesh:
	surface.generate_normals()
	return surface.commit()


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	# a b c d clockwise seen from the front.
	surface.set_color(color)
	for point: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(point)


static func _box(surface: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var corners := []
	for i in 8:
		corners.append(centre + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	# Each face clockwise seen from outside.
	_quad(surface, corners[4], corners[6], corners[7], corners[5], color)  # +Z
	_quad(surface, corners[1], corners[3], corners[2], corners[0], color)  # -Z
	_quad(surface, corners[5], corners[7], corners[3], corners[1], color)  # +X
	_quad(surface, corners[0], corners[2], corners[6], corners[4], color)  # -X
	_quad(surface, corners[6], corners[2], corners[3], corners[7], color)  # +Y
	_quad(surface, corners[0], corners[4], corners[5], corners[1], color)  # -Y


## A cylinder whose axis is Z, centred on `centre`.
static func _cylinder_z(surface: SurfaceTool, centre: Vector3, radius: float, length: float, sides: int,
		side_color: Color, cap_color: Color) -> void:
	var basis := Basis(Vector3.RIGHT, PI * 0.5)
	_cylinder(surface, centre, basis, radius, length, sides, side_color, cap_color)


static func _cylinder_x(surface: SurfaceTool, centre: Vector3, radius: float, length: float, sides: int,
		side_color: Color, cap_color: Color) -> void:
	var basis := Basis(Vector3.BACK, PI * 0.5)
	_cylinder(surface, centre, basis, radius, length, sides, side_color, cap_color)


## A capped cylinder along the local Y axis of `basis`, centred on `centre`.
static func _cylinder(surface: SurfaceTool, centre: Vector3, basis: Basis, radius: float, length: float,
		sides: int, side_color: Color, cap_color: Color) -> void:
	var top := centre + basis * Vector3(0.0, length * 0.5, 0.0)
	var bottom := centre - basis * Vector3(0.0, length * 0.5, 0.0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := basis * Vector3(cos(a0), 0.0, sin(a0)) * radius
		var d1 := basis * Vector3(cos(a1), 0.0, sin(a1)) * radius
		_quad(surface, bottom + d0, bottom + d1, top + d1, top + d0, side_color)
		surface.set_color(cap_color)
		for point: Vector3 in [top, top + d0, top + d1, bottom, bottom + d1, bottom + d0]:
			surface.add_vertex(point)
