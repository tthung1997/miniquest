class_name Hub
extends Control
## The selected hero's home screen: the hero standing in a warm glow between
## their four equipment slots on the left, their stats beneath, and their
## inventory on the right.
##
## Items move between the inventory and the slots by drag-and-drop, by a
## right-click menu, or by activating a cell with Enter, Space or a
## double-click. Changes go through HeroData's own methods and are reported
## with hero_changed; the hub never loads or saves, the screen owner does.
## The stats panel under the hero follows every change, and leaving the hub
## with free points still waiting to be applied asks what to do with them.
## Advance opens a dialog of the classes the hero can become; the choice goes
## through HeroData.advance_to() and is reported with hero_changed like any
## other edit. Skills and Gacha are not built yet, so their tiles are locked.
## Runs standalone with an unselected portrait.

signal quest_requested
signal change_hero_requested
signal store_requested
## The shown hero's equipment, inventory or stats changed and should be saved.
signal hero_changed

enum MenuAction { EQUIP, UNEQUIP }

## Stage height in unscaled doll pixels: the full 64px frame, since a hat can
## reach its top row, plus the dais below the feet.
const STAGE_HEIGHT: float = 68.0
## Distance from the stage's bottom edge to the hero's feet, in doll pixels.
## Puts the frame's top row on the stage's top edge and leaves the dais clear
## of the bottom one.
const FEET_MARGIN: float = 11.0

## Whole-number scale keeps the pixel art crisp. 3x leaves no room for the
## stats panel under the hero on 360 lines.
@export_range(1, 3) var doll_scale: int = 2
## One inventory cell, instanced HeroData.INVENTORY_SIZE times into the grid.
@export var item_cell_scene: PackedScene

var _hero: HeroData = null
var _equipment_cells: Array[ItemCell] = []
var _inventory_cells: Array[ItemCell] = []
var _menu_cell: ItemCell = null
## What to do once the player has said what happens to waiting stat points.
var _after_leave_choice: Callable = Callable()

@onready var _stage: Control = %Stage
@onready var _doll_anchor: Node2D = %DollAnchor
@onready var _doll: PaperDoll = %PaperDoll
@onready var _name_label: Label = %NameLabel
@onready var _info_tag: ClassTag = %InfoTag
@onready var _gold_label: Label = %GoldLabel
@onready var _exp_label: Label = %ExpLabel
@onready var _count_label: Label = %CountLabel
@onready var _inventory_grid: GridContainer = %InventoryGrid
@onready var _item_menu: PopupMenu = %ItemMenu
@onready var _weapon_slot: ItemCell = %WeaponSlot
@onready var _armour_slot: ItemCell = %ArmourSlot
@onready var _boots_slot: ItemCell = %BootsSlot
@onready var _accessory_slot: ItemCell = %AccessorySlot
@onready var _stats_panel: StatsPanel = %StatsPanel
@onready var _quest_button: Button = %QuestButton
@onready var _change_hero_button: Button = %ChangeHeroButton
@onready var _store_button: Button = %StoreButton
@onready var _advance_button: Button = %AdvanceButton
@onready var _confirm_dialog: ConfirmDialog = %ConfirmDialog
@onready var _advance_dialog: AdvanceDialog = %AdvanceDialog


func _ready() -> void:
	_doll_anchor.scale = Vector2.ONE * doll_scale
	_stage.custom_minimum_size.y = STAGE_HEIGHT * doll_scale
	_stage.resized.connect(_place_doll)
	_quest_button.pressed.connect(_on_quest_pressed)
	_change_hero_button.pressed.connect(_on_change_hero_pressed)
	_store_button.pressed.connect(_on_store_pressed)
	_advance_button.pressed.connect(_on_advance_pressed)
	_advance_dialog.class_chosen.connect(_on_class_chosen)
	_advance_dialog.closed.connect(_advance_button.grab_focus)
	_item_menu.id_pressed.connect(_on_menu_id_pressed)
	_stats_panel.points_applied.connect(_on_points_applied)
	_confirm_dialog.confirmed.connect(_on_leave_apply_chosen)
	_confirm_dialog.cancelled.connect(_on_leave_discard_chosen)

	_equipment_cells = [_weapon_slot, _armour_slot, _boots_slot, _accessory_slot]
	for cell: ItemCell in _equipment_cells:
		cell.locked = not HeroData.supports_slot(cell.slot)
		_connect_cell(cell)
	_build_inventory()

	_place_doll()
	_refresh()
	_focus_default()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_leave(_request_change_hero)


