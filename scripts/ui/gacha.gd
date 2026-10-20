class_name Gacha
extends Control
## The gacha screen: pull gear from packs for gold, and merge spare items into
## better ones.
##
## Packs tab: pick a pack, see its odds and how close the hero is to its
## guaranteed Legendary, then pull once or ten at a time (the ten-pull is
## cheaper per pull). Merge tab: tick items of one rarity in the inventory
## and turn them into one random item a rarity higher. What comes out of
## either is shown on the right.
##
## Changes the hero through GachaMachine and ItemMerge, and reports it with
## hero_changed for the screen owner to save. Runs standalone with a throwaway
## hero.

signal back_requested
## The hero pulled or merged and should be saved.
signal hero_changed

enum Tab { PACKS, MERGE }

const RESULT_COLUMNS: int = 5
const MERGE_COLUMNS: int = 5
## Gold of the throwaway hero this screen makes when run on its own.
const TESTER_GOLD: int = 20000
const NO_PACKS: String = "No packs are for sale"
const EMPTY_RESULT: String = "Pull a pack or merge items to see what you get."

## One item cell, instanced for every item shown.
@export var item_cell_scene: PackedScene

var _hero: HeroData = null
var _tab: Tab = Tab.PACKS
var _packs: Array[PackData] = []
var _pack: PackData = null
var _merge_cells: Array[ItemCell] = []

@onready var _back_button: Button = %BackButton
@onready var _gold_label: Label = %GoldLabel
@onready var _packs_tab: Button = %PacksTab
@onready var _merge_tab: Button = %MergeTab
@onready var _packs_view: Control = %PacksView
@onready var _merge_view: Control = %MergeView
@onready var _pack_row: HBoxContainer = %PackRow
@onready var _pack_title: Label = %PackTitle
@onready var _pack_description: Label = %PackDescription
@onready var _odds_box: VBoxContainer = %OddsBox
@onready var _pity_label: Label = %PityLabel
@onready var _pull_one_button: Button = %PullOneButton
@onready var _pull_ten_button: Button = %PullTenButton
@onready var _message_label: Label = %MessageLabel
@onready var _merge_hint: Label = %MergeHint
@onready var _merge_grid: GridContainer = %MergeGrid
@onready var _merge_count_label: Label = %MergeCountLabel
@onready var _merge_button: Button = %MergeButton
@onready var _result_summary: Label = %ResultSummary
@onready var _result_grid: GridContainer = %ResultGrid
@onready var _inventory_label: Label = %InventoryLabel


func _ready() -> void:
	_back_button.pressed.connect(back_requested.emit)
	_packs_tab.toggled.connect(_on_tab_toggled.bind(Tab.PACKS))
	_merge_tab.toggled.connect(_on_tab_toggled.bind(Tab.MERGE))
	_pull_one_button.pressed.connect(_on_pull_pressed.bind(1))
	_pull_ten_button.pressed.connect(_on_pull_pressed.bind(PackData.MULTI_PULL))
	_merge_button.pressed.connect(_on_merge_pressed)
	_result_grid.columns = RESULT_COLUMNS
	_merge_grid.columns = MERGE_COLUMNS

	if _hero == null:
		_hero = HeroData.create("Tester")
		if _hero == null:
			return
		_hero.gold = TESTER_GOLD
	_packs = PackData.all()
	_build_pack_buttons()
	_show_tab(Tab.PACKS)
	_show_result_text(EMPTY_RESULT)
	_refresh_hero()
	_pull_one_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()


## Show the gacha to `hero`, whose gold, packs and inventory are used. Can be
## called before ready.
func show_hero(hero: HeroData) -> void:
	if hero == null:
		push_error("Gacha: cannot open for an empty hero.")
		return
	_hero = hero
	if is_node_ready():
		_refresh_hero()


func _refresh_hero() -> void:
	_gold_label.text = str(_hero.gold)
	_inventory_label.text = "Inventory %d/%d" % [_hero.inventory.size(), HeroData.INVENTORY_SIZE]
	_inventory_label.theme_type_variation = (
		&"AccentLabel" if _hero.is_inventory_full() else &"MutedLabel"
	)
	_refresh_pack()
	_build_merge_grid()


func _show_tab(tab: Tab) -> void:
	_tab = tab
	_packs_view.visible = tab == Tab.PACKS
	_merge_view.visible = tab == Tab.MERGE
	_message_label.text = ""


