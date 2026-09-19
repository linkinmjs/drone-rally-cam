class_name ThemeBuilder
extends RefCounted
## Builds the "rally at sunset" menu theme of Drone Rally Cam from UIPalette: warm dark
## surfaces, cream text, orange accent, a focus ring that reads over anything.
## Run `debug/tools/build_theme.gd` to regenerate `gui/theme/main_theme.tres`; never edit
## the .tres by hand.


const P := preload("res://gui/theme/ui_palette.gd")

## Every type variation the theme defines, for the checks.
const VARIATIONS: Array[String] = ["DisplayLabel", "TitleLabel", "HeadingLabel", "SubtitleLabel",
		"CaptionLabel", "SectionLabel", "HintLabel", "ValueLabel", "KeyCap", "GradeLabel",
		"SectionHeader", "MenuItemButton", "PrimaryButton", "DangerButton", "GhostButton",
		"HubCard", "Card", "InsetPanel", "Chip", "StatChip", "SliderRow", "ClearPanel",
		"HudPreviewPanel", "OverlayScrim", "BodyText"]


static func build() -> Theme:
	var t := Theme.new()
	var regular := load(P.FONT_REGULAR) as Font
	var bold := load(P.FONT_BOLD) as Font
	var mono := load(P.FONT_MONO) as Font
	t.default_font = regular
	t.default_font_size = 20

	_containers(t)
	_labels(t, bold, mono)
	_buttons(t, bold)
	_panels(t)
	_popups(t)
	_ranges(t)
	_toggles(t)
	_tabs(t, bold)
	_scroll(t)
	_text_inputs(t)
	_rich_text(t, regular, bold, mono)
	return t


# --- Style helpers -------------------------------------------------------------------------

static func flat(bg: Color, radius := 10, margins := Vector4(20, 12, 20, 12),
		border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.content_margin_left = margins.x
	sb.content_margin_top = margins.y
	sb.content_margin_right = margins.z
	sb.content_margin_bottom = margins.w
	if border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	return sb


## Focus ring: 2 px of accent with a dark halo outside it, visible over any background.
static func focus_ring(radius := 10, expand := 3.0) -> StyleBoxFlat:
	var sb := flat(Color.TRANSPARENT, radius + 2, Vector4.ZERO, P.ACCENT, 2)
	sb.draw_center = false
	sb.set_expand_margin_all(expand)
	sb.shadow_color = P.FOCUS_HALO
	sb.shadow_size = 2
	return sb


## Accent bar on the left side: focus and hover of the big menu entries.
static func left_bar(bg: Color, margins: Vector4, bar := 4) -> StyleBoxFlat:
	var sb := flat(bg, 8, margins)
	sb.border_color = P.ACCENT
	sb.border_width_left = bar
	sb.corner_radius_top_left = 2
	sb.corner_radius_bottom_left = 2
	return sb


static func empty(margins := Vector4.ZERO) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = margins.x
	sb.content_margin_top = margins.y
	sb.content_margin_right = margins.z
	sb.content_margin_bottom = margins.w
	return sb


static func with_shadow(sb: StyleBoxFlat, size := 24, offset := Vector2(0, 8)) -> StyleBoxFlat:
	sb.shadow_color = P.SHADOW
	sb.shadow_size = size
	sb.shadow_offset = offset
	return sb


## Bold with a little tracking, for the small uppercase labels of sections.
static func spaced(font: Font, spacing := 2) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = spacing
	return variation


# --- Sections ------------------------------------------------------------------------------

static func _containers(t: Theme) -> void:
	t.set_constant("separation", "BoxContainer", 12)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 24)
	t.set_constant("v_separation", "GridContainer", 14)
	t.set_constant("separation", "HFlowContainer", 12)
	for side: String in ["left", "top", "right", "bottom"]:
		t.set_constant("margin_" + side, "MarginContainer", 0)


