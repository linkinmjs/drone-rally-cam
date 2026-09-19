extends Node
## Progress saved between sessions: for each stage, the best grade, runs, clips delivered and
## the clips of the last run; stages unlock with a good enough clip on the previous one
## (StageCatalog). Saved in user://save, never next to the settings in user://config.


signal progress_changed

const DEFAULT_SAVE_PATH := "user://save/progress.tres"

## Redirected by the automated checks and the screenshot tour.
var save_path := DEFAULT_SAVE_PATH
var data := SaveData.new()


func _ready() -> void:
	load_progress()


## Loads the saved progress; a missing or broken file starts from scratch.
func load_progress() -> void:
	data = SaveData.new()
	if not FileAccess.file_exists(save_path):
		return
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if loaded == null:
		push_warning("Progress: could not read %s, starting from scratch" % save_path)
		return
	data = loaded


func save_progress() -> void:
	var _err := DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var err := ResourceSaver.save(data, save_path)
	if err != OK:
		push_error("Progress: could not save %s (%s)" % [save_path, error_string(err)])


## Forgets everything in memory (the checks start from a clean slate).
func reset() -> void:
	data = SaveData.new()
	progress_changed.emit()


func stage_progress(id: StringName) -> StageProgress:
	return data.stages.get(id)


func best_grade(id: StringName) -> String:
	var progress := stage_progress(id)
	return progress.best_grade if progress else ""


func clips_delivered(id: StringName) -> int:
	var progress := stage_progress(id)
	return progress.clips_delivered if progress else 0


func is_unlocked(id: StringName) -> bool:
	var info := StageCatalog.get_default().find(id)
	if info == null:
		return false
	if info.unlock_after == &"":
		return true
	return grade_at_least(best_grade(info.unlock_after), info.unlock_grade)


## The stage "Play" starts: the last unlocked one in championship order.
func current_stage() -> StageInfo:
	var current: StageInfo = null
	for info in StageCatalog.get_default().stages:
		if is_unlocked(info.id):
			current = info
	return current


## Stages with at least one clip delivered.
func completed_count() -> int:
	var count := 0
	for info in StageCatalog.get_default().stages:
		if not best_grade(info.id).is_empty():
			count += 1
	return count


## Best grade over every stage ("" before the first clip).
func overall_best() -> String:
	var best := ""
	for info in StageCatalog.get_default().stages:
		best = better_grade(best, best_grade(info.id))
	return best


static func grade_at_least(grade: String, needed: String) -> bool:
	return not grade.is_empty() and ShotReport.GRADES.find(grade) >= ShotReport.GRADES.find(needed)


static func better_grade(a: String, b: String) -> String:
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	return a if ShotReport.GRADES.find(a) >= ShotReport.GRADES.find(b) else b


## Records a finished run of `id` and saves. Returns {"new_record": bool, "first": bool (the
## first grade on this stage), "best_grade": String, "unlocked": StageInfo or null (stage opened
## by this run), "next": StageInfo or null (the next stage, when it is unlocked)}.
func record_run(id: StringName, clips: Array[ShotReport]) -> Dictionary:
	var catalog := StageCatalog.get_default()
	var unlocked_before := {}
	for info in catalog.stages:
		unlocked_before[info.id] = is_unlocked(info.id)

	var progress := stage_progress(id)
	if progress == null:
		progress = StageProgress.new()
		data.stages[id] = progress
	var run_best := ""
	var run_mean := 0.0
	for clip in clips:
		# GRADES.find("") is -1: any clip beats no clip.
		var rank := ShotReport.GRADES.find(clip.grade)
		var best_rank := ShotReport.GRADES.find(run_best)
		if rank > best_rank or (rank == best_rank and clip.mean_score > run_mean):
			run_best = clip.grade
			run_mean = clip.mean_score
	var new_record := false
	var first := progress.best_grade.is_empty() and not run_best.is_empty()
	if not run_best.is_empty():
		var better := progress.best_grade.is_empty() \
				or ShotReport.GRADES.find(run_best) > ShotReport.GRADES.find(progress.best_grade)
		var same_but_higher := run_best == progress.best_grade and run_mean > progress.best_mean_score
		if better or same_but_higher:
			new_record = true
			progress.best_grade = run_best
			progress.best_mean_score = run_mean
	progress.runs += 1
	progress.clips_delivered += clips.size()
	progress.last_clips = clips.duplicate()
	progress.last_played = Time.get_datetime_string_from_system()

	var unlocked: StageInfo = null
	for info in catalog.stages:
		if not unlocked_before[info.id] and is_unlocked(info.id):
			unlocked = info
	var next := catalog.next_after(id)
	save_progress()
	progress_changed.emit()
	return {
		"new_record": new_record,
		"first": first,
		"best_grade": progress.best_grade,
		"unlocked": unlocked,
		"next": next if next and is_unlocked(next.id) else null,
	}
