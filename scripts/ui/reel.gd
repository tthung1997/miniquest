class_name Reel
extends Control
## One window of the slot machine: a strip of item icons that spins, slows and
## stops on one item, then flashes in that item's rarity colour.
##
## Shows only what it is told and never changes a hero. `spin()` starts it,
## `land_on()` stops it on an item after a delay, and `land_now()` jumps there
## at once. `landed` is emitted when it has stopped, either way. Icons drawn
## while it spins are `fillers`, a shared list set by the screen; the item it
## stops on is drawn with its rarity's glow and frame.

signal landed

enum State { IDLE, SPINNING, LANDING, LANDED }

## Rows a second at full speed, and how fast it gets there.
const SPIN_SPEED: float = 16.0
const SPIN_UP: float = 40.0
## Seconds the slowing takes. It starts at the spinning speed, so the strip
## does not jerk.
const LAND_SECONDS: float = 0.9
## Seconds the flash on landing takes to fade.
const FLASH_SECONDS: float = 0.6
## How far an icon is dimmed while spinning, so it reads as a blur.
const BLUR_ALPHA: float = 0.55
const SOCKET_COLOR: Color = Color(0.13, 0.1, 0.08, 1.0)
const SOCKET_EDGE: Color = Color(0.06, 0.04, 0.03, 1.0)
const MARK_COLOR: Color = Color(1.0, 0.82, 0.35, 1.0)
const QUESTION_COLOR: Color = Color(1.0, 1.0, 1.0, 0.35)
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.28)
const FRAME_WIDTH: float = 2.0

## Icons shown while spinning. Without any, a spinning reel is blank.
var fillers: Array[EquipmentItem] = []

var _state: State = State.IDLE
var _scroll: float = 0.0
var _speed: float = 0.0
var _target_row: int = 0
var _item: EquipmentItem = null
var _rarity: RarityData = null
var _flash: float = 0.0
var _seconds: float = 0.0
var _seed: int = 0
var _tween: Tween = null


func _init() -> void:
	custom_minimum_size = Vector2(64, 64)
	clip_contents = true
	_seed = randi()


func _process(delta: float) -> void:
	_seconds += delta
	if _state == State.SPINNING:
		_speed = move_toward(_speed, SPIN_SPEED, SPIN_UP * delta)
		_scroll += _speed * delta
	queue_redraw()


## Whether the reel is spinning or slowing down.
func is_busy() -> bool:
	return _state == State.SPINNING or _state == State.LANDING


## Go back to the idle window, showing a question mark.
func reset() -> void:
	_stop_tween()
	_state = State.IDLE
	_item = null
	_rarity = null
	_flash = 0.0
	_speed = 0.0
	tooltip_text = ""
	set_process(false)
	queue_redraw()


func spin() -> void:
	_stop_tween()
	_state = State.SPINNING
	_item = null
	_rarity = null
	_flash = 0.0
	_speed = 0.0
	tooltip_text = ""
	set_process(true)


## Slow down after `delay` seconds and stop on `item`. Emits `landed` once it has.
func land_on(item: EquipmentItem, delay: float) -> void:
	if _state != State.SPINNING:
		return
	_item = item
	_stop_tween()
	_tween = create_tween()
	_tween.tween_interval(maxf(delay, 0.0))
	_tween.tween_callback(_begin_landing)


## Stop on `item` immediately, without the slowing.
func land_now(item: EquipmentItem) -> void:
	if _state == State.LANDED or _state == State.IDLE:
		return
	_item = item
	_stop_tween()
	_target_row = ceili(_scroll)
	_scroll = float(_target_row)
	_finish_landing(0.4)


func _begin_landing() -> void:
	_state = State.LANDING
	# Cubic ease-out starts at three times distance over time, so this distance
	# makes it start at the spinning speed.
	_target_row = ceili(_scroll + _speed * LAND_SECONDS / 3.0)
	_tween = create_tween()
	_tween.tween_property(self, "_scroll", float(_target_row), LAND_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_finish_landing)


func _finish_landing(flash_scale: float = 1.0) -> void:
	_state = State.LANDED
	_speed = 0.0
	_rarity = _item.get_rarity() if _item != null else null
	tooltip_text = _item.get_tooltip_text() if _item != null else ""
	_flash = flash_scale
	_tween = create_tween()
	_tween.tween_property(self, "_flash", 0.0, FLASH_SECONDS)
	_tween.tween_callback(_on_flash_done)
	# The flash needs redrawing every frame, as does a pulsing glow after it.
	set_process(true)
	landed.emit()


