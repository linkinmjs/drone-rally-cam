## The rally radio under the stage status: announces the car's start and splits, counts down
## until it reaches the player's spot (with beeps at 10 and 5 seconds), and says when it
## passed and when it finished. It lives in the on-foot overlay and keeps running while it is
## hidden; the viewfinder draws the same lines while piloting (message_text, countdown_text).
class_name RadioFeed
extends VBoxContainer


## A message was read on the radio (used by the checks).
signal announced(text: String)

## Distance between split announcements, in meters.
@export var split_meters := 300.0
## The countdown to the player's spot shows from this many seconds.
@export var countdown_from := 90.0
@export var message_seconds := 4.0

var stage: Stage = null

var _message: Label
var _countdown: Label
var _message_time := 0.0
var _started := false
var _finished := false
var _last_split := 0
var _was_passed := true
var _last_eta := INF


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_message = HudStyle.make_label("", HudStyle.SIZE_M, HudStyle.AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_message)
	_countdown = HudStyle.make_label("", HudStyle.SIZE_M, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_countdown)


func setup(new_stage: Stage) -> void:
	stage = new_stage


## The last announcement while it is on air, empty otherwise.
func message_text() -> String:
	return _message.text if _message_time > 0.0 else ""


## Opacity of the announcement (it fades out during its last second).
func message_alpha() -> float:
	return clampf(_message_time, 0.0, 1.0)


## "Llega a tu punto en 0:12" while the car is on its way, empty otherwise.
func countdown_text() -> String:
	return _countdown.text if _countdown.visible else ""


func countdown_color() -> Color:
	return _countdown.get_theme_color("font_color")


func announce(text: String) -> void:
	_message.text = "RADIO · %s" % text
	_message_time = message_seconds
	announced.emit(text)


func _process(delta: float) -> void:
	_message_time -= delta
	_message.visible = _message_time > 0.0
	_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	if not stage:
		return
	var car := stage.world.car
	if car.running and not _started:
		_started = true
		announce("¡Largó el %s!" % car.driver_name)
	if car.running:
		var split := floori(car.distance / split_meters)
		if split > _last_split:
			_last_split = split
			announce("%s · km %s · %s" % [car.driver_name, HudStyle.decimal(car.distance / 1000.0),
					HudStyle.format_time(stage.race_time)])
	if car.has_finished and not _finished:
		_finished = true
		announce("%s llegó a meta" % car.driver_name)
	_update_countdown(car)


func _update_countdown(car: RallyCar) -> void:
	var spot := stage.reference_route_offset()
	var eta := stage.seconds_until_car_at(spot)
	var passed := car.distance >= spot and (car.running or car.has_finished)
	if passed and not _was_passed:
		announce("El %s pasó por tu punto" % car.driver_name)
	_was_passed = passed
	if eta > 0.0 and eta <= countdown_from:
		_countdown.text = "Llega a tu punto en %s" % HudStyle.format_time(ceilf(eta))
		HudStyle.set_color(_countdown, HudStyle.AMBER if eta <= 10.0 else HudStyle.WHITE)
		_countdown.visible = true
		for beep: float in [10.0, 5.0]:
			if eta <= beep and _last_eta > beep and car.running:
				UI.play("tick")
	else:
		_countdown.visible = false
	_last_eta = eta
