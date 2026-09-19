# Modified from drone-simulator (GPL-3.0), 2026: a chip with the flight mode and the armed state,
# sized from its text.
class_name HUDModeBadge
extends Control
## Rounded outline chip: flight mode and armed state ("ESTABILIZADO · ARMADO"). The mode
## blinks during crash recovery.


const PADDING := Vector2(18, 8)
const SEPARATOR := "  ·  "

var mode_key := "HUD_MODE_STABILIZED"
var state_key := "HUD_STATUS_DISARMED"
var state_color := HudStyle.AMBER
var show_mode := true
var show_state := true
var blinking := false
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_size()


func set_mode(key: String, blink := false) -> void:
	if key == mode_key and blink == blinking:
		return
	mode_key = key
	blinking = blink
	_update_size()


func set_state(key: String, color: Color) -> void:
	if key == state_key and color == state_color:
		return
	state_key = key
	state_color = color
	_update_size()


func set_parts(mode_visible: bool, state_visible: bool) -> void:
	show_mode = mode_visible
	show_state = state_visible
	visible = show_mode or show_state
	_update_size()


func label_text() -> String:
	var parts := PackedStringArray()
	if show_mode:
		parts.append(tr(mode_key))
	if show_state:
		parts.append(tr(state_key))
	return SEPARATOR.join(parts)


func _process(delta: float) -> void:
	if blinking and is_visible_in_tree():
		_time += delta
		queue_redraw()


func _update_size() -> void:
	var font := HudStyle.bold_font()
	var width := font.get_string_size(label_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, HudStyle.SIZE_M).x
	custom_minimum_size = Vector2(width, HudStyle.SIZE_M) + PADDING * 2.0 + Vector2(4, 4)
	update_minimum_size()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_size()


func _draw() -> void:
	if not show_mode and not show_state:
		return
	var box := Rect2(Vector2(2, 2), custom_minimum_size - Vector2(4, 4))
	var style := StyleBoxFlat.new()
	style.draw_center = true
	style.bg_color = Color(HudStyle.PANEL_BG, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(box.size.y / 2.0))
	style.anti_aliasing = true
	style.border_color = Color(HudStyle.WHITE, 0.85)
	draw_style_box(style, box)
	var font := HudStyle.bold_font()
	var baseline := box.position.y + PADDING.y + HudStyle.SIZE_M * 0.82
	var x := box.position.x + PADDING.x
	if show_mode:
		var mode_alpha := 0.25 if blinking and fmod(_time, 0.8) > 0.5 else 1.0
		var mode_text := tr(mode_key)
		HUDDraw.text(self, font, Vector2(x, baseline), mode_text, HudStyle.SIZE_M,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, Color(HudStyle.WHITE, mode_alpha))
		x += font.get_string_size(mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, HudStyle.SIZE_M).x
		if show_state:
			HUDDraw.text(self, font, Vector2(x, baseline), SEPARATOR, HudStyle.SIZE_M,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, HudStyle.DIM)
			x += font.get_string_size(SEPARATOR, HORIZONTAL_ALIGNMENT_LEFT, -1, HudStyle.SIZE_M).x
	if show_state:
		HUDDraw.text(self, font, Vector2(x, baseline), tr(state_key), HudStyle.SIZE_M,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, state_color)
