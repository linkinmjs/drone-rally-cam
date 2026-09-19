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
	add_theme_stylebox_override("panel", HudStyle.panel(0.8, 8, 18))
	custom_minimum_size = Vector2(HudStyle.COLUMN_W, 0)
	# In the right column of the viewfinder, below the battery and the readouts; it grows
	# downwards, so a longer comment never covers them.
	HudStyle.anchor(self, Control.PRESET_TOP_RIGHT)
	offset_top += HudStyle.SUMMARY_TOP - HudStyle.MARGIN
	offset_bottom += HudStyle.SUMMARY_TOP - HudStyle.MARGIN

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.add_child(HudStyle.make_label("TOMA ENTREGADA", HudStyle.SIZE_XS, HudStyle.DIM,
			HORIZONTAL_ALIGNMENT_LEFT, true))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	column.add_child(header)
	_grade = HudStyle.make_label("A", HudStyle.SIZE_DISPLAY, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	header.add_child(_grade)
	var numbers := VBoxContainer.new()
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(numbers)
	_duration = HudStyle.make_label("", HudStyle.SIZE_M)
	numbers.add_child(_duration)
	_average = HudStyle.make_label("", HudStyle.SIZE_S, HudStyle.DIM)
	numbers.add_child(_average)
	for aspect: String in ShotReport.ASPECTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := HudStyle.make_label(ShotReport.ASPECTS[aspect], HudStyle.SIZE_S)
		name_label.custom_minimum_size.x = 130
		row.add_child(name_label)
		var bar := ScoreBar.new()
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var value := HudStyle.make_label("", HudStyle.SIZE_S, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		value.custom_minimum_size.x = 64
		row.add_child(value)
		column.add_child(row)
		var reason := HudStyle.make_label("", HudStyle.SIZE_XS, HudStyle.DIM)
		column.add_child(reason)
		_bars[aspect] = bar
		_values[aspect] = value
		_reasons[aspect] = reason
	_comment = HudStyle.make_label("", HudStyle.SIZE_S)
	_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comment.custom_minimum_size.x = 400
	column.add_child(_comment)
	_rules = HudStyle.make_label(rules_text(), HudStyle.SIZE_XS, HudStyle.DIM)
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.custom_minimum_size.x = 400
	column.add_child(_rules)
	hide()


## How grades are given, from the same thresholds the report uses.
static func rules_text() -> String:
	return "S: promedio ≥ %d %% y %d s seguidos buenos · A: ≥ %d %% · B: ≥ %d %% · mínimo %s s" % [
			roundi(ShotReport.GRADE_S * 100.0), roundi(ShotScorer.CONTINUITY_SECONDS),
			roundi(ShotReport.GRADE_A * 100.0), roundi(ShotReport.GRADE_B * 100.0),
			HudStyle.decimal(ShotReport.MIN_DURATION)]


func show_report(report: ShotReport) -> void:
	_grade.text = report.grade
	_grade.add_theme_color_override("font_color", grade_color(report.grade))
	_duration.text = "Duración %s" % HudStyle.format_duration(report.duration)
	_average.text = "promedio %d %% · racha %s" % [roundi(report.mean_score * 100.0),
			HudStyle.format_duration(report.longest_streak)]
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
