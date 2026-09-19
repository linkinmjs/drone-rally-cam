# Modified from GodotDrone (GPL-3.0, (c) Cykyrios) via drone-simulator, 2026: compact column with
# height above the ground (or "---"), horizontal speed, vertical speed, distance to the pilot,
# signed gimbal tilt and heading.
class_name HUDReadouts
extends Control
## Exact values in the right column: label, value and unit on each row. The column grows
## with the rows that are shown.


const MAIN_ROW := 40.0
const SMALL_ROW := 32.0
const LABEL_W := 96.0
const VALUE_W := 120.0
const UNIT_W := 72.0

## Height above the ground in meters; `altitude_known` is false when there is no ground under
## the drone within the sensor range.
var altitude := 0.0
var altitude_known := true
## Horizontal speed.
var speed_kmh := 0.0
var vertical_speed := 0.0
var vertical_speed_known := false
## Distance from the drone to the pilot, in meters.
var distance := 0.0
## Gimbal tilt, in degrees (negative looks down).
var gimbal_deg := 0.0
## Heading of the camera in view, 0–359 degrees.
var heading_deg := 0.0

var show_altitude := true
var show_speed := true
var show_distance := false
var show_gimbal := false
var show_heading := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_layout()


## Number of rows shown.
func row_count() -> int:
	return _rows().size()


## Recomputes the height from the rows shown; call after changing a show_* flag.
func refresh_layout() -> void:
	var height := 0.0
	for row: Array in _rows():
		height += row[3]
	custom_minimum_size = Vector2(LABEL_W + VALUE_W + UNIT_W, height)
	update_minimum_size()
	visible = height > 0.0
	queue_redraw()


func _rows() -> Array:
	var rows: Array = []
	if show_altitude:
		var alt := "---"
		if altitude_known:
			alt = HudStyle.decimal(altitude) if absf(altitude) < 10.0 else "%d" % [roundi(altitude)]
		rows.append(["HUD_ALT", alt, "HUD_UNIT_M", MAIN_ROW])
	if show_speed:
		rows.append(["HUD_SPD", "%d" % [roundi(speed_kmh)], "HUD_UNIT_KMH", MAIN_ROW])
	if show_altitude:
		var vs := "---"
		if altitude_known and vertical_speed_known:
			vs = "%s %s" % [_arrow(vertical_speed, 0.05), HudStyle.decimal(absf(vertical_speed))]
		rows.append(["HUD_VS", vs, "HUD_UNIT_MPS", SMALL_ROW])
	if show_distance:
		rows.append(["HUD_DIST", "%d" % [roundi(distance)], "HUD_UNIT_M", SMALL_ROW])
	if show_gimbal:
		rows.append(["HUD_GIMBAL", "%s %d" % [_arrow(gimbal_deg, 0.5), absi(roundi(gimbal_deg))],
				"HUD_UNIT_DEG_SHORT", SMALL_ROW])
	if show_heading:
		rows.append(["HUD_HDG", "%03d" % [posmod(roundi(heading_deg), 360)],
				"HUD_UNIT_DEG_SHORT", SMALL_ROW])
	return rows


static func _arrow(value: float, dead: float) -> String:
	if value > dead:
		return "▲"
	if value < -dead:
		return "▼"
	return " "


func _draw() -> void:
	var y := 0.0
	var x0 := size.x - (LABEL_W + VALUE_W + UNIT_W)
	for row: Array in _rows():
		var height: float = row[3]
		var value_size := HudStyle.SIZE_L if height == MAIN_ROW else HudStyle.SIZE_M
		var baseline := y + height * 0.72
		HUDDraw.text(self, HudStyle.bold_font(), Vector2(x0, baseline), tr(row[0]), HudStyle.SIZE_S,
				HORIZONTAL_ALIGNMENT_RIGHT, LABEL_W, HudStyle.DIM)
		HUDDraw.text(self, HudStyle.mono_font(), Vector2(x0 + LABEL_W, baseline), row[1], value_size,
				HORIZONTAL_ALIGNMENT_RIGHT, VALUE_W)
		HUDDraw.text(self, HudStyle.mono_font(), Vector2(x0 + LABEL_W + VALUE_W + 10.0, baseline),
				tr(row[2]), HudStyle.SIZE_S, HORIZONTAL_ALIGNMENT_LEFT, UNIT_W - 10.0, HudStyle.DIM)
		y += height