func _on_flash_done() -> void:
	set_process(_rarity != null and _rarity.glow_pulse)
	queue_redraw()


func _stop_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SOCKET_COLOR)
	if _state == State.IDLE:
		_draw_question()
	else:
		if _state == State.LANDED:
			_draw_glow()
		_draw_strip()
		if _state != State.LANDED:
			_draw_shade()
			_draw_marks()
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), SOCKET_EDGE, false, 2.0)
	if _state == State.LANDED:
		_draw_flash_and_frame()


func _icon_scale() -> int:
	return maxi(1, floori(minf(size.x, size.y) / float(EquipmentItem.ICON_SIZE.x + 4)))


func _draw_question() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = int(size.y * 0.45)
	var at: Vector2 = Vector2(0.0, size.y * 0.5 + font_size * 0.35)
	draw_string(
		font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, QUESTION_COLOR
	)


func _draw_strip() -> void:
	var first: int = floori(_scroll) - 1
	var last: int = ceili(_scroll) + 1
	var tint: Color = Color.WHITE
	if _state != State.LANDED:
		tint.a = BLUR_ALPHA if _speed > SPIN_SPEED * 0.5 else 1.0
	for row: int in range(first, last + 1):
		var item: EquipmentItem = _item_for_row(row)
		if item == null:
			continue
		var centre_y: float = size.y * 0.5 + (_scroll - row) * size.y
		_draw_item(item, centre_y, tint)


func _item_for_row(row: int) -> EquipmentItem:
	if _state != State.SPINNING and row == _target_row and _item != null:
		return _item
	if fillers.is_empty():
		return null
	return fillers[posmod(hash(row * 31 + _seed), fillers.size())]


func _draw_item(item: EquipmentItem, centre_y: float, tint: Color) -> void:
	var icon_scale: int = _icon_scale()
	var drawn: Vector2 = Vector2(EquipmentItem.ICON_SIZE) * icon_scale
	var origin: Vector2 = Vector2(((size.x - drawn.x) * 0.5), centre_y - drawn.y * 0.5).floor()
	for layer: Texture2D in item.get_icon_layers():
		draw_texture_rect(layer, Rect2(origin, drawn), false, tint)


## Darkens the top and bottom of the window, as if the strip curved away.
func _draw_shade() -> void:
	var band: float = floorf(size.y * 0.14)
	for i: int in 2:
		var shade: Color = SHADE_COLOR
		shade.a *= 1.0 - i * 0.45
		draw_rect(Rect2(0.0, band * i, size.x, band), shade)
		draw_rect(Rect2(0.0, size.y - band * (i + 1), size.x, band), shade)


## Gold arrows pointing at the middle row from both sides.
func _draw_marks() -> void:
	var mid: float = size.y * 0.5
	var reach: float = maxf(4.0, size.x * 0.07)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, mid - reach), Vector2(reach, mid), Vector2(0.0, mid + reach)
		]),
		MARK_COLOR
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(size.x, mid - reach), Vector2(size.x - reach, mid),
			Vector2(size.x, mid + reach)
		]),
		MARK_COLOR
	)


## The rarity's glow behind the landed item, centred.
func _draw_glow() -> void:
	if _rarity == null or _rarity.glow_strength <= 0.0:
		return
	var glow_scale: int = maxi(1, floori(minf(size.x, size.y) / RarityData.GLOW_SIZE))
	var drawn: Vector2 = Vector2.ONE * RarityData.GLOW_SIZE * glow_scale
	var glow: Color = _rarity.color
	glow.a = _rarity.glow_at(_seconds)
	draw_texture_rect(
		RarityData.glow_texture(), Rect2(((size - drawn) * 0.5).floor(), drawn), false, glow
	)


func _draw_flash_and_frame() -> void:
	if _rarity == null:
		return
	if _flash > 0.0:
		var wash: Color = _rarity.color.lerp(Color.WHITE, 0.4)
		wash.a = _flash * 0.45
		draw_rect(Rect2(Vector2.ZERO, size), wash)
	if _rarity.framed:
		var line: Vector2 = Vector2.ONE * FRAME_WIDTH * 0.5
		draw_rect(Rect2(line, size - line * 2.0), _rarity.color, false, FRAME_WIDTH)
