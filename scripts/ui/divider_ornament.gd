class_name DividerOrnament
extends Control
## A thin rule with a small diamond in the middle, to set a card's title apart
## from its text. Drawn in the theme's accent colour.

const COLOR: Color = Color(1.0, 0.678, 0.333, 0.8)
const DIAMOND: float = 3.0
const GAP: float = 6.0

## Colour of the rule and diamond. The accent colour unless a card tints it.
var color: Color = COLOR:
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(0, 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var middle: Vector2 = (size * 0.5).floor() + Vector2(0.5, 0.5)
	var reach: float = DIAMOND + GAP
	draw_line(Vector2(4.0, middle.y), Vector2(middle.x - reach, middle.y), color, 1.0)
	draw_line(Vector2(middle.x + reach, middle.y), Vector2(size.x - 4.0, middle.y), color, 1.0)
	draw_colored_polygon(
		PackedVector2Array([
			middle + Vector2(0.0, -DIAMOND), middle + Vector2(DIAMOND, 0.0),
			middle + Vector2(0.0, DIAMOND), middle + Vector2(-DIAMOND, 0.0),
		]),
		color,
	)
