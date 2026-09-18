## Base class for the checks run by check_all.tscn. A check builds whatever it needs as
## children, runs, and records failures with expect(). Run them with:
##   godot --headless --path godot --fixed-fps 100 res://debug/headless_checks/check_all.tscn
## Add "-- --only=drone" to run the checks whose name contains "drone".
class_name HeadlessCheck
extends Node3D


var failures: PackedStringArray = []


## Override: the body of the check. May await.
func run() -> void:
	pass


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("    FAIL: %s" % message)


func note(message: String) -> void:
	print("    %s" % message)


func physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func process_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


## A large static floor on the terrain layer, top face at y = 0.
func add_floor(size := 400.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)
	return body


## Presses and releases an input action through the input pipeline, like a real button
## (copy of drone-simulator's ui_smoke_test helper).
func action(action_name: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	await process_frames(1)
	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)
	await process_frames(2)


func focus_name() -> String:
	var focus := get_viewport().gui_get_focus_owner()
	return str(focus.name) if focus else "<none>"


## First descendant of `root` whose script is `script_path`.
func find_child_with_script(root: Node, script_path: String) -> Node:
	for child in root.get_children():
		var script := child.get_script() as Script
		if script and script.resource_path == script_path:
			return child
		var found := find_child_with_script(child, script_path)
		if found:
			return found
	return null