## Can be called before ready, or when updating the visible hero.
func show_hero(hero: HeroData) -> void:
	if hero == null:
		push_error("Hub: cannot display an empty hero.")
		return
	_hero = hero
	if is_node_ready():
		_refresh()
		_focus_default()


func _build_inventory() -> void:
	if item_cell_scene == null:
		push_error("Hub: item_cell_scene must be wired to show the inventory.")
		return
	for i in HeroData.INVENTORY_SIZE:
		var node: Node = item_cell_scene.instantiate()
		if node is not ItemCell:
			push_error("Hub: item_cell_scene must have an ItemCell root.")
			node.free()
			return
		var cell: ItemCell = node
		_inventory_grid.add_child(cell)
		_connect_cell(cell)
		_inventory_cells.append(cell)


func _connect_cell(cell: ItemCell) -> void:
	cell.activated.connect(_on_cell_activated)
	cell.context_requested.connect(_on_cell_context_requested)
	cell.item_dropped.connect(_on_cell_item_dropped)


func _refresh() -> void:
	_quest_button.disabled = _hero == null
	_stats_panel.show_hero(_hero)
	_refresh_items()
	_refresh_advance_button()
	if _hero == null:
		_name_label.text = "No hero selected"
		_info_tag.show_text("Choose a hero to start")
		_gold_label.text = "--"
		_exp_label.text = "--"
		_doll.wear_armour(null)
		_doll.wear_boots(null)
		_doll.wield(null)
		return

	var hero_class: ClassData = _hero.class_data()
	var class_text: String = (
		hero_class.display_name if hero_class != null else String(_hero.class_id)
	)
	_name_label.text = _hero.hero_name
	_info_tag.show_text(
		"Lv %d  %s" % [_hero.level, class_text],
		hero_class.icon if hero_class != null else null
	)
	_gold_label.text = str(_hero.gold)
	var progress: Vector2i = Levelling.progress(_hero.experience)
	_exp_label.text = "MAX" if progress.y == 0 else "%d/%d" % [progress.x, progress.y]
	_doll.wear_armour(_hero.armour)
	_doll.wear_boots(_hero.boots)
	_doll.wield(_hero.weapon)


## The button is disabled when there is nothing to advance into, and gets an
## exclamation mark when the hero can take a class right now.
func _refresh_advance_button() -> void:
	var options: Array[ClassData] = _hero.advancement_options() if _hero != null else []
	var ready_now: bool = false
	for option: ClassData in options:
		if _hero.can_advance_to(option):
			ready_now = true
			break
	_advance_button.disabled = options.is_empty()
	_advance_button.text = "ADVANCE!" if ready_now else "ADVANCE"
	_advance_button.tooltip_text = (
		"Choose a new class" if ready_now
		else "Advance to a new class" if not options.is_empty()
		else "No further classes yet"
	)


func _refresh_items() -> void:
	for cell: ItemCell in _equipment_cells:
		cell.item = _hero.equipped(cell.slot) if _hero != null else null

	var carried: Array[EquipmentItem] = []
	if _hero != null:
		carried = _hero.inventory
	for i in _inventory_cells.size():
		_inventory_cells[i].item = carried[i] if i < carried.size() else null

	_count_label.text = "%d/%d" % [carried.size(), HeroData.INVENTORY_SIZE]
	var full: bool = carried.size() >= HeroData.INVENTORY_SIZE
	_count_label.theme_type_variation = &"AccentLabel" if full else &"MutedLabel"


