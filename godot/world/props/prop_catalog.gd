## The rally set dressing of a stage, placed from its road with a generator of its own
## (scenery_seed + 2): start arch and finish banner across the road, kilometre boards, red and
## white tape on the outside of tight corners, hay bales at the three tightest, spectators in
## clearings, marshals with flags, the service van under an awning at the start and a stretch
## of fence. Props of a kind share a MultiMesh; only the van and the bales collide.
class_name PropCatalog
extends RefCounted


const MATERIAL := preload("res://world/materials/props.tres")
## Corners tighter than this radius (m) get tape on the outside.
const TAPE_RADIUS := 45.0
## Road distances (m) of each kind, from the centre line.
const STAKE_OFFSET := 2.4
const BALE_OFFSET := 1.9
const ARCH_OFFSET := 1.8
const SHIRTS: Array[Color] = [Color(0.85, 0.2, 0.18), Color(0.2, 0.4, 0.8), Color(0.95, 0.78, 0.2),
		Color(0.3, 0.62, 0.32), Color(0.94, 0.93, 0.9), Color(0.55, 0.3, 0.62), Color(0.2, 0.22, 0.26)]
const MARSHAL_VEST := Color(1.0, 0.45, 0.1)

var builder: StageBuilder
var rng := RandomNumberGenerator.new()
## Transforms of every prop by kind, in this node's space (for the checks).
var transforms := {}
## Points of the solid props (van, bales, spectators, stakes, marshals) by kind: they must stay
## off the road.
var solid := {}

var _colors := {}
var _node: Node3D
var _curvature := PackedFloat32Array()


## Places the props of `stage_builder` under `parent`.
static func place(stage_builder: StageBuilder, parent: Node3D) -> PropCatalog:
	var catalog := PropCatalog.new()
	catalog.builder = stage_builder
	catalog.rng.seed = stage_builder.scenery_seed + 2
	catalog._node = Node3D.new()
	catalog._node.name = "Props"
	parent.add_child(catalog._node)
	catalog._build()
	return catalog


func _build() -> void:
	var samples := builder.road_samples
	if samples.size() < 40:
		return
	_curvature = _compute_curvature()
	_arches()
	_km_boards()
	_tape()
	_bales()
	_van()
	_marshals()
	_spectators()
	_fence()
	_flush()


# --- Road helpers --------------------------------------------------------------------------

## Point, forward and side (the +offset direction of the road mesh) of a road sample.
func _frame(index: int) -> Dictionary:
	var samples := builder.road_samples
	var i := clampi(index, 0, samples.size() - 1)
	var previous := samples[maxi(i - 1, 0)]
	var next := samples[mini(i + 1, samples.size() - 1)]
	var forward := Vector3(next.x - previous.x, 0.0, next.z - previous.z).normalized()
	return {"point": samples[i], "forward": forward, "side": Vector3(-forward.z, 0.0, forward.x)}


## Signed curvature (1/m) at every sample, over a 16 m window: positive when the road turns
## toward its +side.
func _compute_curvature() -> PackedFloat32Array:
	var samples := builder.road_samples
	var values := PackedFloat32Array()
	values.resize(samples.size())
	for i in samples.size():
		var a := samples[maxi(i - 4, 0)]
		var b := samples[i]
		var c := samples[mini(i + 4, samples.size() - 1)]
		var f1 := Vector2(b.x - a.x, b.z - a.z)
		var f2 := Vector2(c.x - b.x, c.z - b.z)
		if f1.length() < 0.1 or f2.length() < 0.1:
			continue
		var angle := atan2(f1.x * f2.y - f1.y * f2.x, f1.dot(f2))
		values[i] = angle / ((f1.length() + f2.length()) * 0.5)
	return values


func _on_ground(point: Vector3) -> Vector3:
	return Vector3(point.x, builder.get_height(point.x, point.z), point.z)


## Basis whose +Z faces `direction` on the ground plane.
static func _facing(direction: Vector3) -> Basis:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	return Basis.looking_at(-flat, Vector3.UP)


func _add(kind: String, xform: Transform3D, color := Color.WHITE) -> void:
	if not transforms.has(kind):
		transforms[kind] = [] as Array[Transform3D]
		_colors[kind] = PackedColorArray()
	(transforms[kind] as Array[Transform3D]).append(xform)
	var colors: PackedColorArray = _colors[kind]
	colors.append(color)
	_colors[kind] = colors


func _solid(kind: String, point: Vector3) -> void:
	var points: PackedVector3Array = solid.get(kind, PackedVector3Array())
	points.append(point)
	solid[kind] = points
	builder.occupy(point)


# --- Props ---------------------------------------------------------------------------------

