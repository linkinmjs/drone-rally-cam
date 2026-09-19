## The stages of the championship as cards: map of the road, name, description, length, best
## grade and clips delivered; a locked stage says what opens it. An open stage starts with ✕.
class_name StageSelect
extends MenuScreen


const CARD_SIZE := Vector2(440, 500)

## The card of each stage, by id.
var cards := {}

@onready var cards_row := %Cards as HBoxContainer
@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	_build_cards()
	var current := Progress.current_stage()
	if current and cards.has(current.id):
		initial_focus = cards[current.id]
	super()
	bind_back_button(button_back)


func _build_cards() -> void:
	for info in StageCatalog.get_default().stages:
		var card := _card(info)
		cards_row.add_child(card)
		cards[info.id] = card


func _card(info: StageInfo) -> Button:
	var unlocked := Progress.is_unlocked(info.id)
	var card := Button.new()
	card.name = "Card_%s" % info.id
	card.theme_type_variation = &"HubCard"
	card.custom_minimum_size = CARD_SIZE
	card.set_meta(&"stage_id", info.id)
	card.set_meta(&"locked", not unlocked)
	if unlocked:
		var _discard := card.pressed.connect(SceneTransition.start_stage.bind(info))
	else:
		card.set_meta(&"ui_silent", true)
		var _discard := card.pressed.connect(UI.play.bind("error"))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 10)
	margin.add_child(content)

	var map := TrackThumbnail.new()
	map.custom_minimum_size = Vector2(0, 190)
	map.points = info.road_points()
	if not unlocked:
		map.line_color = UIPalette.TEXT_DISABLED
	content.add_child(map)
	content.add_child(_label(tr("STAGE_NUMBER") % info.number, &"SectionHeader", true))
	content.add_child(_label(info.display_name, &"HeadingLabel"))
	var description := _label(info.description, &"CaptionLabel")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = CARD_SIZE.x - 60.0
	content.add_child(description)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)

	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override(&"separation", 18)
	content.add_child(stats)
	if unlocked:
		var grade := Progress.best_grade(info.id)
		var grade_label := _label(grade if not grade.is_empty() else "—", &"GradeLabel")
		grade_label.add_theme_font_size_override(&"font_size", 40)
		grade_label.add_theme_color_override(&"font_color",
				UIPalette.grade_color(grade) if not grade.is_empty() else UIPalette.TEXT_DISABLED)
		stats.add_child(grade_label)
		var numbers := VBoxContainer.new()
		numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
		numbers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		numbers.add_theme_constant_override(&"separation", 0)
		numbers.add_child(_label("%s km" % HudStyle.decimal(info.length_km), &"ValueLabel"))
		var clips := Progress.clips_delivered(info.id)
		numbers.add_child(_label(tr("STAGE_CLIPS") % clips, &"CaptionLabel"))
		stats.add_child(numbers)
	else:
		var locked := VBoxContainer.new()
		locked.mouse_filter = Control.MOUSE_FILTER_IGNORE
		locked.add_theme_constant_override(&"separation", 4)
		locked.add_child(_label("STAGE_LOCKED_TITLE", &"SectionLabel", true))
		var needed := StageCatalog.get_default().find(info.unlock_after)
		var hint := _label(tr("STAGE_LOCKED") % [info.unlock_grade, needed.title() if needed else ""],
				&"CaptionLabel")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = CARD_SIZE.x - 60.0
		locked.add_child(hint)
		stats.add_child(locked)
		content.modulate = Color(1, 1, 1, 0.55)
	return card


func _label(text: String, variation: StringName, upper := false) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.uppercase = upper
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
