## Live scoring while recording: one bar per aspect of the shot and a tip on what to fix,
## so the player learns what the producer wants while filming. It lives in the viewfinder's
## assistance panel, in place of the pilot guide. The score always comes from the gimbal
## camera (the one that records), so the title says so in the pilot view.
class_name ScoreBars
extends VBoxContainer


## Width the tip may take: the assistance panel's column minus its margins. A longer tip uses
## the smaller text size instead of widening the panel.
const TIP_WIDTH := HudStyle.COLUMN_W - 24.0

var recorder: Recorder = null

var _title: Label
var _tip: Label
var _bars: Dictionary[String, ScoreBar] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_title = HudStyle.make_label("PUNTAJE", HudStyle.SIZE_XS, HudStyle.DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	add_child(_title)
	_tip = HudStyle.make_label("", HudStyle.SIZE_M)
	add_child(_tip)
	for aspect: String in ShotReport.ASPECTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := HudStyle.make_label(ShotReport.ASPECTS[aspect], HudStyle.SIZE_XS, HudStyle.DIM)
		name_label.custom_minimum_size.x = 120
		row.add_child(name_label)
		var bar := ScoreBar.new()
		bar.custom_minimum_size = Vector2(200, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		add_child(row)
		_bars[aspect] = bar


## In the pilot view the bars still measure the gimbal image, which is not on screen.
func set_pilot_view(pilot: bool) -> void:
	_title.text = "PUNTAJE (GIMBAL)" if pilot else "PUNTAJE"


func _process(_delta: float) -> void:
	if not recorder or not is_visible_in_tree():
		return
	_bars["framing"].value = recorder.last_framing
	_bars["size"].value = recorder.last_size
	_bars["stability"].value = recorder.last_stability
	_bars["visibility"].value = recorder.last_visible
	var tip := ShotAdvice.for_recorder(recorder)
	if _tip.text != tip:
		_set_tip(tip)
	HudStyle.set_color(_tip, HudStyle.score_color(recorder.last_score))


## Sample values for the preview of the HUD settings (there is no recorder there).
func show_preview() -> void:
	var samples := {"framing": 0.82, "size": 0.9, "stability": 0.7, "visibility": 1.0}
	for aspect: String in samples:
		_bars[aspect].value = samples[aspect]
	_set_tip("Así, mantené")
	HudStyle.set_color(_tip, HudStyle.score_color(0.85))


func _set_tip(tip: String) -> void:
	_tip.text = tip
	var font_size := HudStyle.SIZE_M
	if HudStyle.mono_font().get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > TIP_WIDTH:
		font_size = HudStyle.SIZE_S
	if _tip.get_theme_font_size("font_size") != font_size:
		_tip.add_theme_font_size_override("font_size", font_size)
		_tip.add_theme_constant_override("outline_size", HudStyle.outline_size(font_size))


func get_tip() -> String:
	return _tip.text


func get_title() -> String:
	return _title.text