func _arches() -> void:
	var width := builder.road_width + ARCH_OFFSET * 2.0
	var samples := builder.road_samples
	for data: Array in [[2, "LARGADA", "ArchStart"], [samples.size() - 3, "META", "ArchFinish"]]:
		var frame := _frame(data[0])
		var xform := Transform3D(_facing(frame["forward"]), frame["point"])
		_add(data[2], xform)
		var arch := MeshInstance3D.new()
		arch.name = data[2]
		arch.mesh = PropMeshes.arch(width)
		arch.material_override = MATERIAL
		arch.transform = xform
		_node.add_child(arch)
		for side: float in [1.0, -1.0]:
			var label := _label(data[1], 96, 0.01, Color.WHITE)
			label.position = Vector3(0.0, PropMeshes.ARCH_CLEARANCE + 0.55, 0.09 * side)
			label.rotation.y = 0.0 if side > 0.0 else PI
			arch.add_child(label)


func _km_boards() -> void:
	var kilometre := 1
	while kilometre * 1000.0 < builder.get_road_length() - 50.0:
		var frame := _frame(roundi(kilometre * 1000.0 / StageBuilder.ROAD_STEP))
		var spot := _on_ground(frame["point"] + frame["side"] * (builder.road_width * 0.5 + 2.6))
		var xform := Transform3D(_facing(-frame["side"]), spot)
		_add("KmBoards", xform)
		var label := _label("KM %d" % kilometre, 64, 0.006, PropMeshes.DARK)
		label.transform = xform * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.75, 0.07))
		_node.add_child(label)
		kilometre += 1


## Stakes every 4 m with tape between them, on the outside of every corner tighter than
## TAPE_RADIUS.
func _tape() -> void:
	var previous_stake := Vector3.INF
	var previous_index := -100
	for i in range(8, builder.road_samples.size() - 8, 2):
		var curvature := _curvature[i]
		if absf(curvature) < 1.0 / TAPE_RADIUS:
			continue
		var frame := _frame(i)
		var outside := -signf(curvature)
		var spot := _on_ground(frame["point"] + frame["side"] * outside * (builder.road_width * 0.5 + STAKE_OFFSET))
		_add("Stakes", Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), spot))
		_solid("stakes", spot)
		if i - previous_index == 2 and previous_stake.distance_to(spot) < 6.0:
			var span := spot - previous_stake
			var along := Vector3(span.x, 0.0, span.z)
			# The tape mesh runs along its local X: turn it toward the next stake, then stretch it.
			var basis := Basis(Vector3.UP, atan2(-along.z, along.x)) * Basis.from_scale(Vector3(along.length(), 1.0, 1.0))
			var height := (previous_stake.y + spot.y) * 0.5 + 0.75
			_add("Tape", Transform3D(basis, Vector3(previous_stake.x, height, previous_stake.z)))
		previous_stake = spot
		previous_index = i


## Four round bales on the outside of each of the three tightest corners.
func _bales() -> void:
	var apexes: Array[int] = []
	var order := range(10, builder.road_samples.size() - 10)
	order.sort_custom(func(a: int, b: int) -> bool: return absf(_curvature[a]) > absf(_curvature[b]))
	for i: int in order:
		if apexes.size() >= 3:
			break
		var far_enough := true
		for apex in apexes:
			if absi(apex - i) < 40:
				far_enough = false
		if far_enough:
			apexes.append(i)
	var body := StaticBody3D.new()
	body.name = "BaleColliders"
	body.collision_layer = StageBuilder.TERRAIN_LAYER
	body.collision_mask = 0
	_node.add_child(body)
	for apex in apexes:
		var outside := -signf(_curvature[apex])
		for k in 4:
			var frame := _frame(apex)
			var spot := _on_ground(frame["point"] + frame["side"] * outside * (builder.road_width * 0.5 + BALE_OFFSET + 0.6)
					+ frame["forward"] * (k - 1.5) * 1.3)
			var xform := Transform3D(_facing(frame["forward"]), spot)
			_add("Bales", xform)
			_solid("bales", spot)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.2, 1.2, 1.2)
			shape.shape = box
			shape.transform = Transform3D(xform.basis, spot + Vector3.UP * 0.6)
			body.add_child(shape)


## The service van and its awning near the start, off the road.
func _van() -> void:
	var frame := _frame(14)
	var spot := _on_ground(frame["point"] + frame["side"] * (builder.road_width * 0.5 + 8.0))
	var xform := Transform3D(_facing(frame["forward"]), spot)
	_add("Van", xform)
	var van := MeshInstance3D.new()
	van.name = "ServiceVan"
	van.mesh = PropMeshes.van()
	van.material_override = MATERIAL
	van.transform = xform
	_node.add_child(van)
	var body := StaticBody3D.new()
	body.name = "VanCollider"
	body.collision_layer = StageBuilder.TERRAIN_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.9, 4.8)
	shape.shape = box
	shape.transform = Transform3D(xform.basis, spot + xform.basis * Vector3(0.0, 0.95, 0.2))
	body.add_child(shape)
	_node.add_child(body)
	for corner: Vector3 in [Vector3(1.0, 0.0, 2.5), Vector3(-1.0, 0.0, 2.5), Vector3(1.0, 0.0, -2.2), Vector3(-1.0, 0.0, -2.2)]:
		_solid("van", xform * corner)
	var awning := MeshInstance3D.new()
	awning.name = "Awning"
	awning.mesh = PropMeshes.awning()
	awning.material_override = MATERIAL
	var awning_spot := _on_ground(spot - frame["forward"] * 5.5 + frame["side"] * 0.5)
	awning.transform = Transform3D(_facing(-frame["side"]), awning_spot)
	_add("Awning", awning.transform)
	_node.add_child(awning)