static func _labels(t: Theme, bold: Font, mono: Font) -> void:
	t.set_color("font_color", "Label", P.TEXT)
	t.set_color("font_shadow_color", "Label", Color.TRANSPARENT)
	t.set_color("font_outline_color", "Label", Color.TRANSPARENT)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 4)

	var tracked := spaced(bold)
	var variations := {
		"DisplayLabel": [bold, 64, P.TEXT],
		"TitleLabel": [bold, 40, P.TEXT],
		"HeadingLabel": [bold, 24, P.TEXT],
		"SubtitleLabel": [null, 22, P.TEXT_2],
		"CaptionLabel": [null, 17, P.TEXT_2],
		"SectionLabel": [tracked, 15, P.TEXT_2],
		"HintLabel": [null, 17, P.TEXT_2],
		"ValueLabel": [mono, 20, P.TEXT],
		"GradeLabel": [mono, 72, P.TEXT],
	}
	for variation: String in variations:
		var data: Array = variations[variation]
		t.set_type_variation(variation, "Label")
		if data[0]:
			t.set_font("font", variation, data[0])
		t.set_font_size("font_size", variation, data[1])
		t.set_color("font_color", variation, data[2])

	# Section title: small tracked capitals after an accent bar.
	t.set_type_variation("SectionHeader", "Label")
	t.set_font("font", "SectionHeader", tracked)
	t.set_font_size("font_size", "SectionHeader", 16)
	t.set_color("font_color", "SectionHeader", P.TEXT)
	var header := flat(Color.TRANSPARENT, 0, Vector4(14, 2, 0, 2))
	header.border_color = P.ACCENT
	header.border_width_left = 4
	t.set_stylebox("normal", "SectionHeader", header)

	t.set_type_variation("KeyCap", "Label")
	t.set_font("font", "KeyCap", bold)
	t.set_font_size("font_size", "KeyCap", 15)
	t.set_color("font_color", "KeyCap", P.TEXT)
	t.set_stylebox("normal", "KeyCap", flat(P.SURFACE_ALT, 6, Vector4(8, 2, 8, 3), P.BORDER_STRONG, 1))

	t.set_color("font_color", "TooltipLabel", P.TEXT)
	t.set_font_size("font_size", "TooltipLabel", 18)
	t.set_stylebox("panel", "TooltipPanel",
			with_shadow(flat(P.SURFACE_ALT, 8, Vector4(14, 10, 14, 10), P.BORDER_STRONG, 1), 12))


static func _button_colors(t: Theme, type: String, normal: Color, hover: Color, focus: Color,
		disabled := P.TEXT_DISABLED) -> void:
	t.set_color("font_color", type, normal)
	t.set_color("font_hover_color", type, hover)
	t.set_color("font_pressed_color", type, hover)
	t.set_color("font_hover_pressed_color", type, hover)
	t.set_color("font_focus_color", type, focus)
	t.set_color("font_disabled_color", type, disabled)
	t.set_color("icon_normal_color", type, normal)
	t.set_color("icon_hover_color", type, hover)
	t.set_color("icon_pressed_color", type, hover)
	t.set_color("icon_focus_color", type, focus)
	t.set_color("icon_disabled_color", type, disabled)
	t.set_color("font_outline_color", type, Color.TRANSPARENT)
	t.set_constant("outline_size", type, 0)


