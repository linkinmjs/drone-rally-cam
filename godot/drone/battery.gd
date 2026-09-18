## LiPo battery drained by the thrust the simulation actually produces: hovering costs little,
## climbing and fast flight cost a lot. Warns at 20 %, limits the motors and cuts them at 0 %.
class_name Battery
extends Node


signal changed(fraction: float, seconds_left: float)
signal low
signal depleted

const CELL_VOLTAGE_FULL := 4.2
const CELL_VOLTAGE_EMPTY := 3.5
const AIR_DENSITY := 1.225

## Tuned for gameplay, not realism: about three minutes of hover.
@export_range(50, 10000) var capacity_mah := 350.0
@export_range(1, 6) var cells := 4
## Propeller figure of merit times motor and ESC efficiency: electrical power to ideal
## induced power ratio.
@export_range(0.1, 1.0) var efficiency := 0.5
## Electronics, camera and video link, in watts.
@export var base_draw_w := 8.0
@export_range(0.0, 1.0) var low_fraction := 0.2
## Motor PWM ceiling while the battery is low ("respuesta reducida").
@export_range(0.5, 1.0) var low_power_limit := 0.85
@export var infinite := false

var charge_mah := 0.0
var voltage := 0.0
var current_a := 0.0
var power_w := 0.0
var is_low := false
var is_depleted := false

var _drone: Drone = null
var _average_current_a := 0.0
var _report_timer := 0.0


func _ready() -> void:
	_drone = get_parent() as Drone
	recharge()


func _physics_process(delta: float) -> void:
	if not _drone or _drone.is_stowed:
		return
	var armed := _drone.flight_controller.state_armed
	power_w = get_electrical_power() if armed else 0.0
	voltage = get_voltage()
	current_a = power_w / voltage
	_average_current_a = lerpf(_average_current_a, current_a, 1.0 - exp(-delta / 3.0))

	if armed and not infinite:
		charge_mah = maxf(charge_mah - current_a * delta / 3.6, 0.0)
		_check_thresholds()

	_report_timer -= delta
	if _report_timer <= 0.0:
		_report_timer = 0.5
		var fraction := get_fraction()
		var seconds := get_seconds_left()
		changed.emit(fraction, seconds)
		EventBus.battery_changed.emit(fraction, seconds)


## Electrical power drawn by the motors from their thrust, using momentum theory for the
## ideal induced power of each propeller.
func get_electrical_power() -> float:
	var total := base_draw_w
	for motor in _drone.motors:
		var propeller := motor.propeller
		var radius := propeller.diameter * 0.0254 * 0.5
		var disk_area := PI * radius * radius
		var thrust := propeller.forces[0].length()
		total += pow(thrust, 1.5) / sqrt(2.0 * AIR_DENSITY * disk_area) / efficiency
	return total


func get_voltage() -> float:
	return cells * lerpf(CELL_VOLTAGE_EMPTY, CELL_VOLTAGE_FULL, get_fraction())


func get_fraction() -> float:
	return charge_mah / capacity_mah


## Flight time left at the recent average draw, never more than hovering would allow (idling
## on the ground or just after arming would otherwise promise far too much).
func get_seconds_left() -> float:
	var amps := maxf(_average_current_a, _estimate_hover_current())
	return charge_mah / 1000.0 / amps * 3600.0


func recharge() -> void:
	charge_mah = capacity_mah
	is_low = false
	is_depleted = false
	voltage = get_voltage()
	_average_current_a = 0.0
	if _drone and _drone.flight_controller:
		_drone.flight_controller.power_limit = 1.0
		_drone.flight_controller.arming_blocked = false


func _check_thresholds() -> void:
	var fraction := get_fraction()
	if not is_low and fraction <= low_fraction:
		is_low = true
		_drone.flight_controller.power_limit = low_power_limit
		low.emit()
		EventBus.battery_low.emit()
	if not is_depleted and charge_mah <= 0.0:
		is_depleted = true
		_drone.flight_controller.arming_blocked = true
		_drone.flight_controller._on_disarm_input()
		depleted.emit()
		EventBus.battery_depleted.emit()


func _estimate_hover_current() -> float:
	if not _drone or _drone.motors.is_empty():
		return 1.0
	var thrust := _drone.mass * 9.81 / _drone.motors.size()
	var radius := _drone.motors[0].propeller.diameter * 0.0254 * 0.5
	var disk_area := PI * radius * radius
	var per_motor := pow(thrust, 1.5) / sqrt(2.0 * AIR_DENSITY * disk_area) / efficiency
	return (base_draw_w + per_motor * _drone.motors.size()) / get_voltage()
