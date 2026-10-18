class_name SkillFrame
extends Control
## A skill's icon in a square frame with chamfered corners: the same look in the
## skill tree, on the run's skill bar and on level-up cards. It only draws what
## it is told; clicks and keys belong to whoever holds it.
##
## The icon is 16x16 art drawn at `icon_scale` times its size, so it stays crisp.

const ICON_SIZE: int = 16
const CHAMFER: float = 2.0
const FILL: Color = Color("2a1b14")
const BORDER: Color = Color("ffad55")
const BORDER_LOCKED: Color = Color("6e6357")
const BORDER_SELECTED: Color = Color("fff3d6")
const LOCKED_TINT: Color = Color(0.32, 0.32, 0.38, 1.0)
const COOLDOWN_SHADE: Color = Color(0.0, 0.0, 0.0, 0.62)

@export var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
@export_range(1, 4) var icon_scale: int = 1:
	set(value):
		icon_scale = value
		_update_size()
@export_range(0, 8) var padding: int = 2:
	set(value):
		padding = value
		_update_size()
## Not yet unlocked: dimmed, with a padlock.
@export var locked: bool = false:
	set(value):
		locked = value
		queue_redraw()
## Drawn with a bright border, as the picked skill in the tree.
@export var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## Drawn at the frame's bottom-right, such as a level.
@export var badge: String = "":
	set(value):
		badge = value
		queue_redraw()
@export var badge_color: Color = Color.WHITE:
	set(value):
		badge_color = value
		queue_redraw()
## Fraction of a cooldown still to run, shading the icon from the top down.
## Zero is ready.
@export_range(0.0, 1.0, 0.01) var cooldown: float = 0.0:
	set(value):
		if not is_equal_approx(value, cooldown):
			cooldown = value
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_update_size()


func _draw() -> void:
	var outline: PackedVector2Array = _outline()
	draw_colored_polygon(outline, FILL)
	var inner: Rect2 = Rect2(
		Vector2(padding, padding), Vector2.ONE * (ICON_SIZE * icon_scale)
	)
	if icon != null:
		draw_texture_rect(icon, inner, false, LOCKED_TINT if locked else Color.WHITE)
	if locked:
		_draw_padlock(inner)
	elif cooldown > 0.0:
		var shade: Rect2 = Rect2(inner.position, Vector2(inner.size.x, inner.size.y * cooldown))
		draw_rect(shade, COOLDOWN_SHADE)
	var border: Color = BORDER_SELECTED if selected else BORDER_LOCKED if locked else BORDER
	outline.append(outline[0])
	draw_polyline(outline, border, 2.0 if selected else 1.0)
	if not badge.is_empty():
		var font: Font = get_theme_default_font()
		var font_size: int = get_theme_default_font_size()
		var text_size: Vector2 = font.get_string_size(
			badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		)
		var at: Vector2 = Vector2(size.x - text_size.x - 3.0, size.y - 3.0)
		var shadow_at: Vector2 = at + Vector2.ONE
		draw_string(
			font, shadow_at, badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK
		)
		draw_string(font, at, badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, badge_color)


func _update_size() -> void:
	custom_minimum_size = Vector2.ONE * (ICON_SIZE * icon_scale + padding * 2)
	queue_redraw()


## The frame's shape: a square with its corners cut off, drawn half a pixel in
## so a one-pixel border stays inside the control.
func _outline() -> PackedVector2Array:
	var left: float = 0.5
	var top: float = 0.5
	var right: float = size.x - 0.5
	var bottom: float = size.y - 0.5
	return PackedVector2Array([
		Vector2(left + CHAMFER, top), Vector2(right - CHAMFER, top),
		Vector2(right, top + CHAMFER), Vector2(right, bottom - CHAMFER),
		Vector2(right - CHAMFER, bottom), Vector2(left + CHAMFER, bottom),
		Vector2(left, bottom - CHAMFER), Vector2(left, top + CHAMFER),
	])


func _draw_padlock(inner: Rect2) -> void:
	var unit: float = float(icon_scale)
	var centre: Vector2 = inner.get_center()
	var body: Rect2 = Rect2(centre + Vector2(-3.0, 0.0) * unit, Vector2(6.0, 5.0) * unit)
	draw_rect(body, Color("c9b79c"))
	draw_rect(Rect2(body.position + Vector2(2.0, 1.5) * unit, Vector2(2.0, 2.0) * unit), FILL)
	draw_arc(
		centre + Vector2(0.0, 0.0), 2.0 * unit, PI, TAU, 8, Color("c9b79c"), maxf(unit, 1.0)
	)
