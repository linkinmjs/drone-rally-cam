## What the player achieved on one stage: best grade and mean score, runs, clips delivered and
## the clips of the last run. Saved inside SaveData.
class_name StageProgress
extends Resource


@export var best_grade := ""
@export var best_mean_score := 0.0
@export var runs := 0
@export var clips_delivered := 0
@export var last_clips: Array[ShotReport] = []
## Date and time of the last run, ISO 8601.
@export var last_played := ""
