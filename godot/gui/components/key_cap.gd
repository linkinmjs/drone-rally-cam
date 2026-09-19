## A button, key or stick drawn the way it looks on the device in use: the PlayStation shapes
## (✕ ○ □ △ in their colors), the Xbox letters in theirs, shoulders, triggers and system
## buttons as pills, the D-pad as a cross with its direction lit, and keyboard keys as keys.
## Drawn in code; it follows the device in use and the controls remapping by itself.
## Used by the menu footers, the confirm dialog, the pause menu and the help page. The texts
## of the game (guide, checklist) keep using InputHints.button(): one table of names.
class_name KeyCap
extends Control


enum Kind {FACE, PILL, DPAD, KEY}

## Glyphs that stand for no single binding.
const GLYPH_DPAD := &"glyph_dpad"
const GLYPH_ARROWS := &"glyph_arrows"

const FACE_BUTTONS: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]
const PLAYSTATION_COLORS := {
	JOY_BUTTON_A: Color("#7CB2E8"), JOY_BUTTON_B: Color("#FF6B6B"),
	JOY_BUTTON_X: Color("#E59CD8"), JOY_BUTTON_Y: Color("#3FD6A0"),
}
const XBOX_COLORS := {
	JOY_BUTTON_A: Color("#6CC24A"), JOY_BUTTON_B: Color("#E2403A"),
	JOY_BUTTON_X: Color("#3A8FE2"), JOY_BUTTON_Y: Color("#F2C12E"),
}
const DPAD_DIRECTIONS := {
	JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
	JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT,
}
const FACE_FILL := Color("#121418")

## Action shown (ui_accept, rec_toggle…) or a GLYPH_* constant.
@export var action: StringName = &"":
	set(value):
		action = value
		if is_node_ready():
			refresh()
## Menu actions follow the device of the menus (InputHints.menu_uses_pad); game actions the
## last device used to play (Controls.using_gamepad).
@export var menu := true
## Height of the cap; the width follows the content.
@export var cap_height := 30.0:
	set(value):
		cap_height = value
		if is_node_ready():
			refresh()
## Always the gamepad binding, never the keyboard one (Options > Controls, which is about
## the controller).
@export var gamepad_only := false
## Shown as a key on keyboard and mouse instead of the first binding, for actions spread over
## several keys or on the mouse ("W A S D", "Mouse").
@export var keyboard_text := ""
## Fixed text drawn as a pill instead of an action (radio sticks: "Pitch ↕").
var fixed_text := "":
	set(value):
		fixed_text = value
		if is_node_ready():
			refresh()

## Current look: {"kind": Kind, "text": String, "button": int, "dir": Vector2,
## "playstation": bool}.
var shape := {}

static var _font: Font = null
static var _box_styles := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var _discard := Controls.input_device_changed.connect(refresh.unbind(1))
	_discard = UI.input_kind_changed.connect(refresh.unbind(1))
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Reads the binding again and resizes.
func refresh() -> void:
	if not fixed_text.is_empty():
		shape = {"kind": Kind.PILL, "text": fixed_text}
	elif gamepad_only:
		shape = shape_of(InputHints.first_event(action, true), Controls.is_playstation_pad())
	else:
		var gamepad := InputHints.menu_uses_pad() if menu else Controls.using_gamepad
		if not gamepad and not keyboard_text.is_empty():
			shape = {"kind": Kind.KEY, "text": keyboard_text}
		else:
			shape = shape_for(action, gamepad, Controls.is_playstation_pad())
	custom_minimum_size = Vector2(_width(), cap_height)
	update_minimum_size()
	queue_redraw()


## Text of the glyph ("✕", "L1", "Esc"), for hints and checks.
func get_text() -> String:
	return String(shape.get("text", ""))


## How `action` looks on a gamepad (Xbox or PlayStation) or on keyboard and mouse. When the
## action has no binding on that device, the other device's binding is shown.
static func shape_for(target: StringName, gamepad: bool, playstation: bool) -> Dictionary:
	if target == GLYPH_DPAD:
		return {"kind": Kind.DPAD, "text": TranslationServer.translate("UI_KEY_DPAD"), "dir": Vector2.ZERO}
	if target == GLYPH_ARROWS:
		return {"kind": Kind.KEY, "text": "↑ ↓"}
	var event := InputHints.first_event(target, gamepad)
	if event == null:
		event = InputHints.first_event(target, not gamepad)
	return shape_of(event, playstation)


static func shape_of(event: InputEvent, playstation: bool) -> Dictionary:
	if event is InputEventJoypadButton:
		var index := (event as InputEventJoypadButton).button_index
		var table := InputHints.PLAYSTATION_BUTTONS if playstation else InputHints.XBOX_BUTTONS
		var text: String = table.get(index, "Botón %d" % index)
		if index in FACE_BUTTONS:
			return {"kind": Kind.FACE, "text": text, "button": index, "playstation": playstation}
		if DPAD_DIRECTIONS.has(index):
			return {"kind": Kind.DPAD, "text": text, "dir": DPAD_DIRECTIONS[index]}
		return {"kind": Kind.PILL, "text": text}
	if event is InputEventJoypadMotion:
		var axis := (event as InputEventJoypadMotion).axis
		var text := ""
		match axis:
			JOY_AXIS_TRIGGER_LEFT:
				text = "L2" if playstation else "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				text = "R2" if playstation else "RT"
			_:
				text = InputHints.joy_axis_name(axis)
		return {"kind": Kind.PILL, "text": text}
	if event is InputEventKey or event is InputEventMouseButton:
		return {"kind": Kind.KEY, "text": InputHints.name_of(event)}
	return {"kind": Kind.PILL, "text": "—"}


