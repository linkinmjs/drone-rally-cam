## End of the stage: every clip delivered with its grade, length and the producer's comment,
## the best grade, a new record and the stage it unlocked, and buttons for the next stage,
## again or the main menu. Shown over the paused game.
class_name ResultsScreen
extends MenuScreen


signal restart_requested
signal next_requested(info: StageInfo)
signal menu_requested

var _next: StageInfo = null

@onready var title := %Title as Label
@onready var subtitle := %Subtitle as Label
@onready var best_label := %Best as Label
@onready var record_label := %Record as Label
@onready var unlocked_label := %Unlocked as Label
@onready var clip_list := %ClipList as VBoxContainer
@onready var button_next := %ButtonNext as Button
@onready var button_restart := %ButtonRestart as Button
@onready var button_menu := %ButtonMenu as Button


func _ready() -> void:
	backdrop = Backdrop.SCRIM
	allow_back = false
	initial_focus = button_restart
	super()
	var _discard := button_restart.pressed.connect(restart_requested.emit)
	_discard = button_next.pressed.connect(func() -> void: next_requested.emit(_next))
	_discard = button_menu.pressed.connect(menu_requested.emit)
	button_next.visible = false
	record_label.visible = false
	unlocked_label.visible = false


## Fills the screen for `clips` of the stage run by `car_name`. `run` is what
## Progress.record_run() returned: a new record, a stage unlocked, the next stage.
func show_results(car_name: String, clips: Array[ShotReport], run := {}) -> void:
	title.text = "Etapa terminada"
	var best := best_grade(clips)
	best_label.text = best if not best.is_empty() else "—"
	best_label.add_theme_color_override(&"font_color",
			UIPalette.grade_color(best) if not best.is_empty() else UIPalette.TEXT_DISABLED)
	record_label.visible = bool(run.get("new_record", false))
	record_label.text = "RESULTS_FIRST" if run.get("first", false) else "RESULTS_RECORD"
	var unlocked: StageInfo = run.get("unlocked")
	unlocked_label.visible = unlocked != null
	if unlocked:
		unlocked_label.text = tr("RESULTS_UNLOCKED") % unlocked.title()
	_next = run.get("next")
	button_next.visible = _next != null
	if _next:
		button_next.text = tr("RESULTS_NEXT") % _next.number
	initial_focus = button_next if _next else button_restart
	var parts := PackedStringArray(["El %s llegó a meta" % car_name,
			"%d toma%s" % [clips.size(), "" if clips.size() == 1 else "s"]])
	if not best.is_empty():
		parts.append("mejor nota: %s" % best)
	subtitle.text = " · ".join(parts)
	for child in clip_list.get_children():
		child.queue_free()
	if clips.is_empty():
		var empty := Label.new()
		empty.text = "No entregaste ninguna toma. Grabá el paso del auto con el gimbal la próxima vez."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clip_list.add_child(empty)
		return
	for i in clips.size():
		clip_list.add_child(_clip_row(i + 1, clips[i]))


static func best_grade(clips: Array[ShotReport]) -> String:
	var best := ""
	for clip in clips:
		if best.is_empty() or ShotReport.GRADES.find(clip.grade) > ShotReport.GRADES.find(best):
			best = clip.grade
	return best


func clip_count() -> int:
	var count := 0
	for child in clip_list.get_children():
		if child is HBoxContainer and not child.is_queued_for_deletion():
			count += 1
	return count


func _clip_row(number: int, clip: ShotReport) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var grade := Label.new()
	grade.text = clip.grade
	grade.theme_type_variation = &"GradeLabel"
	grade.add_theme_font_size_override("font_size", 56)
	grade.custom_minimum_size.x = 56
	grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade.add_theme_color_override("font_color", UIPalette.grade_color(clip.grade))
	row.add_child(grade)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	var header := Label.new()
	header.theme_type_variation = &"ValueLabel"
	header.text = "Toma %d · %s · promedio %d %% · racha %s" % [number,
			HudStyle.format_duration(clip.duration), roundi(clip.mean_score * 100.0),
			HudStyle.format_duration(clip.longest_streak)]
	column.add_child(header)
	var comment := Label.new()
	comment.text = "“%s”" % clip.comment
	comment.theme_type_variation = &"CaptionLabel"
	comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(comment)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_stage"):
		accept_event()
		restart_requested.emit()

