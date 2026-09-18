## One stage of the rally: the player arrives on foot, the car starts after a countdown,
## the player films it from the drone and the stage ends when the car reaches the finish.
class_name Stage
extends Node3D


enum Phase {WAITING_START, RACING, FINISHED}

const PACKED_PAUSE_MENU := preload("res://gui/pause_menu.tscn")
const PACKED_RESULTS := preload("res://ui/results_screen.tscn")
## Seconds between the car's finish (and the end of a clip being recorded) and the results.
const RESULTS_DELAY := 4.0
## Longest wait for the buttons and sticks to be released when leaving the pause menu.
const RESUME_RELEASE_TIMEOUT_MSEC := 500
## Within this distance of the road the player is "close to the road" for the checklist.
const NEAR_ROAD := 40.0
const CHECKLIST: Array[String] = [
	"Elegí un lugar cerca del camino",
	"Desplegá el dron {interact}",
	"Tomá el control {pilot_toggle} y armá {toggle_arm}",
	"Despegá y grabá el paso del auto {rec_toggle}",
	"Aterrizá y guardá el dron {interact}",
]

@export var stage_name := "Etapa 1"
## Seconds between arriving and the car's start. Waiting and positioning is part of the game.
@export var start_delay := 45.0

var phase := Phase.WAITING_START
var clips: Array[ShotReport] = []
var _countdown := 0.0
var _race_time := 0.0
var _motors_bus := -1
var pause_menu: PauseMenu = null
var results: ResultsScreen = null
var _results_delay := -1.0
## Seconds since the car started.
var race_time: float:
	get:
		return _race_time
var _route_offset := 0.0
var _road_distance := INF
var _route_timer := 0.0

@onready var world := $World as StageWorld
@onready var player := $Player as Player
@onready var drone := $RallyDrone as Drone
@onready var control := $ControlState as ControlState
@onready var recorder := $Recorder as Recorder
@onready var visor := $UI/DroneVisor as DroneVisor
@onready var hud := $UI/StageHud as StageHud
@onready var summary := $UI/ClipSummary as ClipSummary
@onready var menus := $Menus as CanvasLayer
@onready var tablet := $UI/Tablet as Tablet


func _ready() -> void:
	var controls_error := Controls.load_input_map(true)
	if not controls_error.is_empty():
		push_warning(controls_error)
	_motors_bus = AudioServer.get_bus_index(&"Motors")

	player.global_transform = world.get_player_spawn_transform()
	drone.stow()
	recorder.setup(drone, world.car)
	visor.setup(drone, recorder, player, control)
	visor.set_car(world.car)
	hud.radio_feed.setup(self)
	hud.drone_marker.target = drone
	tablet.setup(self)

	var _discard := control.state_changed.connect(_on_control_state_changed)
	_discard = control.action_refused.connect(hud.show_notice)
	_discard = recorder.recording_stopped.connect(_on_recording_stopped)
	_discard = recorder.recording_aborted.connect(hud.show_notice)
	_discard = world.car.finished.connect(_on_car_finished)
	_discard = EventBus.battery_depleted.connect(hud.show_notice.bind("El dron se quedó sin batería."))

	_countdown = start_delay
	_on_control_state_changed(control.state)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_route_offset()
	tablet.open(briefing(), 10.0)


## Three lines for the start: the car, the stage and what to do.
func briefing() -> String:
	var car := world.car
	return ("Sos el camarógrafo aéreo del rally. El %s larga en %s y cruza los %.1f km del tramo "
			+ "en unos %s.\n"
			+ "Elegí un lugar cerca del camino, desplegá el dron %s, tomá el control %s y grabá "
			+ "su paso con el gimbal %s.\n"
			+ "El punto naranja del mapa es donde el auto pasa más cerca tuyo. Abrí el mapa con %s.") % [
			car.driver_name, HudStyle.format_time(start_delay), car.get_route_length() / 1000.0,
			HudStyle.format_time(car.expected_time_at(car.get_route_length())),
			InputHints.button("interact"), InputHints.button("pilot_toggle"),
			InputHints.button("rec_toggle"), InputHints.button("show_map")]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("pause_menu") and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		open_pause_menu()
	elif phase == Phase.FINISHED and event.is_action_pressed("restart_stage"):
		get_viewport().set_input_as_handled()
		restart()
	elif event.is_action_pressed("show_map") and control.state != ControlState.State.PILOTING:
		get_viewport().set_input_as_handled()
		tablet.toggle()