func _focus_default() -> void:
	if _hero == null:
		_change_hero_button.grab_focus()
	else:
		_quest_button.grab_focus()


func _place_doll() -> void:
	_doll_anchor.position = Vector2(
		roundf(_stage.size.x * 0.5), roundf(_stage.size.y - FEET_MARGIN * doll_scale)
	)


func _equip(item: EquipmentItem) -> void:
	if _hero == null or not _hero.can_equip(item):
		return
	if _hero.equip(item):
		_on_hero_edited()


## Refused quietly when the inventory is full; the count shows why.
func _unequip(slot: EquipmentItem.Slot) -> void:
	if _hero == null or not _hero.can_unequip(slot):
		return
	if _hero.unequip(slot):
		_on_hero_edited()


func _on_hero_edited() -> void:
	_refresh()
	hero_changed.emit()


func _on_cell_activated(cell: ItemCell) -> void:
	if cell.is_equipment_slot:
		_unequip(cell.slot)
	else:
		_equip(cell.item)


func _on_cell_context_requested(cell: ItemCell) -> void:
	if _hero == null or cell.item == null:
		return
	_menu_cell = cell
	_item_menu.clear()
	if cell.is_equipment_slot:
		_item_menu.add_item("Unequip", MenuAction.UNEQUIP)
		_item_menu.set_item_disabled(0, not _hero.can_unequip(cell.slot))
		if _hero.is_inventory_full():
			_item_menu.set_item_tooltip(0, "Inventory full")
	else:
		_item_menu.add_item("Equip", MenuAction.EQUIP)
		_item_menu.set_item_disabled(0, not _hero.can_equip(cell.item))
	_item_menu.reset_size()
	_item_menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))


func _on_menu_id_pressed(id: int) -> void:
	var cell: ItemCell = _menu_cell
	_menu_cell = null
	if cell == null:
		return
	match id:
		MenuAction.EQUIP:
			_equip(cell.item)
		MenuAction.UNEQUIP:
			_unequip(cell.slot)


## A drop onto a slot wears the item. A drop onto an inventory cell takes the
## slot's item off, swapping it with the cell's item when there is one.
func _on_cell_item_dropped(cell: ItemCell, item: EquipmentItem) -> void:
	if cell.is_equipment_slot:
		_equip(item)
	elif cell.item != null:
		_equip(cell.item)
	else:
		_unequip(item.get_slot())


func _on_quest_pressed() -> void:
	_leave(_request_quest)


func _on_change_hero_pressed() -> void:
	_leave(_request_change_hero)


func _on_store_pressed() -> void:
	_leave(_request_store)


func _on_advance_pressed() -> void:
	if _hero == null:
		return
	var note: String = ""
	if _stats_panel.has_pending():
		note = "Apply your waiting stat points first: only spent points count."
	_advance_dialog.open(_hero, note)


func _on_class_chosen(class_id: StringName) -> void:
	if _hero == null or not _hero.advance_to(class_id):
		return
	_on_hero_edited()
	_focus_default()


func _request_store() -> void:
	store_requested.emit()


func _request_quest() -> void:
	quest_requested.emit()


func _request_change_hero() -> void:
	change_hero_requested.emit()


func _on_points_applied() -> void:
	hero_changed.emit()


## Run `action` now, or once the player has chosen what happens to stat points
## they have staged but not applied.
func _leave(action: Callable) -> void:
	if _hero == null or not _stats_panel.has_pending():
		action.call()
		return
	_after_leave_choice = action
	var count: int = _stats_panel.pending_total()
	_confirm_dialog.open(
		"Apply %d stat point%s before leaving?" % [count, "" if count == 1 else "s"],
		"APPLY",
		"DISCARD"
	)


func _on_leave_apply_chosen() -> void:
	_stats_panel.apply()
	_finish_leave()


func _on_leave_discard_chosen() -> void:
	_stats_panel.discard()
	_finish_leave()


func _finish_leave() -> void:
	var action: Callable = _after_leave_choice
	_after_leave_choice = Callable()
	if action.is_valid():
		action.call()
