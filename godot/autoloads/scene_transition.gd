extends CanvasLayer
## Changes of screen with a transition: a fade to black between menus, and a camera shutter
## (two bars closing and opening) around the loading screen when a stage starts. While it
## works it swallows the input. The scene it opens gets `current_payload()` (the stage to
## play, the screen to show).


signal transition_finished

const FADE_SECONDS := 0.25
const SHUTTER_SECONDS := 0.22
const MAIN_SCENE := "res://game/main.tscn"
const STAGE_SCENE := "res://game/stage.tscn"
const LOADING_SCREEN := "res://gui/front/loading_screen.tscn"
## Least time the loading screen stays up once the stage is ready, so it can be read.
const LOADING_HOLD_SECONDS := 0.35

## True while a transition runs.
var busy := false
## Node that receives the new scenes instead of the scene tree root (the automated checks
## keep their own scene running this way).
var host: Node = null
## The last scene opened by a transition.
var current: Node = null

var _payload := {}
var _fade: ColorRect
var _shutter_top: ColorRect
var _shutter_bottom: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = _cover(Color.BLACK)
	_fade.modulate.a = 0.0
	_shutter_top = _cover(UIPalette.BG)
	_shutter_bottom = _cover(UIPalette.BG)
	for bar: ColorRect in [_shutter_top, _shutter_bottom]:
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		bar.visible = false
	_shutter_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)


func _cover(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	return rect


## What the scene opened by the last transition should show ({"stage": StageInfo} for a stage,
## {"screen": "menu"} to open the main menu directly).
func current_payload() -> Dictionary:
	return _payload


func _input(event: InputEvent) -> void:
	if busy and not event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


## Fades to black, replaces the current scene by `packed` and fades back in.
func fade_to_packed(packed: PackedScene, payload := {}) -> void:
	if busy:
		return
	busy = true
	await _fade_to(1.0)
	get_tree().paused = false
	_payload = payload
	_swap(packed.instantiate())
	await get_tree().process_frame
	await _fade_to(0.0)
	_done()


func fade_to_scene(path: String, payload := {}) -> void:
	await fade_to_packed(load(path) as PackedScene, payload)


## Back to the main menu (skipping the title screen).
func go_to_menu() -> void:
	await fade_to_scene(MAIN_SCENE, {"screen": "menu"})


## Plays `info`: closes the shutter, builds the stage in steps behind the loading screen
## (the game stays paused meanwhile), then opens the shutter on the stage.
func start_stage(info: StageInfo) -> void:
	if busy or info == null:
		return
	busy = true
	await _shutter(true)
	get_tree().paused = true
	_payload = {"stage": info}
	var loading := (load(LOADING_SCREEN) as PackedScene).instantiate()
	add_child(loading)
	move_child(loading, 0)
	loading.call(&"show_stage", info)
	var stage := (load(STAGE_SCENE) as PackedScene).instantiate() as Stage
	stage.prepare(info, true)
	var builder := stage.get_node("World/StageBuilder") as StageBuilder
	var _discard := builder.build_progress.connect(func(fraction: float, label: String) -> void:
		if is_instance_valid(loading):
			loading.call(&"set_progress", fraction, label))
	_swap(stage)
	await _shutter(false)
	if not stage.is_stage_ready:
		await stage.stage_ready
	loading.call(&"set_progress", 1.0, "LOADING_DONE")
	await get_tree().create_timer(LOADING_HOLD_SECONDS, true).timeout
	await _shutter(true)
	loading.queue_free()
	get_tree().paused = false
	await _shutter(false)
	_done()


## Plays the stage of the last transition (or the stage being played) again.
func reload_stage() -> void:
	var info: StageInfo = _payload.get("stage")
	if info == null and current is Stage:
		info = (current as Stage).stage_info
	await start_stage(info)


func _swap(node: Node) -> void:
	var parent := host if is_instance_valid(host) else get_tree().root
	var old: Node = current if is_instance_valid(current) else null
	if old == null and parent == get_tree().root:
		old = get_tree().current_scene
	if old and old.get_parent():
		old.get_parent().remove_child(old)
	if old:
		old.queue_free()
	parent.add_child(node)
	current = node
	if parent == get_tree().root:
		get_tree().current_scene = node


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	var _step := tween.tween_property(_fade, "modulate:a", alpha, FADE_SECONDS)
	await tween.finished


## Closes (both bars meet in the middle) or opens the shutter.
func _shutter(close: bool) -> void:
	var half := get_viewport().get_visible_rect().size.y / 2.0
	for bar: ColorRect in [_shutter_top, _shutter_bottom]:
		bar.visible = true
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN if close else Tween.EASE_OUT)
	var _a := tween.tween_property(_shutter_top, "offset_bottom", half if close else 0.0, SHUTTER_SECONDS)
	var _b := tween.tween_property(_shutter_bottom, "offset_top", -half if close else 0.0, SHUTTER_SECONDS)
	await tween.finished
	if not close:
		for bar: ColorRect in [_shutter_top, _shutter_bottom]:
			bar.visible = false


func _done() -> void:
	busy = false
	transition_finished.emit()