# --- Packs ---------------------------------------------------------------


func _build_pack_buttons() -> void:
	for child: Node in _pack_row.get_children():
		_pack_row.remove_child(child)
		child.queue_free()
	var group: ButtonGroup = ButtonGroup.new()
	for pack: PackData in _packs:
		var button: Button = Button.new()
		button.text = pack.display_name.to_upper()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"QuietButton"
		button.custom_minimum_size = Vector2(0, 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = pack == _packs[0]
		button.toggled.connect(_on_pack_toggled.bind(pack))
		_pack_row.add_child(button)
	_pack = _packs[0] if not _packs.is_empty() else null
	if _pack == null:
		push_error("Gacha: there are no packs in %s." % PackData.DIRECTORY)


func _refresh_pack() -> void:
	for child: Node in _odds_box.get_children():
		_odds_box.remove_child(child)
		child.queue_free()
	_pull_one_button.disabled = _pack == null
	_pull_ten_button.disabled = _pack == null
	if _pack == null:
		_pack_title.text = NO_PACKS
		_pack_description.text = ""
		_pity_label.text = ""
		return

	_pack_title.text = "%s Pack" % _pack.display_name
	_pack_description.text = _pack.description
	var rarities: Array[RarityData] = RarityData.all()
	rarities.reverse()
	for rarity: RarityData in rarities:
		if _pack.weight_of(rarity) <= 0.0:
			continue
		var row: Label = Label.new()
		row.text = "%s  %s%%" % [rarity.display_name, String.num(
			snappedf(_pack.chance_of(rarity) * 100.0, 0.1)
		)]
		row.add_theme_color_override(&"font_color", rarity.color)
		_odds_box.add_child(row)
	_refresh_pity()
	_refresh_pull_button(_pull_one_button, 1)
	_refresh_pull_button(_pull_ten_button, PackData.MULTI_PULL)


func _refresh_pity() -> void:
	if _pack.pity_limit <= 0:
		_pity_label.text = "No guarantee"
		return
	var left: int = GachaMachine.pulls_until_guarantee(_hero, _pack)
	if left <= 1:
		_pity_label.text = "Your next pull is a guaranteed Legendary!"
	else:
		_pity_label.text = "Legendary guaranteed within %d pulls" % left


func _refresh_pull_button(button: Button, count: int) -> void:
	var cost: int = _pack.cost_for(count)
	button.text = "%d PULL%s  %d" % [count, "" if count == 1 else "S", cost]
	var reason: String = GachaMachine.refusal(_hero, _pack, count)
	button.disabled = not reason.is_empty()
	if not reason.is_empty():
		button.tooltip_text = reason
	elif count > 1:
		button.tooltip_text = "Saves %d gold" % (_pack.price * count - cost)
	else:
		button.tooltip_text = ""


func _on_pack_toggled(pressed: bool, pack: PackData) -> void:
	if not pressed:
		return
	_pack = pack
	_message_label.text = ""
	_refresh_pack()


func _on_pull_pressed(count: int) -> void:
	var result: GachaResult = GachaMachine.pull(_hero, _pack, count)
	if result == null:
		_message_label.text = GachaMachine.refusal(_hero, _pack, count)
		_refresh_hero()
		return
	_message_label.text = ""
	_show_items(result.items)
	var top: RarityData = RarityData.highest()
	var summary: String = "%s Pack, %d pull%s: %s" % [
		_pack.display_name, count, "" if count == 1 else "s", _rarity_counts(result.items)
	]
	if result.guarantee_triggered and top != null:
		summary += "\nGuarantee: a %s!" % top.display_name
	_result_summary.text = summary
	_refresh_hero()
	hero_changed.emit()
	_focus_pull_button(count)


## Keep keyboard focus on a pull button: the one just used, or the other when
## the used one is now out of reach.
func _focus_pull_button(count: int) -> void:
	var used: Button = _pull_one_button if count == 1 else _pull_ten_button
	if not used.disabled:
		used.grab_focus()
	elif not _pull_one_button.disabled:
		_pull_one_button.grab_focus()
	else:
		_back_button.grab_focus()


# --- Results -------------------------------------------------------------


func _show_result_text(text: String) -> void:
	_clear_cells(_result_grid)
	_result_summary.text = text


func _show_items(items: Array[EquipmentItem]) -> void:
	_clear_cells(_result_grid)
	for item: EquipmentItem in items:
		var cell: ItemCell = _new_cell(item)
		if cell != null:
			_result_grid.add_child(cell)


## "6 Common, 3 Uncommon, 1 Rare", the best first.
func _rarity_counts(items: Array[EquipmentItem]) -> String:
	var parts: PackedStringArray = []
	var rarities: Array[RarityData] = RarityData.all()
	rarities.reverse()
	for rarity: RarityData in rarities:
		var count: int = 0
		for item: EquipmentItem in items:
			if item.rarity == rarity.id:
				count += 1
		if count > 0:
			parts.append("%d %s" % [count, rarity.display_name])
	return ", ".join(parts)


# --- Merge ---------------------------------------------------------------


func _build_merge_grid() -> void:
	_clear_cells(_merge_grid)
	_merge_cells.clear()
	for item: EquipmentItem in _hero.inventory:
		var cell: ItemCell = _new_cell(item)
		if cell == null:
			continue
		cell.selectable = true
		cell.selection_toggled.connect(_on_merge_cell_toggled)
		_merge_grid.add_child(cell)
		_merge_cells.append(cell)
	_refresh_merge()


func _selected_items() -> Array[EquipmentItem]:
	var picked: Array[EquipmentItem] = []
	for cell: ItemCell in _merge_cells:
		if cell.selected:
			picked.append(cell.item)
	return picked


## Keep the picks to one rarity that can be merged, and no more than one
## merge takes: the cell just ticked wins over anything that conflicts.
func _on_merge_cell_toggled(toggled: ItemCell) -> void:
	_message_label.text = ""
	if toggled.selected:
		if RarityData.next_above(toggled.item.rarity) == null:
			toggled.selected = false
			_message_label.text = "%s is the highest rarity" % toggled.item.get_rarity().display_name
		else:
			for cell: ItemCell in _merge_cells:
				if cell != toggled and cell.selected and cell.item.rarity != toggled.item.rarity:
					cell.selected = false
			if _selected_items().size() > ItemMerge.ITEMS_NEEDED:
				toggled.selected = false
				_message_label.text = "Only %d items per merge" % ItemMerge.ITEMS_NEEDED
	_refresh_merge()


func _refresh_merge() -> void:
	var picked: Array[EquipmentItem] = _selected_items()
	_merge_count_label.text = "%d/%d" % [picked.size(), ItemMerge.ITEMS_NEEDED]
	_merge_button.disabled = not ItemMerge.refusal(_hero, picked).is_empty()
	if picked.is_empty():
		_merge_hint.text = (
			"Tick %d items of the same rarity to merge them into one random item of the next rarity."
			% ItemMerge.ITEMS_NEEDED
		)
		return
	var next: RarityData = RarityData.next_above(picked[0].rarity)
	_merge_hint.text = "%d %s items become 1 random %s item." % [
		ItemMerge.ITEMS_NEEDED, picked[0].get_rarity().display_name, next.display_name
	]


func _on_merge_pressed() -> void:
	var picked: Array[EquipmentItem] = _selected_items()
	var from_rarity: RarityData = picked[0].get_rarity() if not picked.is_empty() else null
	var made: EquipmentItem = ItemMerge.merge(_hero, picked)
	if made == null:
		_message_label.text = ItemMerge.refusal(_hero, picked)
		return
	_message_label.text = ""
	_show_items([made])
	_result_summary.text = "Merged %d %s items into %s %s" % [
		picked.size(), from_rarity.display_name, made.get_rarity().display_name,
		made.get_display_name()
	]
	_refresh_hero()
	hero_changed.emit()


# --- Shared --------------------------------------------------------------


func _new_cell(item: EquipmentItem) -> ItemCell:
	if item_cell_scene == null:
		push_error("Gacha: item_cell_scene must be wired to show items.")
		return null
	var node: Node = item_cell_scene.instantiate()
	if node is not ItemCell:
		push_error("Gacha: item_cell_scene must have an ItemCell root.")
		node.free()
		return null
	var cell: ItemCell = node
	cell.item = item
	cell.draggable = false
	return cell


func _clear_cells(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _on_tab_toggled(pressed: bool, tab: Tab) -> void:
	if pressed:
		_show_tab(tab)
