## Summary of one recorded clip: per-sample metrics, averages, the longest good streak, a
## grade from C to S and a short comment from the producer.
class_name ShotReport
extends Resource


const GRADES: PackedStringArray = ["C", "B", "A", "S"]
## A clip shorter than this is always graded C.
const MIN_DURATION := 1.5
## Mean frame score needed for each grade (S also needs a good streak of
## ShotScorer.CONTINUITY_SECONDS).
const GRADE_S := 0.85
const GRADE_A := 0.7
const GRADE_B := 0.5
## Aspects scored on every frame, with their names on screen.
const ASPECTS := {
	"framing": "Encuadre",
	"size": "Tamaño",
	"stability": "Estabilidad",
	"visibility": "Visible",
}

@export var duration := 0.0
@export var sample_interval := 0.05
@export var framing: PackedFloat32Array = []
@export var size: PackedFloat32Array = []
@export var stability: PackedFloat32Array = []
@export var visibility: PackedFloat32Array = []
@export var scores: PackedFloat32Array = []

@export var mean_framing := 0.0
@export var mean_size := 0.0
@export var mean_stability := 0.0
@export var mean_visibility := 0.0
@export var mean_score := 0.0
@export var longest_streak := 0.0
@export var grade := "C"
@export var comment := ""
@export var aborted := false


func add_sample(frame_framing: float, frame_size: float, frame_stability: float,
		frame_visibility: float, score: float) -> void:
	framing.append(frame_framing)
	size.append(frame_size)
	stability.append(frame_stability)
	visibility.append(frame_visibility)
	scores.append(score)


func sample_count() -> int:
	return scores.size()


## Computes the averages, grade and comment. Call once, when the clip ends.
func finalize() -> void:
	mean_framing = _mean(framing)
	mean_size = _mean(size)
	mean_stability = _mean(stability)
	mean_visibility = _mean(visibility)
	mean_score = _mean(scores)
	longest_streak = _longest_streak()
	grade = _compute_grade()
	comment = _compute_comment()


func _compute_grade() -> String:
	if aborted or duration < MIN_DURATION:
		return "C"
	if mean_score >= GRADE_S and longest_streak >= ShotScorer.CONTINUITY_SECONDS:
		return "S"
	if mean_score >= GRADE_A:
		return "A"
	if mean_score >= GRADE_B:
		return "B"
	return "C"


func _compute_comment() -> String:
	if aborted:
		return "Perdimos el material: el dron se estrelló."
	if duration < MIN_DURATION:
		return "Demasiado corto, no me sirve."
	var on_screen := 0
	for value in size:
		if value > 0.0:
			on_screen += 1
	if on_screen < sample_count() * 0.3:
		return "El auto casi no aparece en cuadro."
	if mean_visibility < 0.6:
		return "Algo tapa al auto buena parte de la toma."
	# The weakest aspect decides the comment.
	var weakest := "none"
	var lowest := 0.75
	for aspect: Array in [["framing", mean_framing], ["size", mean_size], ["stability", mean_stability]]:
		if aspect[1] < lowest:
			lowest = aspect[1]
			weakest = aspect[0]
	match weakest:
		"framing":
			return "El encuadre se va: centrá el auto o usá los tercios."
		"size":
			return "El auto queda muy chico o cortado en cuadro."
		"stability":
			return "La imagen se mueve demasiado."
	if grade == "S":
		return "¡Toma de portada! Limpia, estable y bien encuadrada."
	return "Buena toma, sólida."


## Average of one aspect ("framing", "size", "stability" or "visibility").
func aspect_mean(aspect: String) -> float:
	match aspect:
		"framing":
			return mean_framing
		"size":
			return mean_size
		"stability":
			return mean_stability
		"visibility":
			return mean_visibility
	return 0.0


## Why an aspect got its average, in a few words.
func aspect_reason(aspect: String) -> String:
	var value := aspect_mean(aspect)
	match aspect:
		"framing":
			if value >= 0.75:
				return "centrado o en los tercios"
			if value >= 0.5:
				return "a veces se va del centro"
			return "lejos del centro y de los tercios"
		"size":
			if value >= 0.75:
				return "buen tamaño en cuadro"
			if _fraction_off_screen() > 0.4:
				return "fuera de cuadro buena parte"
			return "muy chico, muy grande o cortado"
		"stability":
			if value >= 0.75:
				return "imagen quieta"
			if value >= 0.5:
				return "algunos movimientos bruscos"
			return "la cámara se mueve mucho"
		"visibility":
			if value >= 0.9:
				return "siempre a la vista"
			if value >= 0.6:
				return "a veces tapado"
			return "tapado o fuera de cuadro"
	return ""


func _fraction_off_screen() -> float:
	if size.is_empty():
		return 1.0
	var off := 0
	for value in size:
		if value <= 0.0:
			off += 1
	return float(off) / size.size()


func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()


func _longest_streak() -> float:
	var best := 0
	var current := 0
	for score in scores:
		if score >= ShotScorer.GOOD_SCORE:
			current += 1
			best = maxi(best, current)
		else:
			current = 0
	return best * sample_interval
