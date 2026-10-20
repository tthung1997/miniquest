class_name PityMeter
extends Control
## How close a pack's guaranteed Legendary is: a star, then a bar that fills as
## pulls go by without one. The star glows, and the bar shimmers, when the
## next pull is the guaranteed one.
##
## Shows what it is told.

const HEIGHT: float = 14.0
const BAR_HEIGHT: float = 6.0
const STAR_SIZE: float = 6.0
const TRACK_COLOR: Color = Color(0.08, 0.05, 0.03, 1.0)
const FILL_COLOR: Color = Color(0.95, 0.62, 0.2, 1.0)
const STAR_OFF: Color = Color(0.5, 0.4, 0.28, 1.0)
const TEXT_COLOR: Color = Color(0.9, 0.85, 0.75, 1.0)
## Radians a second of the ready pulse.
const PULSE_SPEED: float = 8.0

var _count: int = 0
var _limit: int = 0
var _seconds: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(120, HEIGHT)


func _process(delta: float) -> void:
	_seconds += delta
	queue_redraw()


## Show `count` pulls since the last Legendary out of `limit`. A limit of zero
## means the pack has no guarantee, and the meter hides.
func show_progress(count: int, limit: int) -> void:
	_count = count
	_limit = limit
	visible = limit > 0
	set_process(visible and is_ready_now())
	tooltip_text = (
		"Your next pull is a guaranteed Legendary!" if is_ready_now()
		else "Legendary guaranteed within %d pulls" % maxi(limit - count, 1)
	)
	queue_redraw()


## Whether the next pull is the guaranteed one.
func is_ready_now() -> bool:
	return _limit > 0 and _count >= _limit - 1


func _draw() -> void:
	if _limit <= 0:
		return
	var imminent: bool = is_ready_now()
	var pulse: float = 0.5 + 0.5 * sin(_seconds * PULSE_SPEED) if imminent else 0.0
	var legendary: RarityData = RarityData.highest()
	var gold: Color = legendary.color if legendary != null else FILL_COLOR
	_draw_star(
		Vector2(STAR_SIZE, HEIGHT * 0.5), STAR_SIZE, gold if imminent else STAR_OFF, pulse
	)

	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	var label: String = "%d/%d" % [_count, _limit]
	var label_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var bar_left: float = STAR_SIZE * 2.0 + 4.0
	var track: Rect2 = Rect2(
		bar_left, (HEIGHT - BAR_HEIGHT) * 0.5, size.x - bar_left - label_width - 6.0, BAR_HEIGHT
	)
	draw_rect(Rect2(track.position - Vector2.ONE, track.size + Vector2.ONE * 2.0), TRACK_COLOR)
	var filled: float = floorf(track.size.x * clampf(float(_count) / _limit, 0.0, 1.0))
	var fill: Color = FILL_COLOR.lerp(Color.WHITE, pulse * 0.5)
	draw_rect(Rect2(track.position, Vector2(filled, track.size.y)), fill)
	draw_rect(Rect2(track.position, Vector2(filled, 2.0)), fill.lerp(Color.WHITE, 0.45))
	draw_string(
		font, Vector2(size.x - label_width, HEIGHT * 0.5 + font_size * 0.35), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR
	)


## A five-pointed star of radius `radius` centred on `centre`, with a halo of
## `halo` strength behind it.
func _draw_star(centre: Vector2, radius: float, color: Color, halo: float) -> void:
	if halo > 0.0:
		var glow: Color = color
		glow.a = 0.3 * halo
		draw_circle(centre, radius * 1.7, glow)
	var points: PackedVector2Array = []
	for i: int in 10:
		var angle: float = -PI * 0.5 + i * PI / 5.0
		var reach: float = radius if i % 2 == 0 else radius * 0.45
		points.append(centre + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(points, color)
