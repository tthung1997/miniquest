class_name ItemIcon
extends Control
## Draws an equipment item's icon layers stacked and centred, at a whole-number
## scale so the pixel art stays crisp. Shows a faded placeholder when empty.
##
## Purely visual and ignores the mouse, so it can sit inside a cell or follow
## the cursor as a drag preview. Its material recolours the art for the item's
## rarity, so it never draws the rarity frame, which would be recoloured too.

@export_range(1, 4) var icon_scale: int = 2:
	set(value):
		icon_scale = value
		queue_redraw()
## Drawn when there is no item, such as the silhouette of an empty slot.
@export var placeholder: Texture2D:
	set(value):
		placeholder = value
		queue_redraw()
@export var placeholder_color: Color = Color(1.0, 1.0, 1.0, 0.3):
	set(value):
		placeholder_color = value
		queue_redraw()
## Centre each layer's drawn pixels instead of its whole canvas. For an item
## whose layers sit in fixed zones, such as one armour piece shown alone, which
## would otherwise hang at the top or bottom of the cell.
@export var center_content: bool = false:
	set(value):
		center_content = value
		queue_redraw()

var item: EquipmentItem = null:
	set(value):
		item = value
		material = item.get_rarity().get_tint_material() if item != null else null
		queue_redraw()

var _used_rects: Dictionary[Texture2D, Rect2] = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if item == null:
		if placeholder != null:
			_draw_layer(placeholder, placeholder_color, false)
		return
	for layer: Texture2D in item.get_icon_layers():
		_draw_layer(layer, Color.WHITE, center_content)


func _draw_layer(texture: Texture2D, tint: Color, centre_pixels: bool) -> void:
	var source: Rect2 = Rect2(Vector2.ZERO, texture.get_size())
	if centre_pixels:
		source = _used_rect(texture)
	var drawn: Vector2 = source.size * icon_scale
	var origin: Vector2 = ((size - drawn) * 0.5).floor()
	draw_texture_rect_region(texture, Rect2(origin, drawn), source, tint)


## The part of `texture` that is not transparent, remembered per texture.
func _used_rect(texture: Texture2D) -> Rect2:
	if not _used_rects.has(texture):
		var image: Image = texture.get_image()
		var used: Rect2i = image.get_used_rect() if image != null else Rect2i()
		if used.size == Vector2i.ZERO:
			used = Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
		_used_rects[texture] = Rect2(used)
	return _used_rects[texture]
