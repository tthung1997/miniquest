class_name ThreatIndicators
extends Control
## Arrows on the screen's edge pointing at enemies that are out of view, so a
## camera that follows the hero does not hide what is coming (DESIGN.md 6.2).
##
## Enemies in the same direction share one arrow, which grows and brightens with
## how many there are and how close the nearest is, so fifty enemies stay
## readable. The elite always gets its own larger arrow. Takes its enemies from
## the director it is wired to and never reaches up the tree.

## Directions are grouped into this many slices of the circle.
const SLICES: int = 16
## How far inside the screen's edge an arrow sits.
const EDGE_MARGIN: float = 14.0
## Enemies farther than this off-screen are too far away to warn about.
const MAX_RANGE: float = 700.0
const ARROW_COLOR: Color = Color(1.0, 0.45, 0.25)
const ELITE_COLOR: Color = Color(1.0, 0.15, 0.15)
const ARROW_SIZE: float = 6.0
const ELITE_SIZE: float = 11.0

@export var director: RunDirector

var _counts: PackedInt32Array = PackedInt32Array()
var _nearest: PackedFloat32Array = PackedFloat32Array()
var _elites: Array[Vector2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counts.resize(SLICES)
	_nearest.resize(SLICES)


func _process(_delta: float) -> void:
	if director == null:
		return
	_gather()
	queue_redraw()


func _gather() -> void:
	_counts.fill(0)
	_nearest.fill(INF)
	_elites.clear()
	var view: Rect2 = Rect2(Vector2.ZERO, size)
	var centre: Vector2 = view.get_center()
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	for enemy: Enemy in director.enemies:
		var at: Vector2 = to_screen * enemy.global_position
		if view.has_point(at):
			continue
		var offset: Vector2 = at - centre
		var outside: float = _distance_outside(view, at)
		if enemy.data.is_elite:
			_elites.append(offset)
			continue
		if outside > MAX_RANGE:
			continue
		var slice: int = posmod(roundi(offset.angle() / TAU * SLICES), SLICES)
		_counts[slice] += 1
		_nearest[slice] = minf(_nearest[slice], outside)


func _draw() -> void:
	var centre: Vector2 = size * 0.5
	for slice: int in SLICES:
		if _counts[slice] == 0:
			continue
		var direction: Vector2 = Vector2.from_angle(slice * TAU / SLICES)
		var crowd: float = clampf(_counts[slice] / 6.0, 0.0, 1.0)
		var closeness: float = 1.0 - clampf(_nearest[slice] / MAX_RANGE, 0.0, 1.0)
		var color: Color = ARROW_COLOR
		color.a = lerpf(0.35, 0.95, closeness)
		_arrow(centre, direction, ARROW_SIZE * lerpf(0.8, 1.6, crowd), color)
	for offset: Vector2 in _elites:
		_arrow(centre, offset.normalized(), ELITE_SIZE, ELITE_COLOR)


## A triangle at the screen's edge in `direction` from the centre.
func _arrow(centre: Vector2, direction: Vector2, length: float, color: Color) -> void:
	var half: Vector2 = size * 0.5 - Vector2.ONE * (EDGE_MARGIN + length)
	var scale_to_edge: float = minf(
		half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001)
	)
	var tip: Vector2 = centre + direction * scale_to_edge + direction * length
	var base: Vector2 = tip - direction * length * 1.6
	var side: Vector2 = direction.orthogonal() * length * 0.8
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), color)


## How far `point` is beyond the nearest edge of `view`.
func _distance_outside(view: Rect2, point: Vector2) -> float:
	var dx: float = maxf(maxf(view.position.x - point.x, point.x - view.end.x), 0.0)
	var dy: float = maxf(maxf(view.position.y - point.y, point.y - view.end.y), 0.0)
	return Vector2(dx, dy).length()
