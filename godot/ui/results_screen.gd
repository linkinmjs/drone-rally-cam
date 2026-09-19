## End of the stage: every clip delivered with its grade, length and the producer's comment,
## the best grade, and buttons to restart the stage or quit. Shown over the paused game.
class_name ResultsScreen
extends MenuScreen


signal restart_requested

@onready var title := %Title as Label
@onready var subtitle := %Subtitle as Label
@onready var clip_list := %ClipList as VBoxContainer
@onready var button_restart := %ButtonRestart as Button
@onready var button_quit := %ButtonQuit as Button


func _ready() -> void:
	backdrop = Backdrop.SCRIM
	allow_back = false
	initial_focus = button_restart
	super()
	var _discard := button_restart.pressed.connect(restart_requested.emit)
	_discard = button_quit.pressed.connect(_on_quit_pressed)


## Fills the screen for `clips` of the stage run by `car_name`.
func show_results(car_name: String, clips: Array[ShotReport]) -> void:
	title.text = "Etapa terminada"
	var best := best_grade(clips)
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
	row.add_theme_constant_override("separation", 18)
	var grade := Label.new()
	grade.text = clip.grade
	grade.theme_type_variation = &"DisplayLabel"
	grade.custom_minimum_size.x = 64
	grade.add_theme_color_override("font_color", _grade_color(clip.grade))
	row.add_child(grade)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var header := Label.new()
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


static func _grade_color(grade: String) -> Color:
	# Darker than the HUD colours: the menu backdrop is light.
	match grade:
		"S":
			return Color(0.72, 0.52, 0.0)
		"A":
			return Color(0.1, 0.52, 0.25)
		"B":
			return Color(0.72, 0.42, 0.0)
	return Color(0.72, 0.16, 0.1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_stage"):
		accept_event()
		restart_requested.emit()


func _on_quit_pressed() -> void:
	var confirmed: bool = await UI.confirm("MENU_QUIT_CONFIRM", "MENU_QUIT", "UI_CANCEL", true)
	if confirmed:
		get_tree().quit()