## A marshal with a flag at the start and another halfway.
func _marshals() -> void:
	var samples := builder.road_samples
	for data: Array in [[8, -1.0], [int(samples.size() * 0.5), 1.0]]:
		var frame := _frame(data[0])
		var spot := _on_ground(frame["point"] + frame["side"] * data[1] * (builder.road_width * 0.5 + 3.2))
		var xform := Transform3D(_facing(-frame["side"] * data[1]), spot)
		_add("Bodies", xform, MARSHAL_VEST)
		_add("Heads", xform)
		_add("Flags", xform)
		_solid("marshals", spot)


## Three groups of four to six spectators in clearings by the road, facing it.
func _spectators() -> void:
	var samples := builder.road_samples
	for fraction: float in [0.3, 0.55, 0.8]:
		var near := samples[int(samples.size() * fraction)]
		var spot := builder.find_clear_spot(near, 10.0, 6.0)
		if spot == near:
			continue
		var closest := _closest_sample(spot)
		var toward := (samples[closest] - spot)
		toward.y = 0.0
		toward = toward.normalized()
		var along := Vector3(-toward.z, 0.0, toward.x)
		var count := rng.randi_range(4, 6)
		for k in count:
			var offset := along * (k - (count - 1) * 0.5) * 0.85 + toward * rng.randf_range(-0.5, 0.5)
			var person := _on_ground(spot + offset)
			var basis := _facing(toward).rotated(Vector3.UP, rng.randf_range(-0.35, 0.35))
			var shirt := SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
			var height := rng.randf_range(0.92, 1.06)
			var xform := Transform3D(basis.scaled(Vector3.ONE * height), person)
			_add("Bodies", xform, shirt)
			_add("Heads", xform)
			_solid("spectators", person)


## Posts and two wires along the straightest stretch of the middle of the road.
func _fence() -> void:
	var samples := builder.road_samples
	var best := -1
	var best_turn := INF
	for start in range(int(samples.size() * 0.25), int(samples.size() * 0.7), 5):
		var turn := 0.0
		for i in range(start, mini(start + 30, samples.size())):
			turn += absf(_curvature[i])
		if turn < best_turn:
			best_turn = turn
			best = start
	if best < 0:
		return
	var previous := Vector3.INF
	for i in range(best, best + 30, 2):
		var frame := _frame(i)
		var post := _on_ground(frame["point"] - frame["side"] * (builder.road_width * 0.5 + 6.0))
		_add("FencePosts", Transform3D(Basis.IDENTITY, post))
		if previous != Vector3.INF:
			var span := post - previous
			var flat := Vector3(span.x, 0.0, span.z)
			var basis := Basis(Vector3.UP, atan2(-flat.z, flat.x)) * Basis.from_scale(Vector3(flat.length(), 1.0, 1.0))
			_add("FenceWires", Transform3D(basis, Vector3(previous.x, (previous.y + post.y) * 0.5, previous.z)))
		previous = post


func _closest_sample(point: Vector3) -> int:
	var best := 0
	var best_distance := INF
	var samples := builder.road_samples
	for i in range(0, samples.size(), 2):
		var distance := Vector2(samples[i].x - point.x, samples[i].z - point.z).length_squared()
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


# --- Output --------------------------------------------------------------------------------

## Props drawn as one MultiMesh per kind; only the spectators' bodies keep their colors.
const MULTIMESHES: Array[String] = ["KmBoards", "Stakes", "Tape", "Bales", "Bodies", "Heads", "Flags",
		"FencePosts", "FenceWires"]


static func _mesh_of(kind: String) -> ArrayMesh:
	match kind:
		"KmBoards":
			return PropMeshes.km_board()
		"Stakes":
			return PropMeshes.stake()
		"Tape":
			return PropMeshes.tape()
		"Bales":
			return PropMeshes.hay_bale()
		"Bodies":
			return PropMeshes.person_body()
		"Heads":
			return PropMeshes.person_head()
		"Flags":
			return PropMeshes.flag()
		"FencePosts":
			return PropMeshes.fence_post()
	return PropMeshes.fence_wire()


func _flush() -> void:
	for kind in MULTIMESHES:
		if not transforms.has(kind):
			continue
		var mesh := _mesh_of(kind)
		var colors: PackedColorArray = _colors[kind] if kind == "Bodies" else PackedColorArray()
		var instance := builder._multimesh(kind, mesh, MATERIAL, transforms[kind], Transform3D.IDENTITY, colors)
		if kind == "Tape" or kind == "FenceWires":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_node.add_child(instance)


func _label(text: String, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = load(UIPalette.FONT_BOLD) as Font
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	return label
