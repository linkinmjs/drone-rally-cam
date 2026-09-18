## One short tip for the camera operator from the metrics of the frame being recorded, in
## order of what matters most: the car has to be in the shot and visible, then at a good size,
## then well placed, and the camera has to be still.
class_name ShotAdvice
extends RefCounted


static func tip(fraction: float, cropped: bool, framing: float, size: float, stability: float,
		visible: float) -> String:
	if fraction <= 0.0:
		return "Buscá al auto"
	if visible < 0.5:
		return "Algo tapa al auto"
	if cropped and fraction >= 0.25:
		return "El auto está cortado: alejate"
	if fraction >= 0.25:
		return "Muy cerca: alejate un poco"
	if size < 0.5:
		return "Acercate: el auto se ve chico"
	if cropped:
		return "El auto está cortado: centralo"
	if framing < 0.5:
		return "Centrá el auto o usá los tercios"
	if stability < 0.6:
		return "Quieto: movimientos suaves"
	return "Así, mantené"


## The tip for the recorder's last sampled frame.
static func for_recorder(recorder: Recorder) -> String:
	return tip(recorder.last_fraction, recorder.last_cropped, recorder.last_framing,
			recorder.last_size, recorder.last_stability, recorder.last_visible)
