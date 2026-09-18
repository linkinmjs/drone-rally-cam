## Producer's verdict on the last clip: grade, one bar per aspect with its value and why, a
## short comment and how grades are given. Shows up at the side of the screen and fades out
## on its own.
class_name ClipSummary
extends PanelContainer


@export var display_seconds := 14.0

var _grade: Label
var _duration: Label
var _average: Label
var _comment: Label
var _rules: Label
var _bars: Dictionary[String, ScoreBar] = {}
var _values: Dictionary[String, Label] = {}
var _reasons: Dictionary[String, Label] = {}
var _time_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.85)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(440, 0)
	HudStyle.anchor(self, Control.PRESET_CENTER_RIGHT, 40.0)
	# Below the viewfinder's readouts (height, speed, distance, gimbal).
	offset_top += 90.0
	offset_bottom += 90.0

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.add_child(HudStyle.make_label("TOMA ENTREGADA", 18, HudStyle.DIM))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	column.add_child(header)
	_grade = HudStyle.make_label("A", 72)
	header.add_child(_grade)
	var numbers := VBoxContainer.new()
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(numbers)
	_duration = HudStyle.make_label("", 20)
	numbers.add_child(_duration)
	_average = HudStyle.make_label("", 18, HudStyle.DIM)
	numbers.add_child(_average)
	for aspect: String in ShotReport.ASPECTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := HudStyle.make_label(ShotReport.ASPECTS[aspect], 18)
		name_label.custom_minimum_size.x = 130
		row.add_child(name_label)
		var bar := ScoreBar.new()
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var value := HudStyle.make_label("", 18, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		value.custom_minimum_size.x = 64
		row.add_child(value)
		column.add_child(row)
		var reason := HudStyle.make_label("", 16, HudStyle.DIM)
		column.add_child(reason)
		_bars[aspect] = bar
		_values[aspect] = value
		_reasons[aspect] = reason
	_comment = HudStyle.make_label("", 18)
	_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comment.custom_minimum_size.x = 400
	column.add_child(_comment)
	_rules = HudStyle.make_label(rules_text(), 14, HudStyle.DIM)
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.custom_minimum_size.x = 400
	column.add_child(_rules)
	hide()


## How grades are given, from the same thresholds the report uses.
static func rules_text() -> String:
	return "S: promedio ≥ %d %% y %d s seguidos buenos · A: ≥ %d %% · B: ≥ %d %% · mínimo %.1f s" % [
			roundi(ShotReport.GRADE_S * 100.0), roundi(ShotScorer.CONTINUITY_SECONDS),
			roundi(ShotReport.GRADE_A * 100.0), roundi(ShotReport.GRADE_B * 100.0),
			ShotReport.MIN_DURATION]


func show_report(report: ShotReport) -> void:
	_grade.text = report.grade
	_grade.add_theme_color_override("font_color", grade_color(report.grade))
	_duration.text = "Duración %s" % HudStyle.format_time(report.duration)
	_average.text = "promedio %d %% · racha %.1f s" % [roundi(report.mean_score * 100.0),
			report.longest_streak]
	for aspect: String in ShotReport.ASPECTS:
		var value := report.aspect_mean(aspect)
		_bars[aspect].value = value
		_values[aspect].text = "%d %%" % [roundi(value * 100.0)]
		_reasons[aspect].text = "   %s" % report.aspect_reason(aspect)
	_comment.text = "“%s”" % report.comment
	_time_left = display_seconds
	modulate.a = 1.0
	show()


## Text of the aspect rows, for the checks: "Encuadre 80 % centrado o en los tercios".
func aspect_line(aspect: String) -> String:
	return "%s %s %s" % [ShotReport.ASPECTS[aspect], _values[aspect].text, _reasons[aspect].text.strip_edges()]


func _process(delta: float) -> void:
	if not visible:
		return
	_time_left -= delta
	modulate.a = clampf(_time_left, 0.0, 1.0)
	if _time_left <= 0.0:
		hide()


static func grade_color(grade: String) -> Color:
	match grade:
		"S":
			return Color(1.0, 0.82, 0.25)
		"A":
			return HudStyle.GREEN
		"B":
			return HudStyle.AMBER
	return HudStyle.RED