static func font() -> Font:
	if _font == null:
		_font = load(UIPalette.FONT_BOLD) as Font
	return _font


func _font_size() -> int:
	return int(round(cap_height * 0.5))


func _width() -> float:
	var kind: Kind = shape.get("kind", Kind.PILL)
	if kind == Kind.FACE or kind == Kind.DPAD:
		return cap_height
	var text_width := font().get_string_size(get_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x
	return maxf(cap_height, ceilf(text_width) + cap_height * 0.6)


func _draw() -> void:
	var rect := Rect2(Vector2(0.0, (size.y - cap_height) / 2.0), Vector2(size.x, cap_height))
	match shape.get("kind", Kind.PILL):
		Kind.FACE:
			_draw_face(rect)
		Kind.DPAD:
			_draw_dpad(rect)
		Kind.KEY:
			draw_style_box(_box(6, true), rect)
			_draw_text(rect, UIPalette.TEXT, -1.0)
		_:
			draw_style_box(_box(int(cap_height / 2.0), false), rect)
			_draw_text(rect, UIPalette.TEXT, 0.0)


func _draw_face(rect: Rect2) -> void:
	var center := rect.get_center()
	var radius := cap_height / 2.0
	draw_circle(center, radius, FACE_FILL, true, -1.0, true)
	draw_circle(center, radius - 0.75, UIPalette.BORDER_STRONG, false, 1.5, true)
	var button: int = shape.get("button", JOY_BUTTON_A)
	if not shape.get("playstation", false):
		_draw_text(rect, XBOX_COLORS.get(button, UIPalette.TEXT), 0.0)
		return
	var color: Color = PLAYSTATION_COLORS.get(button, UIPalette.TEXT)
	var width := maxf(cap_height * 0.085, 1.5)
	var r := radius * 0.42
	match button:
		JOY_BUTTON_A:
			draw_line(center + Vector2(-r, -r), center + Vector2(r, r), color, width, true)
			draw_line(center + Vector2(-r, r), center + Vector2(r, -r), color, width, true)
		JOY_BUTTON_B:
			draw_arc(center, r * 1.05, 0.0, TAU, 32, color, width, true)
		JOY_BUTTON_X:
			draw_rect(Rect2(center - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), color, false, width)
		JOY_BUTTON_Y:
			var top := center + Vector2(0.0, -r * 1.1)
			var left := center + Vector2(-r * 1.05, r * 0.75)
			var right := center + Vector2(r * 1.05, r * 0.75)
			draw_polyline(PackedVector2Array([top, left, right, top]), color, width, true)


func _draw_dpad(rect: Rect2) -> void:
	var center := rect.get_center()
	var arm := cap_height * 0.34
	var reach := cap_height / 2.0 - 1.0
	var base := UIPalette.BORDER_STRONG
	draw_rect(Rect2(center.x - reach, center.y - arm / 2.0, reach * 2.0, arm), base)
	draw_rect(Rect2(center.x - arm / 2.0, center.y - reach, arm, reach * 2.0), base)
	var dir: Vector2 = shape.get("dir", Vector2.ZERO)
	if dir == Vector2.ZERO:
		draw_rect(Rect2(center - Vector2(arm, arm) / 2.0, Vector2(arm, arm)), UIPalette.TEXT_2)
		return
	# The pressed arm, from the centre to its end.
	var end := center + dir * reach
	var lit := Rect2(center, Vector2.ZERO).expand(end)
	lit = lit.grow_individual(arm / 2.0 if dir.x == 0.0 else 0.0, arm / 2.0 if dir.y == 0.0 else 0.0,
			arm / 2.0 if dir.x == 0.0 else 0.0, arm / 2.0 if dir.y == 0.0 else 0.0)
	draw_rect(lit, UIPalette.TEXT)


func _draw_text(rect: Rect2, color: Color, offset_y: float) -> void:
	var font_size := _font_size()
	var f := font()
	var baseline := rect.position.y + (rect.size.y + f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0
	draw_string(f, Vector2(rect.position.x, baseline + offset_y), get_text(), HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, font_size, color)


static func _box(radius: int, key: bool) -> StyleBoxFlat:
	var id := "%d_%s" % [radius, key]
	if not _box_styles.has(id):
		var style := ThemeBuilder.flat(UIPalette.SURFACE_ALT, radius, Vector4.ZERO, UIPalette.BORDER_STRONG, 1)
		if key:
			# A key has a darker lip at the bottom.
			style.border_width_bottom = 3
		_box_styles[id] = style
	return _box_styles[id]
