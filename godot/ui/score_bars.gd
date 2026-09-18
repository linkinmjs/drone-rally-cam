## Live scoring while recording: one bar per aspect of the shot and a tip on what to fix,
## so the player learns what the producer wants while filming.
class_name ScoreBars
extends PanelContainer


var recorder: Recorder = null

var _tip: Label
var _bars: Dictionary[String, ScoreBar] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.05, 0.5)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_tip = HudStyle.make_label("", 22)
	column.add_child(_tip)
	for aspect: String in ShotReport.ASPECTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := HudStyle.make_label(ShotReport.ASPECTS[aspect], 16, HudStyle.DIM)
		name_label.custom_minimum_size.x = 120
		row.add_child(name_label)
		var bar := ScoreBar.new()
		bar.custom_minimum_size = Vector2(160, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		column.add_child(row)
		_bars[aspect] = bar


func _process(_delta: float) -> void:
	if not recorder or not is_visible_in_tree():
		return
	_bars["framing"].value = recorder.last_framing
	_bars["size"].value = recorder.last_size
	_bars["stability"].value = recorder.last_stability
	_bars["visibility"].value = recorder.last_visible
	_tip.text = ShotAdvice.for_recorder(recorder)
	_tip.add_theme_color_override("font_color", HudStyle.score_color(recorder.last_score))


func get_tip() -> String:
	return _tip.text
