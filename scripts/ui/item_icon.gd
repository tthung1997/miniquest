class_name ItemIcon
extends Control
## Draws an equipment item's icon layers stacked and centred, at a whole-number
## scale so the pixel art stays crisp. Shows a faded placeholder when empty.
##
## Purely visual and ignores the mouse, so it can sit inside a cell or follow
## the cursor as a drag preview.

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

var item: EquipmentItem = null:
	set(value):
		item = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if item == null:
		if placeholder != null:
			_draw_layer(placeholder, placeholder_color)
		return
	for layer: Texture2D in item.get_icon_layers():
		_draw_layer(layer, Color.WHITE)


func _draw_layer(texture: Texture2D, tint: Color) -> void:
	var drawn: Vector2 = texture.get_size() * icon_scale
	var origin: Vector2 = ((size - drawn) * 0.5).floor()
	draw_texture_rect(texture, Rect2(origin, drawn), false, tint)