static func _buttons(t: Theme, bold: Font) -> void:
	for type: String in ["Button", "MenuButton", "OptionButton", "LinkButton"]:
		_button_colors(t, type, P.TEXT, P.TEXT, P.TEXT)
	for type: String in ["Button", "MenuButton", "OptionButton"]:
		var margins := Vector4(20, 12, 20, 12) if type != "OptionButton" else Vector4(16, 10, 16, 10)
		t.set_stylebox("normal", type, flat(P.SURFACE_ALT, 10, margins, P.BORDER, 1))
		t.set_stylebox("hover", type, flat(P.SURFACE_PRESSED, 10, margins, P.BORDER_STRONG, 1))
		t.set_stylebox("pressed", type, flat(P.SURFACE_PRESSED, 10, margins, P.ACCENT, 1))
		t.set_stylebox("hover_pressed", type, flat(P.SURFACE_PRESSED, 10, margins, P.ACCENT, 1))
		t.set_stylebox("disabled", type, flat(P.SURFACE_DISABLED, 10, margins, P.BORDER, 1))
		t.set_stylebox("focus", type, focus_ring())
		t.set_constant("h_separation", type, 8)
	t.set_icon("arrow", "OptionButton", _chevron_icon(14, 9, P.TEXT_2, false))
	t.set_constant("arrow_margin", "OptionButton", 14)
	t.set_constant("modulate_arrow", "OptionButton", 0)
	t.set_color("font_color", "LinkButton", P.SKY)
	t.set_color("font_hover_color", "LinkButton", P.TEXT)
	t.set_stylebox("focus", "LinkButton", focus_ring(4, 2))

	# Big entries of the pause and results menus: plain text, an accent bar on focus.
	var mib := "MenuItemButton"
	t.set_type_variation(mib, "Button")
	var m := Vector4(28, 11, 28, 11)
	t.set_stylebox("normal", mib, empty(m))
	t.set_stylebox("hover", mib, left_bar(Color(P.ACCENT, 0.06), m))
	t.set_stylebox("pressed", mib, left_bar(Color(P.ACCENT, 0.16), m))
	t.set_stylebox("hover_pressed", mib, left_bar(Color(P.ACCENT, 0.16), m))
	t.set_stylebox("disabled", mib, empty(m))
	t.set_stylebox("focus", mib, left_bar(Color(P.ACCENT, 0.12), m))
	t.set_font("font", mib, bold)
	t.set_font_size("font_size", mib, 28)
	_button_colors(t, mib, P.TEXT_2, P.TEXT, P.TEXT)

	var primary := "PrimaryButton"
	t.set_type_variation(primary, "Button")
	var pm := Vector4(24, 12, 24, 12)
	t.set_stylebox("normal", primary, flat(P.ACCENT, 10, pm))
	t.set_stylebox("hover", primary, flat(P.ACCENT_HOVER, 10, pm))
	t.set_stylebox("pressed", primary, flat(P.ACCENT_PRESSED, 10, pm))
	t.set_stylebox("hover_pressed", primary, flat(P.ACCENT_PRESSED, 10, pm))
	t.set_stylebox("disabled", primary, flat(P.SURFACE_PRESSED, 10, pm))
	t.set_font("font", primary, bold)
	_button_colors(t, primary, P.TEXT_ON_ACCENT, P.TEXT_ON_ACCENT, P.TEXT_ON_ACCENT, P.TEXT_DISABLED)

	var danger := "DangerButton"
	var dm := Vector4(20, 12, 20, 12)
	t.set_type_variation(danger, "Button")
	t.set_stylebox("normal", danger, flat(P.DANGER_SOFT, 10, dm, P.DANGER, 2))
	t.set_stylebox("hover", danger, flat(P.DANGER_HOVER, 10, dm, P.DANGER, 2))
	t.set_stylebox("pressed", danger, flat(P.DANGER_HOVER, 10, dm, P.DANGER, 2))
	t.set_stylebox("hover_pressed", danger, flat(P.DANGER_HOVER, 10, dm, P.DANGER, 2))
	t.set_font("font", danger, bold)
	_button_colors(t, danger, P.DANGER, P.TEXT, P.TEXT)

	var ghost := "GhostButton"
	var gm := Vector4(16, 10, 16, 10)
	t.set_type_variation(ghost, "Button")
	t.set_stylebox("normal", ghost, empty(gm))
	t.set_stylebox("hover", ghost, flat(P.SURFACE_ALT, 10, gm))
	t.set_stylebox("pressed", ghost, flat(P.SURFACE_PRESSED, 10, gm))
	t.set_stylebox("hover_pressed", ghost, flat(P.SURFACE_PRESSED, 10, gm))
	_button_colors(t, ghost, P.TEXT_2, P.TEXT, P.TEXT)

	# Big cards of the options hub (icon, title and a line of description inside).
	var hub := "HubCard"
	var hm := Vector4(28, 24, 28, 24)
	t.set_type_variation(hub, "Button")
	t.set_stylebox("normal", hub, flat(P.SURFACE, 14, hm, P.BORDER, 1))
	t.set_stylebox("hover", hub, flat(P.SURFACE_ALT, 14, hm, P.BORDER_STRONG, 1))
	t.set_stylebox("pressed", hub, flat(P.SURFACE_PRESSED, 14, hm, P.ACCENT, 1))
	t.set_stylebox("hover_pressed", hub, flat(P.SURFACE_PRESSED, 14, hm, P.ACCENT, 1))
	t.set_stylebox("focus", hub, focus_ring(14, 3))
	_button_colors(t, hub, P.TEXT, P.TEXT, P.TEXT)


