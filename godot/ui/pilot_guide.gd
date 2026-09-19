## Step-by-step help while piloting: what to do now (arm, take off, frame, record, land) and
## where to put the throttle stick. The suggestion is drawn on the HUD's own left stick, so
## there is a single stick widget on screen. It lives in the viewfinder's assistance panel,
## which shows the score bars instead while recording.
class_name PilotGuide
extends VBoxContainer


## Suggested throttle stick positions (screen convention: up = -1).
enum Stick {NONE, CENTRE, UP, DOWN}

## Above this height (m) a disarmed drone is not on the ground: it fell or got stuck.
const FALLEN_HEIGHT := 1.0
## Below this height (m) an armed drone is still on the ground.
const GROUND_HEIGHT := 0.4

var drone: Drone = null
var recorder: Recorder = null
var control: ControlState = null
## The HUD's left stick, where the suggested throttle position is shown.
var stick_hint: StickHint = null

var _text: Label
var _battery: Battery = null
var _current := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	add_child(HudStyle.make_label("GUÍA", HudStyle.SIZE_XS, HudStyle.DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	_text = HudStyle.make_label("", HudStyle.SIZE_S)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = HudStyle.COLUMN_W - 24.0
	add_child(_text)


func setup(new_drone: Drone, new_recorder: Recorder, new_control: ControlState,
		new_stick_hint: StickHint = null) -> void:
	drone = new_drone
	recorder = new_recorder
	control = new_control
	stick_hint = new_stick_hint
	_battery = drone.get_node_or_null("Battery") as Battery if drone else null


## What the guide shows for a flight situation. `state` keys: armed, throttle_idle,
## idle_centred, height, pilot_view, recording, battery_low, battery_empty, recovering.
## Returns {"text": String, "stick": Stick}; empty text hides the guide.
static func step_for(state: Dictionary) -> Dictionary:
	var arm := InputHints.button("toggle_arm")
	var idle_stick := Stick.CENTRE if state.get("idle_centred", true) else Stick.DOWN
	var height: float = state.get("height", 0.0)
	var on_ground := height < GROUND_HEIGHT
	if state.get("recording", false):
		return {"text": "", "stick": Stick.NONE}
	if state.get("recovering", false):
		return {"text": "Recuperando el control: esperá a que el dron se nivele", "stick": Stick.NONE}
	if not state.get("armed", false):
		if state.get("battery_empty", false):
			return {"text": "Sin batería: volvé caminando a buscar el dron", "stick": Stick.NONE}
		if height > FALLEN_HEIGHT:
			return {"text": "Dron caído: %s para volver al despegue" % InputHints.button("respawn"),
					"stick": Stick.NONE}
		if state.get("battery_low", false):
			return {"text": "Batería baja: guardá el dron para cambiar la batería", "stick": Stick.NONE}
		if not state.get("throttle_idle", true):
			return {"text": "Acelerador %s y %s para armar" % [
					"al centro" if idle_stick == Stick.CENTRE else "abajo", arm], "stick": idle_stick}
		return {"text": "%s para armar los motores" % arm, "stick": idle_stick}
	if on_ground:
		if state.get("battery_low", false):
			return {"text": "Batería baja: mantené el acelerador abajo para apagar los motores y guardá el dron",
					"stick": Stick.DOWN}
		return {"text": "Subí el acelerador despacio para despegar. Abajo del todo apaga los motores.",
				"stick": Stick.UP}
	if state.get("battery_low", false):
		return {"text": "Batería baja: aterrizá con el acelerador abajo", "stick": Stick.DOWN}
	if state.get("pilot_view", false):
		return {"text": "Cambiá al gimbal %s para encuadrar al auto" % InputHints.button("change_camera"),
				"stick": Stick.NONE}
	return {"text": "Encuadrá el camino y grabá %s cuando pase el auto" % InputHints.button("rec_toggle"),
			"stick": Stick.NONE}


## The situation of the drone, in the keys step_for() reads.
func current_state() -> Dictionary:
	var fc := drone.flight_controller
	var height := fc.flight_state.ground_distance
	return {
		"armed": fc.state_armed,
		"throttle_idle": fc.flight_mode != null and fc.is_throttle_at_idle(),
		"idle_centred": fc.flight_mode != null and fc.flight_mode.idle_power() > 0.0,
		"height": height if is_finite(height) else 99.0,
		"pilot_view": control != null and control.view == ControlState.View.PILOT,
		"recording": recorder != null and recorder.recording,
		"battery_low": _battery != null and _battery.is_low,
		"battery_empty": fc.arming_blocked,
		"recovering": fc.flight_mode is FlightModeRecover,
	}


## Recomputes the step. Returns false when there is nothing to say.
func refresh() -> bool:
	if not drone:
		return false
	_current = step_for(current_state())
	_text.text = _current["text"]
	_show_stick(_current["stick"])
	return not _text.text.is_empty()


## Shows a fixed step (settings preview).
func show_step(text: String) -> void:
	_text.text = text


## Removes the suggestion from the stick (the guide is hidden).
func clear_target() -> void:
	_show_stick(Stick.NONE)


func _show_stick(stick: Stick) -> void:
	if not stick_hint:
		return
	match stick:
		Stick.CENTRE:
			stick_hint.set_target(Vector2.ZERO, true)
		Stick.UP:
			stick_hint.set_target(Vector2(0, -1))
		Stick.DOWN:
			stick_hint.set_target(Vector2(0, 1))
		_:
			stick_hint.set_target(Vector2.ZERO, false)


## The text shown now, for the checks.
func get_text() -> String:
	return _text.text


## The stick suggestion now, for the checks.
func get_stick() -> Stick:
	return _current.get("stick", Stick.NONE)
