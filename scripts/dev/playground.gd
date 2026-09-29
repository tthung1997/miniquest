class_name Playground
extends Node2D
## Walkable test area for driving the hero around with the keyboard.
##
## The room is deliberately larger than the 640x360 viewport so the camera has
## something to follow and its limits are actually exercised. Not shipped game
## code; it exists to check movement, facing and animation switching by hand.

const ROOM: Rect2i = Rect2i(0, 0, 1120, 630)
const WALL: int = 16
const FLOOR_COLOR: Color = Color(0.16, 0.18, 0.22)
const WALL_COLOR: Color = Color(0.28, 0.31, 0.38)
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.05)
const GRID_STEP: int = 64

@onready var hero: Hero = $Hero
@onready var _readout: Label = $HUD/Root/Readout


func _ready() -> void:
	_build_walls()
	hero.position = Vector2(ROOM.size) * 0.5
	hero.facing_changed.connect(_on_hero_facing_changed)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(ROOM), FLOOR_COLOR, true)

	for x in range(GRID_STEP, ROOM.size.x, GRID_STEP):
		draw_line(Vector2(x, 0), Vector2(x, ROOM.size.y), GRID_COLOR, 1.0)
	for y in range(GRID_STEP, ROOM.size.y, GRID_STEP):
		draw_line(Vector2(0, y), Vector2(ROOM.size.x, y), GRID_COLOR, 1.0)

	var w: float = float(WALL)
	var sx: float = float(ROOM.size.x)
	var sy: float = float(ROOM.size.y)
	draw_rect(Rect2(0.0, 0.0, sx, w), WALL_COLOR, true)
	draw_rect(Rect2(0.0, sy - w, sx, w), WALL_COLOR, true)
	draw_rect(Rect2(0.0, 0.0, w, sy), WALL_COLOR, true)
	draw_rect(Rect2(sx - w, 0.0, w, sy), WALL_COLOR, true)


func _build_walls() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = &"Walls"
	add_child(body)

	var w: float = float(WALL)
	var sx: float = float(ROOM.size.x)
	var sy: float = float(ROOM.size.y)
	var spans: Array[Rect2] = [
		Rect2(0.0, 0.0, sx, w),
		Rect2(0.0, sy - w, sx, w),
		Rect2(0.0, 0.0, w, sy),
		Rect2(sx - w, 0.0, w, sy),
	]

	for span: Rect2 in spans:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = span.size
		var collider: CollisionShape2D = CollisionShape2D.new()
		collider.shape = shape
		collider.position = span.position + span.size * 0.5
		body.add_child(collider)


func _on_hero_facing_changed(_facing_right: bool) -> void:
	_refresh()


func _refresh() -> void:
	_readout.text = (
		"pos %d, %d    speed %d    facing %s\nWASD or arrows to move"
		% [
			roundi(hero.position.x),
			roundi(hero.position.y),
			roundi(hero.velocity.length()),
			"right" if hero.is_facing_right() else "left",
		]
	)