static func _panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", flat(P.SURFACE, 12, Vector4(24, 24, 24, 24), P.BORDER, 1))
	t.set_stylebox("panel", "Panel", flat(P.SURFACE, 12, Vector4.ZERO, P.BORDER, 1))

	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card",
			with_shadow(flat(P.SURFACE, 12, Vector4(36, 32, 36, 32), P.BORDER, 1)))
	t.set_type_variation("InsetPanel", "PanelContainer")
	t.set_stylebox("panel", "InsetPanel", flat(P.BG, 10, Vector4(20, 18, 20, 18), P.BORDER, 1))
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", flat(P.SURFACE_ALT, 8, Vector4(10, 5, 12, 5), P.BORDER, 1))
	t.set_type_variation("StatChip", "PanelContainer")
	t.set_stylebox("panel", "StatChip", flat(P.SURFACE_ALT, 18, Vector4(14, 6, 16, 6), P.BORDER_STRONG, 1))
	t.set_type_variation("SliderRow", "PanelContainer")
	var row_margins := Vector4(20, 12, 20, 12)
	t.set_stylebox("panel", "SliderRow", flat(P.SURFACE_ALT, 10, row_margins))
	t.set_stylebox("focus", "SliderRow", left_bar(Color(P.ACCENT, 0.12), row_margins))
	t.set_type_variation("ClearPanel", "PanelContainer")
	t.set_stylebox("panel", "ClearPanel", empty())
	t.set_type_variation("HudPreviewPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPreviewPanel", flat(Color("#3B5268"), 12, Vector4.ZERO, P.BORDER, 1))
	t.set_type_variation("OverlayScrim", "Panel")
	t.set_stylebox("panel", "OverlayScrim", flat(P.SCRIM, 0, Vector4.ZERO))

	# Rows that behave like buttons (control bindings)
	var rm := Vector4(14, 8, 14, 8)
	t.set_stylebox("normal", "RowPanel", empty(rm))
	t.set_stylebox("hover", "RowPanel", flat(P.SURFACE_ALT, 8, rm))
	t.set_stylebox("focus", "RowPanel", flat(P.ACCENT_SOFT, 8, rm, P.ACCENT, 2))

	var line := StyleBoxLine.new()
	line.color = P.BORDER
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 16)
	var vline := StyleBoxLine.new()
	vline.color = P.BORDER
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)
	t.set_constant("separation", "VSeparator", 16)

	t.set_stylebox("background", "ProgressBar", flat(P.SURFACE_PRESSED, 4, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", flat(P.ACCENT, 4, Vector4.ZERO))
	t.set_color("font_color", "ProgressBar", P.TEXT)


static func _popups(t: Theme) -> void:
	var panel := with_shadow(flat(P.SURFACE_ALT, 12, Vector4(8, 8, 8, 8), P.BORDER_STRONG, 1), 16)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_stylebox("panel", "PopupPanel", panel)
	t.set_stylebox("hover", "PopupMenu", flat(P.ACCENT_SOFT, 8, Vector4(12, 8, 12, 8)))
	t.set_stylebox("focus", "PopupMenu", flat(P.ACCENT_SOFT, 8, Vector4(12, 8, 12, 8)))
	var sep := StyleBoxLine.new()
	sep.color = P.BORDER
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_color("font_color", "PopupMenu", P.TEXT)
	t.set_color("font_hover_color", "PopupMenu", P.ACCENT_HOVER)
	t.set_color("font_disabled_color", "PopupMenu", P.TEXT_DISABLED)
	t.set_color("font_accelerator_color", "PopupMenu", P.TEXT_2)
	t.set_color("font_separator_color", "PopupMenu", P.TEXT_2)
	t.set_color("font_outline_color", "PopupMenu", Color.TRANSPARENT)
	t.set_constant("outline_size", "PopupMenu", 0)
	t.set_constant("v_separation", "PopupMenu", 10)
	t.set_constant("h_separation", "PopupMenu", 10)
	t.set_constant("item_start_padding", "PopupMenu", 10)
	t.set_constant("item_end_padding", "PopupMenu", 14)
	t.set_font_size("font_size", "PopupMenu", 20)
	var dot := _dot_icon(18, 7, P.ACCENT)
	var blank := _blank_icon(18)
	for icon: String in ["radio_checked", "checked"]:
		t.set_icon(icon, "PopupMenu", dot)
		t.set_icon(icon + "_disabled", "PopupMenu", dot)
	for icon: String in ["radio_unchecked", "unchecked"]:
		t.set_icon(icon, "PopupMenu", blank)
		t.set_icon(icon + "_disabled", "PopupMenu", blank)
	t.set_icon("submenu", "PopupMenu", _chevron_icon(9, 14, P.TEXT_2, true))

	t.set_stylebox("embedded_border", "Window", empty())
	t.set_stylebox("embedded_unfocused_border", "Window", empty())


static func _ranges(t: Theme) -> void:
	for type: String in ["HSlider", "VSlider"]:
		var track := flat(P.SURFACE_PRESSED, 4, Vector4(0, 3, 0, 3))
		var fill := flat(P.ACCENT, 4, Vector4(0, 3, 0, 3))
		if type == "VSlider":
			track = flat(P.SURFACE_PRESSED, 4, Vector4(3, 0, 3, 0))
			fill = flat(P.ACCENT, 4, Vector4(3, 0, 3, 0))
		t.set_stylebox("slider", type, track)
		t.set_stylebox("grabber_area", type, fill)
		t.set_stylebox("grabber_area_highlight", type, fill)
		t.set_icon("grabber", type, _ring_icon(24, P.TEXT, P.ACCENT, 2.5))
		t.set_icon("grabber_highlight", type, _ring_icon(26, P.ACCENT, P.TEXT, 3.0))
		t.set_icon("grabber_disabled", type, _ring_icon(24, P.SURFACE_PRESSED, P.BORDER_STRONG, 2.5))
		t.set_icon("tick", type, _tick_icon(type == "HSlider"))
		t.set_stylebox("focus", type, focus_ring(8, 6))
		t.set_constant("center_grabber", type, 0)
		t.set_constant("grabber_offset", type, 0)


static func _toggles(t: Theme) -> void:
	var m := Vector4(4, 6, 4, 6)
	for type: String in ["CheckButton", "CheckBox"]:
		_button_colors(t, type, P.TEXT, P.TEXT, P.TEXT)
		t.set_stylebox("normal", type, empty(m))
		t.set_stylebox("pressed", type, empty(m))
		t.set_stylebox("hover", type, empty(m))
		t.set_stylebox("hover_pressed", type, empty(m))
		t.set_stylebox("disabled", type, empty(m))
		t.set_stylebox("focus", type, focus_ring(8, 4))
		t.set_constant("h_separation", type, 14)
		t.set_constant("check_v_offset", type, 0)
	var on := _switch_icon(true, P.ACCENT, P.TEXT)
	var off := _switch_icon(false, P.SURFACE_PRESSED, P.TEXT_2)
	var on_disabled := _switch_icon(true, Color(P.ACCENT, 0.35), P.TEXT_DISABLED)
	var off_disabled := _switch_icon(false, P.SURFACE_ALT, P.TEXT_DISABLED)
	for suffix: String in ["", "_mirrored"]:
		t.set_icon("checked" + suffix, "CheckButton", on)
		t.set_icon("unchecked" + suffix, "CheckButton", off)
		t.set_icon("checked_disabled" + suffix, "CheckButton", on_disabled)
		t.set_icon("unchecked_disabled" + suffix, "CheckButton", off_disabled)
	t.set_icon("checked", "CheckBox", _checkbox_icon(true, P.ACCENT))
	t.set_icon("unchecked", "CheckBox", _checkbox_icon(false, P.BORDER_STRONG))
	t.set_icon("checked_disabled", "CheckBox", _checkbox_icon(true, P.BORDER_STRONG))
	t.set_icon("unchecked_disabled", "CheckBox", _checkbox_icon(false, P.BORDER))
	t.set_icon("radio_checked", "CheckBox", _ring_icon(24, P.TEXT_ON_ACCENT, P.ACCENT, 7.0))
	t.set_icon("radio_unchecked", "CheckBox", _ring_icon(24, P.SURFACE, P.BORDER_STRONG, 2.0))
	t.set_icon("radio_checked_disabled", "CheckBox", _ring_icon(24, P.SURFACE, P.BORDER_STRONG, 7.0))
	t.set_icon("radio_unchecked_disabled", "CheckBox", _ring_icon(24, P.SURFACE, P.BORDER, 2.0))


static func _tabs(t: Theme, bold: Font) -> void:
	for type: String in ["TabContainer", "TabBar"]:
		var tm := Vector4(22, 10, 22, 10)
		var selected := flat(P.SURFACE_ALT, 10, tm)
		selected.border_color = P.ACCENT
		selected.border_width_bottom = 3
		selected.corner_radius_bottom_left = 0
		selected.corner_radius_bottom_right = 0
		t.set_stylebox("tab_selected", type, selected)
		t.set_stylebox("tab_unselected", type, empty(tm))
		t.set_stylebox("tab_hovered", type, flat(P.SURFACE_ALT, 10, tm))
		t.set_stylebox("tab_disabled", type, empty(tm))
		t.set_stylebox("tab_focus", type, focus_ring(10, 2))
		t.set_color("font_selected_color", type, P.TEXT)
		t.set_color("font_unselected_color", type, P.TEXT_2)
		t.set_color("font_hovered_color", type, P.TEXT)
		t.set_color("font_disabled_color", type, P.TEXT_DISABLED)
		t.set_color("font_outline_color", type, Color.TRANSPARENT)
		t.set_font("font", type, bold)
		t.set_constant("h_separation", type, 8)
		t.set_constant("outline_size", type, 0)
	t.set_stylebox("panel", "TabContainer", empty(Vector4(0, 20, 0, 0)))
	t.set_stylebox("tabbar_background", "TabContainer", empty(Vector4(0, 0, 0, 0)))
	t.set_constant("side_margin", "TabContainer", 0)


static func _scroll(t: Theme) -> void:
	t.set_stylebox("panel", "ScrollContainer", empty())
	t.set_constant("scrollbar_h_separation", "ScrollContainer", 14)
	t.set_constant("scrollbar_v_separation", "ScrollContainer", 14)
	t.set_stylebox("focus", "ScrollContainer", empty())
	var blank := _blank_icon(1)
	for type: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, flat(Color.TRANSPARENT, 4, Vector4(3, 3, 3, 3)))
		t.set_stylebox("scroll_focus", type, flat(Color.TRANSPARENT, 4, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber", type, flat(P.BORDER_STRONG, 4, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber_highlight", type, flat(P.TEXT_2, 4, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber_pressed", type, flat(P.ACCENT, 4, Vector4(3, 3, 3, 3)))
		for icon: String in ["increment", "increment_highlight", "increment_pressed",
				"decrement", "decrement_highlight", "decrement_pressed"]:
			t.set_icon(icon, type, blank)


static func _text_inputs(t: Theme) -> void:
	var m := Vector4(12, 8, 12, 8)
	t.set_stylebox("normal", "LineEdit", flat(P.BG, 8, m, P.BORDER_STRONG, 1))
	t.set_stylebox("focus", "LineEdit", flat(Color.TRANSPARENT, 8, m, P.ACCENT, 2))
	(t.get_stylebox("focus", "LineEdit") as StyleBoxFlat).draw_center = false
	t.set_stylebox("read_only", "LineEdit", flat(P.SURFACE_DISABLED, 8, m, P.BORDER, 1))
	t.set_color("font_color", "LineEdit", P.TEXT)
	t.set_color("font_uneditable_color", "LineEdit", P.TEXT_2)
	t.set_color("font_placeholder_color", "LineEdit", P.TEXT_DISABLED)
	t.set_color("font_selected_color", "LineEdit", P.TEXT)
	t.set_color("selection_color", "LineEdit", Color(P.ACCENT, 0.35))
	t.set_color("caret_color", "LineEdit", P.ACCENT)
	t.set_color("clear_button_color", "LineEdit", P.TEXT_2)
	t.set_color("font_outline_color", "LineEdit", Color.TRANSPARENT)
	t.set_constant("outline_size", "LineEdit", 0)

	var up := _chevron_icon(12, 8, P.TEXT_2, false, true)
	var down := _chevron_icon(12, 8, P.TEXT_2, false)
	for state: String in ["", "_hover", "_pressed", "_disabled"]:
		t.set_icon("up" + state, "SpinBox", up)
		t.set_icon("down" + state, "SpinBox", down)
	t.set_icon("updown", "SpinBox", _updown_icon())
	t.set_stylebox("up_background", "SpinBox", empty())
	t.set_stylebox("down_background", "SpinBox", empty())
	t.set_stylebox("up_background_hovered", "SpinBox", flat(P.SURFACE_ALT, 6, Vector4.ZERO))
	t.set_stylebox("down_background_hovered", "SpinBox", flat(P.SURFACE_ALT, 6, Vector4.ZERO))
	t.set_stylebox("up_background_pressed", "SpinBox", flat(P.SURFACE_PRESSED, 6, Vector4.ZERO))
	t.set_stylebox("down_background_pressed", "SpinBox", flat(P.SURFACE_PRESSED, 6, Vector4.ZERO))
	t.set_stylebox("up_background_disabled", "SpinBox", empty())
	t.set_stylebox("down_background_disabled", "SpinBox", empty())
	t.set_stylebox("field_and_buttons_separator", "SpinBox", empty())
	t.set_stylebox("up_down_buttons_separator", "SpinBox", empty())
	t.set_constant("buttons_width", "SpinBox", 26)
	t.set_constant("field_and_buttons_separation", "SpinBox", 2)
	t.set_color("up_icon_modulate", "SpinBox", P.TEXT_2)
	t.set_color("up_hover_icon_modulate", "SpinBox", P.ACCENT)
	t.set_color("up_pressed_icon_modulate", "SpinBox", P.ACCENT_PRESSED)
	t.set_color("up_disabled_icon_modulate", "SpinBox", P.TEXT_DISABLED)
	t.set_color("down_icon_modulate", "SpinBox", P.TEXT_2)
	t.set_color("down_hover_icon_modulate", "SpinBox", P.ACCENT)
	t.set_color("down_pressed_icon_modulate", "SpinBox", P.ACCENT_PRESSED)
	t.set_color("down_disabled_icon_modulate", "SpinBox", P.TEXT_DISABLED)


static func _rich_text(t: Theme, regular: Font, bold: Font, mono: Font) -> void:
	t.set_stylebox("normal", "RichTextLabel", empty())
	t.set_stylebox("focus", "RichTextLabel", empty())
	t.set_color("default_color", "RichTextLabel", P.TEXT)
	t.set_color("font_selected_color", "RichTextLabel", P.TEXT)
	t.set_color("selection_color", "RichTextLabel", Color(P.ACCENT, 0.35))
	t.set_color("font_shadow_color", "RichTextLabel", Color.TRANSPARENT)
	t.set_color("font_outline_color", "RichTextLabel", Color.TRANSPARENT)
	t.set_font("normal_font", "RichTextLabel", regular)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font("mono_font", "RichTextLabel", mono)
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	t.set_font_size("mono_font_size", "RichTextLabel", 19)
	t.set_constant("line_separation", "RichTextLabel", 6)
	t.set_constant("outline_size", "RichTextLabel", 0)
	t.set_type_variation("BodyText", "RichTextLabel")
	t.set_color("default_color", "BodyText", P.TEXT_2)
	t.set_font_size("normal_font_size", "BodyText", 20)


# --- Procedural icons ----------------------------------------------------------------------

static var _bar_texture: ImageTexture = null


## White rounded bar used (tinted) by the controller axis and button indicators.
static func bar_texture() -> ImageTexture:
	if _bar_texture == null:
		var s := 12
		var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		var c := Vector2(s, s) / 2.0
		for y in s:
			for x in s:
				_blend(img, x, y, Color.WHITE,
						0.5 - _rounded_rect_sdf(Vector2(x + 0.5, y + 0.5), c, c, 4.0))
		_bar_texture = _texture(img)
	return _bar_texture


static func _texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _blank_icon(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	return _texture(img)


static func _blend(img: Image, x: int, y: int, color: Color, coverage: float) -> void:
	if coverage <= 0.0:
		return
	var src := Color(color, color.a * clampf(coverage, 0.0, 1.0))
	var dst := img.get_pixel(x, y)
	var out_a := src.a + dst.a * (1.0 - src.a)
	if out_a <= 0.0:
		return
	var out := Color(
		(src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / out_a,
		(src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / out_a,
		(src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / out_a,
		out_a)
	img.set_pixel(x, y, out)


static func _rounded_rect_sdf(p: Vector2, center: Vector2, half: Vector2, radius: float) -> float:
	var q := (p - center).abs() - half + Vector2(radius, radius)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var h := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - a - ab * h).length()


static func _ring_icon(size: int, fill: Color, ring: Color, ring_width: float) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c := Vector2(size, size) / 2.0
	var r := size / 2.0 - 1.0
	for y in size:
		for x in size:
			var d := (Vector2(x + 0.5, y + 0.5) - c).length()
			_blend(img, x, y, ring, r + 0.5 - d)
			_blend(img, x, y, fill, (r - ring_width) + 0.5 - d)
	return _texture(img)


static func _dot_icon(size: int, radius: float, color: Color) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c := Vector2(size, size) / 2.0
	for y in size:
		for x in size:
			var d := (Vector2(x + 0.5, y + 0.5) - c).length()
			_blend(img, x, y, color, radius / 2.0 + 0.5 - d)
	return _texture(img)


static func _switch_icon(checked: bool, track: Color, knob: Color) -> ImageTexture:
	var w := 50
	var h := 28
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := Vector2(w, h) / 2.0
	var knob_center := Vector2(h / 2.0 if not checked else w - h / 2.0, h / 2.0)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			_blend(img, x, y, track, 0.5 - _rounded_rect_sdf(p, center, Vector2(w, h) / 2.0 - Vector2.ONE, h / 2.0 - 1.0))
			_blend(img, x, y, knob, 0.5 - ((p - knob_center).length() - (h / 2.0 - 4.0)))
	return _texture(img)


static func _checkbox_icon(checked: bool, color: Color) -> ImageTexture:
	var s := 24
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c := Vector2(s, s) / 2.0
	var half := Vector2(s, s) / 2.0 - Vector2.ONE
	for y in s:
		for x in s:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _rounded_rect_sdf(p, c, half, 6.0)
			if checked:
				_blend(img, x, y, color, 0.5 - d)
				var dist := minf(_segment_distance(p, Vector2(6.5, 12.5), Vector2(10.5, 16.5)),
						_segment_distance(p, Vector2(10.5, 16.5), Vector2(17.5, 8.0)))
				_blend(img, x, y, P.TEXT_ON_ACCENT, 1.5 + 0.5 - dist)
			else:
				_blend(img, x, y, color, 0.5 - d)
				_blend(img, x, y, P.BG, 0.5 - _rounded_rect_sdf(p, c, half - Vector2(2, 2), 4.5))
	return _texture(img)


static func _chevron_icon(w: int, h: int, color: Color, pointing_right: bool,
		pointing_up := false) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var a: Vector2
	var b: Vector2
	var c: Vector2
	if pointing_right:
		a = Vector2(2, 2)
		b = Vector2(w - 2.5, h / 2.0)
		c = Vector2(2, h - 2)
	elif pointing_up:
		a = Vector2(2, h - 2)
		b = Vector2(w / 2.0, 2)
		c = Vector2(w - 2, h - 2)
	else:
		a = Vector2(2, 2)
		b = Vector2(w / 2.0, h - 2.5)
		c = Vector2(w - 2, 2)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var dist := minf(_segment_distance(p, a, b), _segment_distance(p, b, c))
			_blend(img, x, y, color, 1.1 + 0.5 - dist)
	return _texture(img)


static func _updown_icon() -> ImageTexture:
	var w := 14
	var h := 22
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var up := minf(_segment_distance(p, Vector2(3, 8), Vector2(7, 4)),
					_segment_distance(p, Vector2(7, 4), Vector2(11, 8)))
			var down := minf(_segment_distance(p, Vector2(3, 14), Vector2(7, 18)),
					_segment_distance(p, Vector2(7, 18), Vector2(11, 14)))
			_blend(img, x, y, P.TEXT_2, 1.1 + 0.5 - minf(up, down))
	return _texture(img)


static func _tick_icon(horizontal: bool) -> ImageTexture:
	var size := Vector2i(2, 8) if horizontal else Vector2i(8, 2)
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(P.BORDER_STRONG)
	return _texture(img)
