class_name ShelfGrid
extends GridContainer
## A grid of shop entries standing on wooden shelves: a plank runs under every
## row, at the foot of the items, with their price tags hanging below it.
##
## Each child is an entry whose first child is the item cell. The plank is
## drawn behind the entries, so they stand in front of it.

const PLANK_HEIGHT: float = 6.0
const PLANK_TOP: Color = Color(0.68, 0.48, 0.3, 1.0)
const PLANK_BODY: Color = Color(0.47, 0.31, 0.19, 1.0)
const PLANK_SHADOW: Color = Color(0.22, 0.14, 0.09, 1.0)


func _init() -> void:
	sort_children.connect(queue_redraw)


func _draw() -> void:
	var drawn: Dictionary[int, bool] = {}
	for child: Node in get_children():
		var entry: Control = child as Control
		if entry == null or not entry.visible or entry.get_child_count() == 0:
			continue
		var cell: Control = entry.get_child(0) as Control
		if cell == null:
			continue
		var y: int = roundi(entry.position.y + cell.size.y - PLANK_HEIGHT * 0.5)
		if drawn.has(y):
			continue
		drawn[y] = true
		_draw_plank(float(y))


func _draw_plank(y: float) -> void:
	draw_rect(Rect2(-2.0, y, size.x + 4.0, PLANK_HEIGHT), PLANK_BODY)
	draw_rect(Rect2(-2.0, y, size.x + 4.0, 2.0), PLANK_TOP)
	draw_rect(Rect2(-2.0, y + PLANK_HEIGHT - 1.0, size.x + 4.0, 1.0), PLANK_SHADOW)
