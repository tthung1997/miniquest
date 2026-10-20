class_name OddsBar
extends Control
## A pack's odds as one stacked bar, a segment in each rarity's colour sized by
## its chance, with the percentages in a row beneath it.
##
## Shows what it is told. Hovering shows each rarity's chance in words.

const BAR_HEIGHT: float = 8.0
const GAP: float = 4.0
const DOT: float = 4.0
## Space between one legend entry and the next.
const LEGEND_GAP: float = 8.0
const TRACK_COLOR: Color = Color(0.08, 0.05, 0.03, 1.0)
const TEXT_COLOR: Color = Color(0.9, 0.85, 0.75, 1.0)
## A segment is never thinner than this, so a tiny chance is still visible.
const MIN_SEGMENT: float = 3.0

var _entries: Array[Dictionary] = []


func _init() -> void:
	custom_minimum_size = Vector2(120, BAR_HEIGHT + 16.0)


## Show `pack`'s odds, or nothing for null.
func show_pack(pack: PackData) -> void:
	_entries.clear()
	var lines: PackedStringArray = []
	if pack != null:
		for rarity: RarityData in RarityData.all():
			if pack.weight_of(rarity) <= 0.0:
				continue
			var chance: float = pack.chance_of(rarity)
			_entries.append({&"rarity": rarity, &"chance": chance})
			lines.append("%s %s" % [rarity.display_name, _percent(chance)])
	tooltip_text = "\n".join(lines)
	queue_redraw()


func _draw() -> void:
	if _entries.is_empty():
		return
	var track: Rect2 = Rect2(0.0, 0.0, size.x, BAR_HEIGHT)
	draw_rect(Rect2(track.position - Vector2.ONE, track.size + Vector2.ONE * 2.0), TRACK_COLOR)
	_draw_segments(track)
	_draw_legend()


func _draw_segments(track: Rect2) -> void:
	var widths: PackedFloat32Array = []
	var total: float = 0.0
	for entry: Dictionary in _entries:
		var width: float = maxf(track.size.x * float(entry[&"chance"]), MIN_SEGMENT)
		widths.append(width)
		total += width
	# Scaled back so the minimums do not push the bar past its track.
	var fit: float = track.size.x / total
	var x: float = track.position.x
	for i: int in _entries.size():
		var rarity: RarityData = _entries[i][&"rarity"]
		var width: float = floorf(widths[i] * fit)
		if i == _entries.size() - 1:
			width = track.end.x - x
		draw_rect(Rect2(x, track.position.y, width, track.size.y), rarity.color)
		draw_rect(Rect2(x, track.position.y, width, 2.0), rarity.color.lerp(Color.WHITE, 0.45))
		x += width


func _draw_legend() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	var y: float = BAR_HEIGHT + GAP + font_size
	var texts: PackedStringArray = []
	var total: float = 0.0
	for entry: Dictionary in _entries:
		var text: String = _percent(entry[&"chance"])
		texts.append(text)
		total += DOT + 3.0 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	total += LEGEND_GAP * (_entries.size() - 1)
	var left: float = floorf((size.x - total) * 0.5)
	for i: int in _entries.size():
		var rarity: RarityData = _entries[i][&"rarity"]
		draw_rect(Rect2(left, y - DOT - 1.0, DOT, DOT), rarity.color)
		left += DOT + 3.0
		draw_string(
			font, Vector2(left, y), texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR
		)
		left += font.get_string_size(texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		left += LEGEND_GAP


## 0.285 as "28.5%", and 0.6 as "60%".
static func _percent(chance: float) -> String:
	return ("%.1f" % (chance * 100.0)).trim_suffix(".0") + "%"