func open_pause_menu() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	pause_menu = PACKED_PAUSE_MENU.instantiate() as PauseMenu
	menus.add_child(pause_menu)
	var _discard := pause_menu.resumed.connect(_on_pause_resumed)
	_discard = pause_menu.restart_requested.connect(restart)
	UI.show_mouse()


## Pauses the game and lists the clips of the stage.
func show_results() -> void:
	if results:
		return
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
	get_tree().paused = true
	results = PACKED_RESULTS.instantiate() as ResultsScreen
	menus.add_child(results)
	results.show_results(world.car.driver_name, clips)
	var _discard := results.restart_requested.connect(restart)
	UI.show_mouse()


func restart() -> void:
	get_tree().paused = false
	var _err := get_tree().reload_current_scene()


## Adapted from drone-simulator's Level._on_resume: the button or stick gesture used to
## resume must not reach the drone (✕ also cycles the flight mode), so the game stays paused
## until everything is released, but never longer than RESUME_RELEASE_TIMEOUT_MSEC: a stick
## that does not come back to the center must not leave the game paused without a menu.
func _on_pause_resumed() -> void:
	if not pause_menu or not pause_menu.can_resume:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.queue_free()
	pause_menu = null
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + RESUME_RELEASE_TIMEOUT_MSEC
	while is_inside_tree() and _resume_input_held() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if is_inside_tree():
		get_tree().paused = false


func _resume_input_held() -> bool:
	return Input.is_action_pressed(&"ui_accept") or Input.is_action_pressed(&"ui_cancel") \
			or Input.is_action_pressed(&"pause_menu") or StickNavigation.any_axis_deflected()


func _process(delta: float) -> void:
	var car := world.car
	match phase:
		Phase.WAITING_START:
			_countdown -= delta
			hud.set_status("%s larga en %s" % [car.driver_name, HudStyle.format_time(ceilf(_countdown))])
			if _countdown <= 0.0:
				phase = Phase.RACING
				car.start()
		Phase.RACING:
			_race_time += delta
			hud.set_status("%s en carrera · %s" % [car.driver_name, HudStyle.format_time(_race_time)])
		Phase.FINISHED:
			hud.set_status(_final_status())
			# Results once the clip being recorded (if any) is delivered.
			if not results and _results_delay >= 0.0 and not recorder.recording:
				_results_delay -= delta
				if _results_delay < 0.0:
					show_results()

	_route_timer -= delta
	if _route_timer <= 0.0:
		_update_route_offset()
	hud.set_checklist(checklist_lines(), checklist_step())
	hud.set_checklist_visible(control.state != ControlState.State.PILOTING and not tablet.is_open)
	_update_drone_marker()

	var walking := control.state != ControlState.State.PILOTING
	var prompt := ""
	if walking:
		var action := player.get_prompt()
		if not action.is_empty():
			prompt = "%s %s" % [InputHints.button("interact"), action]
		if control.state == ControlState.State.WALKING_DRONE_DEPLOYED:
			prompt += ("    " if not prompt.is_empty() else "") \
					+ "%s Tomar el control" % InputHints.button("pilot_toggle")
	hud.set_prompt(prompt)
	_update_motor_volume()


## Motor sound fades with the distance to whoever is listening, like the real thing. While
## piloting it never drops below a floor: the pilot needs to hear the motors. The volume
## slider in Options scales the result.
func _update_motor_volume() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or _motors_bus < 0:
		return
	var distance := camera.global_position.distance_to(drone.global_position)
	var volume := linear_to_db(2.0 / maxf(distance, 2.0))
	if control.state == ControlState.State.PILOTING:
		volume = maxf(volume, -14.0)
	var slider := clampf(float(Audio.audio_settings["motors_volume"]), 0.0, 1.0)
	AudioServer.set_bus_volume_db(_motors_bus, maxf(volume + linear_to_db(slider), -80.0))


## Where the player films from: the drone once it is out, the player otherwise.
func reference_point() -> Vector3:
	if control.state == ControlState.State.WALKING_NO_DRONE:
		return player.global_position
	return drone.global_position


## Distance along the road of the point closest to `point`, in the car's units.
func route_offset_at(point: Vector3) -> float:
	var builder := world.builder
	return builder.driving_curve.get_closest_offset(builder.to_local(point))


## Road distance of the spot closest to the player or the drone (refreshed 4 times a second).
func reference_route_offset() -> float:
	return _route_offset


## Horizontal distance from the player or the drone to the road centre line.
func reference_road_distance() -> float:
	return _road_distance


