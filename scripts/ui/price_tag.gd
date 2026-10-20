class_name PriceTag
extends Control
## A paper price tag hanging under a shelf item: a coin and the price, in red
## when the player cannot afford it, or green when it is what a sale pays.
##
## Shows what it is told. `flash()` swaps the price for a word, such as SOLD,
## for a moment.

const COIN: Texture2D = preload("res://assets/packs/ninja_adventure/items/gold_coin.png")
const PAPER: Color = Color(0.93, 0.86, 0.68, 1.0)
const EDGE: Color = Color(0.3, 0.18, 0.1, 1.0)
const STRING_COLOR: Color = Color(0.3, 0.18, 0.1, 1.0)
const INK: Color = Color(0.28, 0.16, 0.08, 1.0)
const SHORT_INK: Color = Color(0.72, 0.15, 0.1, 1.0)
const PAYS_INK: Color = Color(0.15, 0.45, 0.12, 1.0)
const COIN_SIZE: float = 9.0
## Height of the string above the tag.
const STRING_HEIGHT: float = 4.0
## Seconds a flashed word stays up.
const FLASH_SECONDS: float = 0.9

var price: int = 0:
	set(value):
		price = value
		queue_redraw()
## Whether the player can pay it. A tag that is not shown in red.
var affordable: bool = true:
	set(value):
		affordable = value
		queue_redraw()
## Whether the price is gold coming in, as on the sell tab, rather than going out.
var pays: bool = false:
	set(value):
		pays = value
		queue_redraw()

var _flash_text: String = ""
var _flash_tween: Tween = null


func _init() -> void:
	custom_minimum_size = Vector2(48, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Show `text` in place of the price for a moment.
func flash(text: String) -> void:
	_flash_text = text
	queue_redraw()
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(FLASH_SECONDS)
	_flash_tween.tween_callback(_end_flash)


func _end_flash() -> void:
	_flash_text = ""
	queue_redraw()


func _draw() -> void:
	var tag: Rect2 = Rect2(3.0, STRING_HEIGHT, size.x - 6.0, size.y - STRING_HEIGHT)
	draw_rect(Rect2(size.x * 0.5, 0.0, 1.0, STRING_HEIGHT + 2.0), STRING_COLOR)
	draw_rect(Rect2(tag.position - Vector2.ONE, tag.size + Vector2.ONE * 2.0), EDGE)
	draw_rect(tag, PAPER)
	draw_rect(Rect2(size.x * 0.5 - 1.0, tag.position.y + 1.0, 3.0, 3.0), EDGE)

	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	var ink: Color = INK
	if pays:
		ink = PAYS_INK
	elif not affordable:
		ink = SHORT_INK
	var baseline: float = tag.end.y - (tag.size.y - STRING_HEIGHT + 2.0 - font_size) * 0.5 - 1.0
	if not _flash_text.is_empty():
		draw_string(
			font, Vector2(tag.position.x, baseline), _flash_text, HORIZONTAL_ALIGNMENT_CENTER,
			tag.size.x, font_size, PAYS_INK
		)
		return
	var text: String = ("+" if pays else "") + str(price)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var total: float = COIN_SIZE + 2.0 + text_width
	var left: float = tag.position.x + floorf((tag.size.x - total) * 0.5)
	draw_texture_rect(
		COIN, Rect2(left, baseline - COIN_SIZE + 1.0, COIN_SIZE, COIN_SIZE), false
	)
	draw_string(
		font, Vector2(left + COIN_SIZE + 2.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, ink
	)
