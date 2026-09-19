## The camera operator's tablet: the stage map, when the car starts and gets to the player's
## spot, and the briefing at the start. It opens with show_map while walking and does not
## stop the player from moving.
class_name Tablet
extends PanelContainer


var stage: Stage = null
var is_open := false

var _title: Label
var _briefing: Label
var _map: StageMap
var _rows: VBoxContainer
var _footer: Label
var _auto_close := 0.0
var _refresh := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.18
	anchor_right = 0.82
	anchor_top = 0.12
	anchor_bottom = 0.88
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	var style := HudStyle.panel(0.92, 16, 24)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_title = HudStyle.make_label("", HudStyle.SIZE_L, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	column.add_child(_title)
	_briefing = HudStyle.make_label("", HudStyle.SIZE_S)
	_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_briefing)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	_map = StageMap.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_map)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size.x = 330
	_rows.add_theme_constant_override("separation", 6)
	body.add_child(_rows)

	_footer = HudStyle.make_label("", HudStyle.SIZE_S, HudStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	column.add_child(_footer)
	hide()


func setup(new_stage: Stage) -> void:
	stage = new_stage
	_map.setup(stage)
	_title.text = "TABLET · %s" % stage.stage_name


## Shows the tablet, with an optional briefing on top; closes on its own after `auto_close`
## seconds when it is above zero.
func open(briefing := "", auto_close := 0.0) -> void:
	_briefing.text = briefing
	_briefing.visible = not briefing.is_empty()
	_auto_close = auto_close
	is_open = true
	_refresh = 0.0
	show()


func close() -> void:
	is_open = false
	_auto_close = 0.0
	hide()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _process(delta: float) -> void:
	if not is_open or not stage:
		return
	if _auto_close > 0.0:
		_auto_close -= delta
		if _auto_close <= 0.0:
			close()
			return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.25
	_update_rows()
	_footer.text = "%s cerrar" % InputHints.button("show_map")
	if _auto_close > 0.0:
		_footer.text = "Se cierra en %d s · %s" % [ceili(_auto_close), _footer.text]


func _update_rows() -> void:
	var rows := stage.timetable()
	while _rows.get_child_count() < rows.size() * 2:
		var is_title := _rows.get_child_count() % 2 == 0
		var label := HudStyle.make_label("", HudStyle.SIZE_S if is_title else HudStyle.SIZE_L,
				HudStyle.DIM if is_title else HudStyle.WHITE)
		_rows.add_child(label)
	for i in _rows.get_child_count():
		var label := _rows.get_child(i) as Label
		var row := int(i / 2.0)
		label.visible = row < rows.size()
		if label.visible:
			label.text = rows[row][i % 2]
