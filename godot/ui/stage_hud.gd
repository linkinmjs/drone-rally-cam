## On-foot overlay: stage status and the rally radio at the top, the checklist of what to do
## next, a small dot in the centre, what "interact" would do, a marker on the deployed drone
## and short notices.
class_name StageHud
extends Control


var radio_feed: RadioFeed
var drone_marker: WorldMarker

var _status: Label
var _prompt: Label
var _notice: Label
var _crosshair: Label
var _checklist_panel: PanelContainer
var _checklist: VBoxContainer
var _checklist_title: Label
var _notice_time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	drone_marker = WorldMarker.new()
	drone_marker.offset = Vector3(0.0, 0.35, 0.0)
	drone_marker.visible = false
	add_child(drone_marker)

	_status = HudStyle.make_label("", 26, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_status)
	HudStyle.anchor(_status, Control.PRESET_CENTER_TOP, 28.0)

	radio_feed = RadioFeed.new()
	add_child(radio_feed)
	HudStyle.anchor(radio_feed, Control.PRESET_CENTER_TOP, 66.0)

	_checklist_panel = PanelContainer.new()
	_checklist_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.05, 0.45)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_checklist_panel.add_theme_stylebox_override("panel", style)
	add_child(_checklist_panel)
	HudStyle.anchor(_checklist_panel, Control.PRESET_TOP_LEFT, 20.0)
	_checklist = VBoxContainer.new()
	_checklist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_checklist.add_theme_constant_override("separation", 4)
	_checklist_panel.add_child(_checklist)
	_checklist_title = HudStyle.make_label("QUÉ HACER", 16, HudStyle.DIM)
	_checklist.add_child(_checklist_title)

	_crosshair = HudStyle.make_label("·", 34, HudStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	_prompt = HudStyle.make_label("", 24, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_prompt)
	HudStyle.anchor(_prompt, Control.PRESET_CENTER_BOTTOM, 150.0)

	_notice = HudStyle.make_label("", 24, HudStyle.AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_notice)
	HudStyle.anchor(_notice, Control.PRESET_CENTER_BOTTOM, 200.0)


func set_status(text: String) -> void:
	_status.text = text


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_crosshair_visible(value: bool) -> void:
	_crosshair.visible = value


## Steps of the stage; the ones before `current` are done, `current` is highlighted.
func set_checklist(steps: PackedStringArray, current: int) -> void:
	while _checklist.get_child_count() - 1 < steps.size():
		_checklist.add_child(HudStyle.make_label("", 20))
	for i in steps.size():
		var label := _checklist.get_child(i + 1) as Label
		if i < current:
			label.text = "✓ %s" % steps[i]
			label.add_theme_color_override("font_color", Color(HudStyle.GREEN, 0.75))
		elif i == current:
			label.text = "▶ %s" % steps[i]
			label.add_theme_color_override("font_color", HudStyle.WHITE)
		else:
			label.text = "   %s" % steps[i]
			label.add_theme_color_override("font_color", HudStyle.DIM)


func set_checklist_visible(value: bool) -> void:
	_checklist_panel.visible = value


func get_checklist_line(index: int) -> String:
	if index + 1 >= _checklist.get_child_count():
		return ""
	return (_checklist.get_child(index + 1) as Label).text


func show_notice(text: String, seconds := 3.0) -> void:
	_notice.text = text
	_notice_time = seconds


func _process(delta: float) -> void:
	_notice_time -= delta
	_notice.visible = _notice_time > 0.0
