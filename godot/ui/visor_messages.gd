## The single message line of the viewfinder. Everything that has to tell the pilot
## something (crash, battery, a refused arming, a lost clip) posts here, so messages never
## overwrite each other in the same frame: one is shown at a time, the most important first.
class_name VisorMessages
extends Label


enum Level {INFO, WARN, ALERT}

## Most messages waiting to be shown (the oldest of the lowest level are dropped).
const MAX_QUEUED := 3
const LEVEL_COLORS: Array[Color] = [HudStyle.WHITE, HudStyle.AMBER, HudStyle.RED]
const LEVEL_SIZES: Array[int] = [HudStyle.SIZE_M, HudStyle.SIZE_M, HudStyle.SIZE_L]

## Pending messages: {text, level, seconds, key, order}.
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _order := 0
var _blink := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_override("font", HudStyle.bold_font())
	add_theme_color_override("font_outline_color", HudStyle.OUTLINE)
	custom_minimum_size.y = 48.0
	_apply_style(Level.INFO)


## Shows `text` for `seconds`. A message with the same `key` as a pending or visible one
## replaces it; a higher level interrupts a lower one.
func post(message: String, level := Level.INFO, seconds := 2.5, key := &"") -> void:
	if not key.is_empty():
		clear(key)
	_order += 1
	_queue.append({"text": message, "level": level, "seconds": seconds, "key": key, "order": _order})
	if not _current.is_empty() and level > int(_current["level"]):
		# Put the interrupted message back, with the time it still had.
		_queue.append(_current)
		_current = {}
	_trim()
	if _current.is_empty():
		_show_next()


## Removes the messages with `key` (every message when empty).
func clear(key := &"") -> void:
	if key.is_empty():
		_queue.clear()
		_current = {}
	else:
		_queue = _queue.filter(func(m: Dictionary) -> bool: return m["key"] != key)
		if not _current.is_empty() and _current["key"] == key:
			_current = {}
	if _current.is_empty():
		_show_next()


func has_key(key: StringName) -> bool:
	if not _current.is_empty() and _current["key"] == key:
		return true
	return _queue.any(func(m: Dictionary) -> bool: return m["key"] == key)


func current_text() -> String:
	return "" if _current.is_empty() else String(_current["text"])


func current_level() -> Level:
	return Level.INFO if _current.is_empty() else _current["level"] as Level


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_current["seconds"] = float(_current["seconds"]) - delta
	if float(_current["seconds"]) <= 0.0:
		_current = {}
		_show_next()
		return
	if int(_current["level"]) == Level.ALERT:
		_blink = fmod(_blink + delta, 1.0)
		modulate.a = 1.0 if _blink < 0.7 else 0.45


func _show_next() -> void:
	if _current.is_empty() and not _queue.is_empty():
		var best := 0
		for i in _queue.size():
			var m := _queue[i]
			var b := _queue[best]
			if int(m["level"]) > int(b["level"]) \
					or int(m["level"]) == int(b["level"]) and int(m["order"]) > int(b["order"]):
				best = i
		_current = _queue.pop_at(best)
	modulate.a = 1.0
	_blink = 0.0
	if _current.is_empty():
		text = ""
	else:
		text = String(_current["text"])
		_apply_style(_current["level"] as Level)


func _trim() -> void:
	while _queue.size() > MAX_QUEUED:
		var worst := 0
		for i in _queue.size():
			var m := _queue[i]
			var w := _queue[worst]
			if int(m["level"]) < int(w["level"]) \
					or int(m["level"]) == int(w["level"]) and int(m["order"]) < int(w["order"]):
				worst = i
		_queue.remove_at(worst)


func _apply_style(level: Level) -> void:
	var font_size := LEVEL_SIZES[level]
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("outline_size", HudStyle.outline_size(font_size))
	add_theme_color_override("font_color", LEVEL_COLORS[level])
