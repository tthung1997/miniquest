class_name MarqueeFrame
extends Control
## A border of light bulbs, like a slot machine's, drawn around its own edge.
##
## Idle, the lights chase slowly; `set_mode()` speeds them up while the machine
## spins and, once it has paid out, makes them all blink in the colour of the
## prize. Draws only, and ignores the mouse, so it can sit behind other nodes.

enum Mode { IDLE, SPINNING, CELEBRATING }

## Gap between bulbs along the edge, in pixels, and a bulb's side.
const SPACING: float = 10.0
const BULB: float = 4.0
## Distance from this control's edge to the middle of the bulbs.
const INSET: float = 4.0
const OFF_COLOR: Color = Color(0.35, 0.22, 0.12, 1.0)
const ON_COLOR: Color = Color(1.0, 0.85, 0.4, 1.0)
const EDGE_COLOR: Color = Color(0.1, 0.06, 0.03, 1.0)
## Bulbs a second that the chase moves, per mode.
const CHASE_SPEEDS: Dictionary[Mode, float] = {
	Mode.IDLE: 3.0, Mode.SPINNING: 14.0, Mode.CELEBRATING: 6.0
}

var _mode: Mode = Mode.IDLE
var _color: Color = ON_COLOR
var _phase: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_phase += delta * CHASE_SPEEDS[_mode]
	queue_redraw()


## Light the bulbs in `mode`. Celebrating blinks them in `color`.
func set_mode(mode: Mode, color: Color = ON_COLOR) -> void:
	_mode = mode
	_color = color if mode == Mode.CELEBRATING else ON_COLOR


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ONE * INSET, size - Vector2.ONE * INSET * 2.0)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points: PackedVector2Array = _bulb_positions(rect)
	for i: int in points.size():
		var lit: bool = _is_lit(i)
		var colour: Color = _color if lit else OFF_COLOR
		var corner: Vector2 = (points[i] - Vector2.ONE * BULB * 0.5).floor()
		draw_rect(Rect2(corner - Vector2.ONE, Vector2.ONE * (BULB + 2.0)), EDGE_COLOR)
		draw_rect(Rect2(corner, Vector2.ONE * BULB), colour)
		if lit:
			draw_rect(Rect2(corner, Vector2.ONE * 2.0), colour.lerp(Color.WHITE, 0.6))


func _is_lit(index: int) -> bool:
	if _mode == Mode.CELEBRATING:
		return (floori(_phase) + index % 2) % 2 == 0
	return (index + floori(_phase)) % 3 == 0


## Bulbs evenly spaced round `rect`, clockwise from its top-left corner.
func _bulb_positions(rect: Rect2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var across: int = maxi(roundi(rect.size.x / SPACING), 1)
	var down: int = maxi(roundi(rect.size.y / SPACING), 1)
	for i: int in across:
		points.append(rect.position + Vector2(rect.size.x * i / across, 0.0))
	for i: int in down:
		points.append(rect.position + Vector2(rect.size.x, rect.size.y * i / down))
	for i: int in across:
		points.append(rect.end - Vector2(rect.size.x * i / across, 0.0))
	for i: int in down:
		points.append(rect.end - Vector2(0.0, rect.size.y * i / down) - Vector2(rect.size.x, 0.0))
	return points
