class_name ShopAwning
extends Control
## A striped canvas awning with a scalloped edge, over the top of the shelves.
##
## Draws only. `set_stripes()` changes its two colours, so each tab of the store
## can have its own.

## Width of one stripe, and the pixel rows of the scallop: each row's inset
## from both sides of a stripe, top to bottom, which rounds its bottom.
const STRIPE_WIDTH: int = 14
const SCALLOP_INSETS: Array[int] = [0, 0, 1, 2, 4]
const TRIM_HEIGHT: float = 2.0
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.25)

var _first: Color = Color(0.78, 0.22, 0.18, 1.0)
var _second: Color = Color(0.95, 0.9, 0.78, 1.0)


func _init() -> void:
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Draw the awning in `first` and `second` stripes.
func set_stripes(first: Color, second: Color) -> void:
	_first = first
	_second = second
	queue_redraw()


func _draw() -> void:
	var rows: int = SCALLOP_INSETS.size()
	var body: float = size.y - rows
	var stripes: int = ceili(size.x / STRIPE_WIDTH)
	for i: int in stripes:
		var colour: Color = _first if i % 2 == 0 else _second
		var left: float = float(i * STRIPE_WIDTH)
		var width: float = minf(float(STRIPE_WIDTH), size.x - left)
		draw_rect(Rect2(left, 0.0, width, body), colour)
		for row: int in rows:
			var inset: float = float(SCALLOP_INSETS[row]) if width >= STRIPE_WIDTH else 0.0
			var y: float = body + row
			draw_rect(Rect2(left + inset, y + 1.0, width - inset * 2.0, 1.0), SHADOW)
			draw_rect(Rect2(left + inset, y, width - inset * 2.0, 1.0), colour)
	draw_rect(Rect2(0.0, 0.0, size.x, TRIM_HEIGHT), _first.darkened(0.35))
