class_name ItemCell
extends Button
## One place an equipment item can sit: an inventory cell, or one of the hero's
## equipment slots.
##
## Shows its item and reports what the player asks of it: dragging it onto
## another cell, right-clicking it, or activating it with Enter, Space or a
## double-click. It never changes hero data itself; the screen that owns it
## decides what each request means. Whether a drop is allowed depends only on
## the two cells involved, so that is answered here.
##
## Mouse clicks do not press the button (button_mask is empty), so a single
## click only focuses the cell and a drag can start cleanly.

signal activated(cell: ItemCell)
signal context_requested(cell: ItemCell)
## `item` was dropped onto `cell` from another cell.
signal item_dropped(cell: ItemCell, item: EquipmentItem)

## An equipment slot accepts inventory items for its slot. An inventory cell
## accepts items dragged off an equipment slot.
@export var is_equipment_slot: bool = false
## The slot this cell represents. Only meaningful for equipment slots.
@export var slot: EquipmentItem.Slot = EquipmentItem.Slot.ARMOUR
## Silhouette shown while the cell is empty.
@export var placeholder: Texture2D
## Opacity of an empty inventory cell's socket, so filled cells stand out.
## Equipment slots stay solid; their silhouettes already read as empty.
@export_range(0.0, 1.0, 0.05) var empty_opacity: float = 0.5

var item: EquipmentItem = null:
	set(value):
		item = value
		if is_node_ready():
			_refresh()
## A locked cell shows its placeholder but takes no focus, drags or drops.
var locked: bool = false:
	set(value):
		locked = value
		if is_node_ready():
			_refresh()

var _drop_hint: bool = false

@onready var _icon: ItemIcon = %Icon


func _ready() -> void:
	pressed.connect(_on_pressed)
	_icon.placeholder = placeholder
	_refresh()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			var data: Variant = get_viewport().gui_get_drag_data()
			var dragging_this: bool = data is ItemCell and data == self
			_icon.modulate.a = 0.4 if dragging_this else 1.0
			_set_drop_hint(data is ItemCell and can_accept(data))
		NOTIFICATION_DRAG_END:
			_icon.modulate.a = 1.0
			_set_drop_hint(false)


func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var click: InputEventMouseButton = event
	if not click.pressed or item == null or locked:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		grab_focus()
		context_requested.emit(self)
	elif click.button_index == MOUSE_BUTTON_LEFT and click.double_click:
		accept_event()
		activated.emit(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null or locked:
		return null
	set_drag_preview(_make_drag_preview())
	return self


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is ItemCell and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source: ItemCell = data
	item_dropped.emit(self, source.item)


func _draw() -> void:
	if _drop_hint:
		var inset: Vector2 = Vector2.ONE * get_theme_constant(&"drop_hint_inset")
		draw_style_box(get_theme_stylebox(&"drop_hint"), Rect2(inset, size - inset * 2.0))


## Whether `source`'s item may be dropped here. Inventory to inventory is not a
## move: the inventory stays packed, so there is nothing to rearrange.
func can_accept(source: ItemCell) -> bool:
	if source == self or source.item == null or locked:
		return false
	if is_equipment_slot:
		return not source.is_equipment_slot and source.item.get_slot() == slot
	if not source.is_equipment_slot:
		return false
	return item == null or item.get_slot() == source.item.get_slot()


func _refresh() -> void:
	_icon.item = item
	# self_modulate fades only this button's socket, not the icon child.
	var faded: bool = item == null and not is_equipment_slot and not _drop_hint
	self_modulate.a = empty_opacity if faded else 1.0
	disabled = locked
	focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	tooltip_text = _tooltip()


func _tooltip() -> String:
	if item != null:
		return item.get_display_name()
	if not is_equipment_slot:
		return ""
	var slot_text: String = EquipmentItem.slot_name(slot)
	return "%s - coming soon" % slot_text if locked else "%s - empty" % slot_text


func _make_drag_preview() -> Control:
	var preview: ItemIcon = ItemIcon.new()
	preview.item = item
	preview.size = Vector2(EquipmentItem.ICON_SIZE * preview.icon_scale)
	preview.position = -preview.size * 0.5
	# Wrapped so the icon can be centred on the cursor, which the preview's
	# own position cannot do: it is pinned to the cursor at its origin.
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	return holder


func _set_drop_hint(show_hint: bool) -> void:
	if show_hint == _drop_hint:
		return
	_drop_hint = show_hint
	_refresh()
	queue_redraw()


func _on_pressed() -> void:
	if item != null and not locked:
		activated.emit(self)