## Horizontal distance from `point` to the road centre line.
func road_distance_at(point: Vector3) -> float:
	var builder := world.builder
	var local := builder.to_local(point)
	var closest := builder.driving_curve.get_closest_point(local)
	return Vector2(local.x - closest.x, local.z - closest.z).length()


func _update_route_offset() -> void:
	var point := reference_point()
	_route_offset = route_offset_at(point)
	_road_distance = road_distance_at(point)
	_route_timer = 0.25


## Seconds until the car gets to `route_offset`: counting the wait before the start, and
## negative once it went past.
func seconds_until_car_at(route_offset: float) -> float:
	var car := world.car
	match phase:
		Phase.WAITING_START:
			return _countdown + car.expected_time_at(route_offset)
		Phase.RACING:
			if car.distance >= route_offset:
				return -1.0
			return car.expected_time_at(route_offset) - car.expected_time_at(car.distance)
	return -1.0


## Rows of the tablet's timetable: [title, value].
func timetable() -> Array[PackedStringArray]:
	var car := world.car
	var rows: Array[PackedStringArray] = []
	var start := "en %s" % HudStyle.format_time(ceilf(_countdown)) if phase == Phase.WAITING_START \
			else "largó"
	rows.append(PackedStringArray(["LARGADA · %s" % car.driver_name, start]))
	var eta := seconds_until_car_at(_route_offset)
	rows.append(PackedStringArray(["TU PUNTO DEL CAMINO · km %.1f" % [_route_offset / 1000.0],
			"llega en %s" % HudStyle.format_time(ceilf(eta)) if eta > 0.0 else "ya pasó"]))
	rows.append(PackedStringArray(["DISTANCIA AL CAMINO", "%d m" % [roundi(_road_distance)]]))
	var length := car.get_route_length()
	var finish_eta := seconds_until_car_at(length)
	rows.append(PackedStringArray(["META · km %.1f" % [length / 1000.0],
			"llegó" if car.has_finished else "llega en %s" % HudStyle.format_time(ceilf(finish_eta))]))
	rows.append(PackedStringArray(["TOMAS", "%d" % clips.size()]))
	return rows


## Index of the current step of the checklist (CHECKLIST.size() when everything is done).
func checklist_step() -> int:
	var fc := drone.flight_controller
	if control.state == ControlState.State.WALKING_NO_DRONE:
		if not clips.is_empty():
			return CHECKLIST.size()
		return 1 if _road_distance <= NEAR_ROAD else 0
	if clips.is_empty():
		return 3 if fc.state_armed else 2
	return 4


func checklist_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for step in CHECKLIST:
		lines.append(step.format({
			"interact": InputHints.button("interact"),
			"pilot_toggle": InputHints.button("pilot_toggle"),
			"toggle_arm": InputHints.button("toggle_arm"),
			"rec_toggle": InputHints.button("rec_toggle"),
		}))
	return lines


func _update_drone_marker() -> void:
	var marker := hud.drone_marker
	marker.visible = control.state == ControlState.State.WALKING_DRONE_DEPLOYED
	if not marker.visible:
		return
	var distance := player.global_position.distance_to(drone.global_position)
	marker.text = "Dron · al alcance" if distance <= control.recover_distance \
			else "Dron · %d m" % [roundi(distance)]


func _on_control_state_changed(state: ControlState.State) -> void:
	var piloting := state == ControlState.State.PILOTING
	visor.visible = piloting
	hud.set_crosshair_visible(not piloting)
	if piloting:
		tablet.close()
	_update_route_offset()
	if state == ControlState.State.WALKING_DRONE_DEPLOYED and clips.is_empty() and not piloting:
		hud.show_notice("Dron listo. %s para tomar el control." % InputHints.button("pilot_toggle"))


func _on_recording_stopped(report: ShotReport) -> void:
	clips.append(report)
	summary.show_report(report)


func _on_car_finished() -> void:
	phase = Phase.FINISHED
	_results_delay = RESULTS_DELAY


func _final_status() -> String:
	var best := ""
	for clip in clips:
		if best.is_empty() or ShotReport.GRADES.find(clip.grade) > ShotReport.GRADES.find(best):
			best = clip.grade
	var result := "Etapa terminada · %d toma%s" % [clips.size(), "" if clips.size() == 1 else "s"]
	if not best.is_empty():
		result += " · mejor: %s" % best
	return result + " · %s reiniciar" % InputHints.button("restart_stage")
