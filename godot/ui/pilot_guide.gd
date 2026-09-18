## Step-by-step help while piloting: what to do now (arm, take off, frame, record, land) and
## where to put the throttle stick, shown next to the live stick. Hidden while recording (the
## score bars take over) and switchable in Options > Game > HUD.
class_name PilotGuide
extends PanelContainer


## Suggested throttle stick positions (screen convention: up = -1).
enum Stick {NONE, CENTRE, UP, DOWN}

var drone: Drone = null
var recorder: Recorder = null
var control: ControlState = null

var _text: Label
var _stick: StickHint
var _current := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.05, 0.5)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_stick = StickHint.new()
	_stick.custom_minimum_size = Vector2(96, 96)
	row.add_child(_stick)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	column.add_child(HudStyle.make_label("GUÍA", 14, HudStyle.DIM))
	_text = HudStyle.make_label("", 20)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 300
	column.add_child(_text)


func setup(new_drone: Drone, new_recorder: Recorder, new_control: ControlState) -> void:
	drone = new_drone
	recorder = new_recorder
	control = new_control


## What the guide shows for a flight situation. `state` keys: armed, throttle_idle,
## idle_centred, height, pilot_view, recording, battery_low, battery_empty, recovering.
## Returns {"text": String, "stick": Stick}; empty text hides the guide.
static func step_for(state: Dictionary) -> Dictionary:
	var arm := InputHints.button("toggle_arm")
	var idle_stick := Stick.CENTRE if state.get("idle_centred", true) else Stick.DOWN
	if state.get("recording", false):
		return {"text": "", "stick": Stick.NONE}
	if state.get("recovering", false):
		return {"text": "Recuperando el control: esperá a que el dron se nivele", "stick": Stick.NONE}
	if not state.get("armed", false):
		if state.get("battery_empty", false):
			return {"text": "Sin batería: volvé caminando a buscar el dron", "stick": Stick.NONE}
		if not state.get("throttle_idle", true):
			return {"text": "Acelerador %s y %s para armar" % [
					"al centro" if idle_stick == Stick.CENTRE else "abajo", arm], "stick": idle_stick}
		return {"text": "%s para armar los motores" % arm, "stick": idle_stick}
	if state.get("battery_low", false):
		return {"text": "Batería baja: aterrizá con el acelerador abajo", "stick": Stick.DOWN}
	if state.get("height", 0.0) < 0.4:
		return {"text": "Subí el acelerador despacio para despegar. Abajo del todo apaga los motores.",
				"stick": Stick.UP}
	if state.get("pilot_view", false):
		return {"text": "Cambiá al gimbal %s para encuadrar al auto" % InputHints.button("change_camera"),
				"stick": Stick.NONE}
	return {"text": "Encuadrá el camino y grabá %s cuando pase el auto" % InputHints.button("rec_toggle"),
			"stick": Stick.NONE}


## The situation of the drone, in the keys step_for() reads.
func current_state() -> Dictionary:
	var fc := drone.flight_controller
	var battery := drone.get_node("Battery") as Battery
	var height := fc.flight_state.ground_distance
	return {
		"armed": fc.state_armed,
		"throttle_idle": fc.is_throttle_at_idle(),
		"idle_centred": fc.flight_mode != null and fc.flight_mode.idle_power() > 0.0,
		"height": height if is_finite(height) else 99.0,
		"pilot_view": control != null and control.view == ControlState.View.PILOT,
		"recording": recorder != null and recorder.recording,
		"battery_low": battery.is_low,
		"battery_empty": fc.arming_blocked,
		"recovering": fc.flight_mode is FlightModeRecover,
	}


func _process(_delta: float) -> void:
	if not drone or not is_visible_in_tree():
		return
	_current = step_for(current_state())
	_text.text = _current["text"]
	var stick: Stick = _current["stick"]
	_stick.visible = stick != Stick.NONE
	_stick.centre_target = stick == Stick.CENTRE
	var target := Vector2.ZERO
	if stick == Stick.UP:
		target = Vector2(0, -1)
	elif stick == Stick.DOWN:
		target = Vector2(0, 1)
	var input := drone.flight_controller.input
	_stick.set_values(Vector2(input.yaw, -2.0 * (input.power - 0.5)), target)


## The text shown now, for the checks.
func get_text() -> String:
	return _text.text
