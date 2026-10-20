class_name Store
extends Control
## The shop: buy gear from the shelves, sell spare gear back, and the hero's
## doll to try anything on.
##
## Weapons, Boots and Armour tabs show shelves of everything on sale, each
## with a hanging price tag, dimmed and red when the hero cannot afford it.
## Picking something puts it on the doll in place of what the hero wears,
## without touching the hero, and the panel beside it sets what it gives next
## to what the hero wears now. RESET dresses the doll as the hero again, and
## WALK and ATTACK show how a choice moves. BUY pays for what is picked and
## puts a new Common copy in the hero's inventory; the store sells nothing
## rarer (gacha is where rarity comes from). Armour is sold by the piece,
## picked from one class's art at a time, and an Armour item is the pieces
## together, with its stat points rolled when bought.
##
## The Sell tab lists the hero's carried items: tick any number and sell them
## together, or tick every Common with one button. Rarer ones ask first.
## A poster under the shelves opens the gacha.
##
## Changes the hero only by buying and selling, and reports that with
## hero_changed for the screen owner to save. Runs standalone with a throwaway
## hero.

signal back_requested
## The player asked for the gacha, which is reached from the store.
signal gacha_requested
## The hero bought or sold something and should be saved.
signal hero_changed

enum Tab { WEAPONS, BOOTS, ARMOUR, SELL }

const COLUMNS: int = 7
## Gap between shelf entries, across and down. Tight enough that seven columns
## fit the panel beside a scrollbar, so no tab is wider than the screen.
const SHELF_GAP: Vector2i = Vector2i(3, 4)
## Gold of the throwaway hero this screen makes when run on its own.
const TESTER_GOLD: int = 5000
const BUY_TEXT: String = "BUY"
const BOUGHT_TEXT: String = "BOUGHT"
const SOLD_TAG: String = "SOLD!"
## Seconds the BUY button says BOUGHT.
const BOUGHT_SECONDS: float = 0.8
## Seconds the gold count takes to run to its new value.
const GOLD_SECONDS: float = 0.6
## Coins thrown when buying, and per item when selling, at most MAX_COINS.
const BUY_COINS: int = 6
const MAX_COINS: int = 14
## Selling an item of this rarity or a rarer one asks first. By order, so it
## follows RarityData.order: 2 is Rare.
const CONFIRM_SELL_FROM_ORDER: int = 2
const NOTHING_PICKED: String = "Try it on"
const NOTHING_PICKED_HINT: String = "Pick anything on the shelves to see it on your hero."
const NOTHING_TO_SELL_HINT: String = "Pick an item to see what it fetches."
const EMPTY_SELL: String = "Nothing to sell. Your inventory is empty."
const WEAPON_TITLES: Dictionary[StringName, String] = {
	&"sword": "SWORDS", &"crossbow": "CROSSBOWS", &"wand": "WANDS"
}
## Section titles for armour, indexed by ArmourItem.Piece.
const PIECE_TITLES: PackedStringArray = ["HATS", "SHIRTS", "PANTS"]
## The awning's two stripes for the shelves, and for the sell tab.
const BUY_STRIPES: Array[Color] = [Color(0.78, 0.22, 0.18), Color(0.95, 0.9, 0.78)]
const SELL_STRIPES: Array[Color] = [Color(0.25, 0.55, 0.28), Color(0.95, 0.9, 0.78)]
const UNAFFORDABLE: Color = Color(0.7, 0.66, 0.66, 1.0)
const BETTER_COLOR: Color = Color(0.55, 0.9, 0.4, 1.0)
const WORSE_COLOR: Color = Color(1.0, 0.45, 0.4, 1.0)
const NEUTRAL_COLOR: Color = Color(0.82, 0.78, 0.68, 1.0)
## Stage height in unscaled doll pixels, and the gap from its bottom edge to
## the hero's feet. The same as the hub's stage.
const STAGE_HEIGHT: float = 68.0
const FEET_MARGIN: float = 11.0

@export_range(1, 3) var doll_scale: int = 2
## One catalog cell, instanced for every item listed.
@export var item_cell_scene: PackedScene

var _hero: HeroData = null
var _tab: Tab = Tab.WEAPONS
## The class whose armour art the armour tab lists.
var _pool: StringName = HeroData.STARTING_CLASS
## What is being tried on, each null while the hero's own is shown.
var _weapon: WeaponItem = null
var _boots: BootsItem = null
var _armour: ArmourItem = null
var _selected: EquipmentItem = null
## The shelf entries on show, for dimming what the hero cannot afford.
var _entries: Array[Dictionary] = []
var _tags: Dictionary[EquipmentItem, PriceTag] = {}
var _sell_cells: Array[ItemCell] = []
var _pending_sale: Array[EquipmentItem] = []
## Whether the confirmation open is for an inventory upgrade, not a sale.
var _pending_bag: bool = false
var _gold_shown: int = 0
var _gold_tween: Tween = null

@onready var _stage: Control = %Stage
@onready var _doll_anchor: Node2D = %DollAnchor
@onready var _doll: PaperDoll = %PaperDoll
@onready var _back_button: Button = %BackButton
@onready var _gold_chip: Control = %GoldChip
@onready var _bag_button: Button = %BagButton
@onready var _gold_label: Label = %GoldLabel
@onready var _inventory_label: Label = %InventoryLabel
@onready var _name_label: Label = %NameLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _compare_box: VBoxContainer = %CompareBox
@onready var _owned_label: Label = %OwnedLabel
@onready var _price_group: Control = %PriceGroup
@onready var _price_label: Label = %PriceLabel
@onready var _reset_button: Button = %ResetButton
@onready var _walk_button: Button = %WalkButton
@onready var _attack_button: Button = %AttackButton
@onready var _buy_button: Button = %BuyButton
@onready var _weapons_tab: Button = %WeaponsTab
@onready var _boots_tab: Button = %BootsTab
@onready var _armour_tab: Button = %ArmourTab
@onready var _sell_tab: Button = %SellTab
@onready var _awning: ShopAwning = %Awning
@onready var _class_row: HBoxContainer = %ClassRow
@onready var _scroll: ScrollContainer = %Scroll
@onready var _sections: VBoxContainer = %Sections
@onready var _poster: GachaPoster = %Poster
@onready var _sell_bar: Control = %SellBar
@onready var _select_common_button: Button = %SelectCommonButton
@onready var _clear_button: Button = %ClearButton
@onready var _sell_button: Button = %SellButton
@onready var _burst: CoinBurst = %CoinBurst
@onready var _confirm_dialog: ConfirmDialog = %ConfirmDialog


func _ready() -> void:
	_doll_anchor.scale = Vector2.ONE * doll_scale
	_stage.custom_minimum_size.y = STAGE_HEIGHT * doll_scale
	_stage.resized.connect(_place_doll)
	_back_button.pressed.connect(back_requested.emit)
	_poster.pressed.connect(gacha_requested.emit)
	_reset_button.pressed.connect(_reset)
	_walk_button.toggled.connect(_on_walk_toggled)
	_attack_button.pressed.connect(_on_attack_pressed)
	_buy_button.pressed.connect(_on_buy_pressed)
	_bag_button.pressed.connect(_on_bag_pressed)
	_weapons_tab.toggled.connect(_on_tab_toggled.bind(Tab.WEAPONS))
	_boots_tab.toggled.connect(_on_tab_toggled.bind(Tab.BOOTS))
	_armour_tab.toggled.connect(_on_tab_toggled.bind(Tab.ARMOUR))
	_sell_tab.toggled.connect(_on_tab_toggled.bind(Tab.SELL))
	_select_common_button.pressed.connect(_on_select_common_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_sell_button.pressed.connect(_on_sell_pressed)
	_confirm_dialog.confirmed.connect(_on_sale_confirmed)
	_confirm_dialog.cancelled.connect(_on_sale_cancelled)

	if _hero == null:
		_hero = HeroData.create("Tester")
		if _hero == null:
			return
		_hero.gold = TESTER_GOLD
	_pool = _hero.armour_pool()
	_set_tab_icons()
	_build_class_buttons()
	_place_doll()
	_refresh_hero()
	_show_tab(Tab.WEAPONS)
	_weapons_tab.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()


## Show the store to `hero`, whose doll and gold are shown. Can be called
## before ready.
func show_hero(hero: HeroData) -> void:
	if hero == null:
		push_error("Store: cannot open for an empty hero.")
		return
	_hero = hero
	if is_node_ready():
		_pool = hero.armour_pool()
		_refresh_hero()
		_build_catalog()


func _refresh_hero() -> void:
	_set_gold(_hero.gold, false)
	_refresh_inventory_count()
	_poster.show_hero(_hero)
	_reset()


func _refresh_inventory_count() -> void:
	_inventory_label.text = "%d/%d" % [_hero.inventory.size(), _hero.inventory_capacity()]
	_inventory_label.theme_type_variation = (
		&"AccentLabel" if _hero.is_inventory_full() else &""
	)
	_refresh_bag_button()


## Shows the next inventory upgrade and what it costs. Gone once the hero has
## bought them all.
func _refresh_bag_button() -> void:
	var price: int = _hero.next_bag_upgrade_price()
	_bag_button.visible = price >= 0
	if price < 0:
		return
	_bag_button.text = "+%d SLOTS   %d" % [_hero.next_bag_upgrade_slots(), price]
	_bag_button.disabled = _hero.gold < price
	_bag_button.tooltip_text = (
		"Not enough gold" if _hero.gold < price
		else "Make room for %d more items" % _hero.next_bag_upgrade_slots()
	)


func _on_bag_pressed() -> void:
	if not _hero.can_upgrade_bag():
		return
	_pending_bag = true
	_confirm_dialog.open(
		"Add %d inventory slots for %d gold?" % [
			_hero.next_bag_upgrade_slots(), _hero.next_bag_upgrade_price()
		],
		"EXPAND",
		"CANCEL",
	)


func _upgrade_bag() -> void:
	if not _hero.upgrade_bag():
		return
	_burst.fly(_centre_of(_gold_chip), _centre_of(_bag_button), BUY_COINS)
	_set_gold(_hero.gold, true)
	_refresh_inventory_count()
	_refresh_affordability()
	_refresh_buy_button()
	hero_changed.emit()
	_bag_button.grab_focus()


## Run the gold count to `target`, or jump there.
func _set_gold(target: int, animate: bool) -> void:
	if _gold_tween != null:
		_gold_tween.kill()
		_gold_tween = null
	if not animate or target == _gold_shown:
		_show_gold(target)
		return
	_gold_tween = create_tween()
	_gold_tween.tween_method(_show_gold, _gold_shown, target, GOLD_SECONDS)


func _show_gold(amount: int) -> void:
	_gold_shown = amount
	_gold_label.text = str(amount)


## Each tab wears the icon of something it sells.
func _set_tab_icons() -> void:
	var sword: WeaponData = WeaponData.find(&"sword")
	if sword != null:
		_weapons_tab.icon = sword.icon
	var shoes: BootsData = BootsData.find(&"leather_shoes")
	if shoes != null:
		_boots_tab.icon = shoes.icon
	var shirt: ArmourItem = StoreCatalog.armour_piece(&"warrior", ArmourItem.Piece.SHIRT, 1)
	var layers: Array[Texture2D] = shirt.get_icon_layers()
	if not layers.is_empty():
		_armour_tab.icon = layers[0]
	_sell_tab.icon = PriceTag.COIN


## Dress the doll as the hero again and forget what was picked.
func _reset() -> void:
	_weapon = null
	_boots = null
	_armour = null
	_selected = null
	_doll.wear_armour(_hero.armour)
	_doll.wear_boots(_hero.boots)
	_doll.wield(_hero.weapon)
	_refresh_info()


func _place_doll() -> void:
	_doll_anchor.position = Vector2(
		roundf(_stage.size.x * 0.5), roundf(_stage.size.y - FEET_MARGIN * doll_scale)
	)


func _build_class_buttons() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for pool: StringName in StoreCatalog.ARMOUR_POOLS:
		var button: Button = Button.new()
		button.text = String(pool).to_upper()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"QuietButton"
		button.custom_minimum_size = Vector2(0, 20)
		button.button_pressed = pool == _pool
		button.toggled.connect(_on_pool_toggled.bind(pool))
		_class_row.add_child(button)


func _show_tab(tab: Tab) -> void:
	_tab = tab
	var selling: bool = tab == Tab.SELL
	_class_row.visible = tab == Tab.ARMOUR
	_poster.visible = not selling
	_sell_bar.visible = selling
	var stripes: Array[Color] = SELL_STRIPES if selling else BUY_STRIPES
	_awning.set_stripes(stripes[0], stripes[1])
	_reset()
	_build_catalog()


## Rebuild the listing for the current tab from the top.
func _build_catalog() -> void:
	for child: Node in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	_entries.clear()
	_tags.clear()
	_sell_cells.clear()
	match _tab:
		Tab.WEAPONS:
			for family: StringName in StoreCatalog.WEAPON_FAMILIES:
				var grid: ShelfGrid = _add_section(WEAPON_TITLES[family])
				for weapon: WeaponItem in StoreCatalog.weapons(family):
					_add_entry(grid, weapon, StoreCatalog.price_of(weapon))
		Tab.BOOTS:
			var grid: ShelfGrid = _add_section("BOOTS")
			for pair: BootsItem in StoreCatalog.boots():
				_add_entry(grid, pair, StoreCatalog.price_of(pair))
		Tab.ARMOUR:
			for piece: ArmourItem.Piece in StoreCatalog.ARMOUR_PIECES:
				var ids: PackedInt32Array = ArmourItem.available_ids(_pool, piece)
				if ids.is_empty():
					continue
				var grid: ShelfGrid = _add_section(PIECE_TITLES[piece])
				for id: int in ids:
					var single: ArmourItem = StoreCatalog.armour_piece(_pool, piece, id)
					_add_entry(grid, single, StoreCatalog.price_of(single))
		Tab.SELL:
			_build_sell_list()
	_scroll.scroll_vertical = 0
	_refresh_affordability()
	_refresh_sell_bar()


func _add_section(title: String) -> ShelfGrid:
	var header: Label = Label.new()
	header.text = title
	header.theme_type_variation = &"MutedLabel"
	_sections.add_child(header)
	var grid: ShelfGrid = _new_shelf()
	_sections.add_child(grid)
	return grid


## An empty shelf, COLUMNS wide.
func _new_shelf() -> ShelfGrid:
	var grid: ShelfGrid = ShelfGrid.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", SHELF_GAP.x)
	grid.add_theme_constant_override(&"v_separation", SHELF_GAP.y)
	return grid


## One item on a shelf with its tag, or null when the cell cannot be made.
func _new_entry(item: EquipmentItem, tag: PriceTag) -> Control:
	if item_cell_scene == null:
		push_error("Store: item_cell_scene must be wired to list items.")
		return null
	var node: Node = item_cell_scene.instantiate()
	if node is not ItemCell:
		push_error("Store: item_cell_scene must have an ItemCell root.")
		node.free()
		return null
	var cell: ItemCell = node
	cell.item = item
	cell.draggable = false
	cell.center_icon = item is ArmourItem

	var entry: VBoxContainer = VBoxContainer.new()
	entry.add_theme_constant_override(&"separation", 0)
	entry.add_child(cell)
	entry.add_child(tag)
	return entry


func _add_entry(grid: ShelfGrid, item: EquipmentItem, price: int) -> void:
	var tag: PriceTag = PriceTag.new()
	tag.price = price
	var entry: Control = _new_entry(item, tag)
	if entry == null:
		return
	var cell: ItemCell = entry.get_child(0)
	# Picking is focusing, so arrow keys browse and a click picks.
	cell.focus_entered.connect(_select.bind(item))
	cell.activated.connect(_on_cell_activated)
	grid.add_child(entry)
	# After entering the tree: the cell sets its own tooltip when it readies.
	cell.tooltip_text = "%s\n%d gold" % [item.get_tooltip_text(), price]
	_entries.append({&"cell": cell, &"tag": tag, &"price": price})
	_tags[item] = tag


## Dim and redden whatever the hero cannot pay for.
func _refresh_affordability() -> void:
	for entry: Dictionary in _entries:
		var price: int = entry[&"price"]
		var affordable: bool = _hero.gold >= price
		(entry[&"tag"] as PriceTag).affordable = affordable
		(entry[&"cell"] as ItemCell).modulate = Color.WHITE if affordable else UNAFFORDABLE


# --- Buying --------------------------------------------------------------


func _select(item: EquipmentItem) -> void:
	if item is WeaponItem:
		_weapon = item
		_selected = item
		_doll.wield(_weapon)
		_doll.attack()
	elif item is BootsItem:
		_boots = item
		_selected = item
		_doll.wear_boots(_boots)
	elif item is ArmourItem:
		_try_armour_piece(item)
	_refresh_info()


## Put the one piece `single` holds on the doll, on top of whatever armour
## from the same class is already being tried.
func _try_armour_piece(single: ArmourItem) -> void:
	if _armour == null or _armour.pool != single.pool:
		_armour = _starting_armour(single.pool)
	for piece: ArmourItem.Piece in StoreCatalog.ARMOUR_PIECES:
		if single.piece_id(piece) != ArmourItem.NO_PIECE:
			_armour.set_piece_id(piece, single.piece_id(piece))
	_selected = _armour
	_doll.wear_armour(_armour)


## What armour of `pool` to start trying pieces on: the hero's own when they
## wear that class's, otherwise the first variant of each piece.
func _starting_armour(pool: StringName) -> ArmourItem:
	if _hero.armour != null and _hero.armour.pool == pool:
		var worn: ArmourItem = _hero.armour.duplicate() as ArmourItem
		worn.rarity = RarityData.COMMON
		worn.stat_points = {}
		return worn
	var armour: ArmourItem = ArmourItem.new()
	armour.pool = pool
	for piece: ArmourItem.Piece in StoreCatalog.ARMOUR_PIECES:
		var ids: PackedInt32Array = ArmourItem.available_ids(pool, piece)
		if not ids.is_empty():
			armour.set_piece_id(piece, ids[0])
	return armour


## Fill the side panel for what is picked: its name, what it gives next to what
## the hero wears, how many they already have, and its price.
func _refresh_info() -> void:
	var selling: bool = _tab == Tab.SELL
	_refresh_buy_button()
	_clear_children(_compare_box)
	if _selected == null:
		_name_label.text = NOTHING_PICKED
		_set_detail(NOTHING_TO_SELL_HINT if selling else NOTHING_PICKED_HINT, NEUTRAL_COLOR)
		_owned_label.text = ""
		_price_group.visible = false
		_buy_button.modulate.a = 0.0
		return
	_price_group.visible = true
	_buy_button.modulate.a = 0.0 if selling else 1.0
	if selling:
		_price_label.text = "+%d" % StoreCatalog.sell_price_of(_selected)
	else:
		_price_label.text = str(StoreCatalog.price_of(_selected))
	_name_label.text = _selected.get_display_name()
	_describe_subtitle(_selected)
	for row: ItemCompare.Row in ItemCompare.rows(_selected, _hero):
		_add_compare_row(row)
	var owned: int = 0 if selling else _owned_count(_selected)
	_owned_label.text = "You have %d" % owned if owned > 0 else ""


## The line under the name: an armour's pieces, or an item's rarity.
func _describe_subtitle(item: EquipmentItem) -> void:
	if item is ArmourItem and _tab != Tab.SELL:
		var armour: ArmourItem = item
		var parts: PackedStringArray = []
		for piece: ArmourItem.Piece in StoreCatalog.ARMOUR_PIECES:
			var id: int = armour.piece_id(piece)
			if id != ArmourItem.NO_PIECE:
				parts.append("%s #%02d" % [ArmourItem.PIECE_FOLDERS[piece].capitalize(), id])
		_set_detail("  ".join(parts), NEUTRAL_COLOR)
		return
	var rarity: RarityData = item.get_rarity()
	if rarity != null and rarity.id != RarityData.COMMON:
		_set_detail(rarity.display_name, rarity.color)
	else:
		_set_detail("", NEUTRAL_COLOR)


func _set_detail(text: String, color: Color) -> void:
	_detail_label.text = text
	_detail_label.add_theme_color_override(&"font_color", color)


func _add_compare_row(row: ItemCompare.Row) -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 6)
	var label: Label = Label.new()
	label.text = row.label
	label.theme_type_variation = &"MutedLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var value: Label = Label.new()
	value.text = row.value
	line.add_child(value)
	var delta: Label = Label.new()
	delta.text = row.delta
	delta.custom_minimum_size = Vector2(38, 0)
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta.add_theme_color_override(&"font_color", _tone_color(row.tone))
	line.add_child(delta)
	_compare_box.add_child(line)


func _tone_color(tone: ItemCompare.Tone) -> Color:
	match tone:
		ItemCompare.Tone.BETTER:
			return BETTER_COLOR
		ItemCompare.Tone.WORSE:
			return WORSE_COLOR
	return NEUTRAL_COLOR


## How many of `item`'s kind the hero carries or wears. Armour is one-off, so
## only weapons and boots are counted.
func _owned_count(item: EquipmentItem) -> int:
	var count: int = 0
	var held: Array[EquipmentItem] = _hero.inventory.duplicate()
	held.append(_hero.equipped(item.get_slot()))
	for other: EquipmentItem in held:
		if item is WeaponItem and other is WeaponItem:
			if (other as WeaponItem).weapon_id == (item as WeaponItem).weapon_id:
				count += 1
		elif item is BootsItem and other is BootsItem:
			if (other as BootsItem).boots_id == (item as BootsItem).boots_id:
				count += 1
	return count


## Enabled when the hero can pay and has room; otherwise says why on hover.
func _refresh_buy_button() -> void:
	_buy_button.text = BUY_TEXT
	if _selected == null or _tab == Tab.SELL:
		_buy_button.disabled = true
		_buy_button.tooltip_text = ""
		return
	var price: int = StoreCatalog.price_of(_selected)
	_price_label.theme_type_variation = &"" if _hero.gold >= price else &"AccentLabel"
	if _hero.is_inventory_full():
		_buy_button.tooltip_text = "Inventory full. Sell something or add slots."
	elif _hero.gold < price:
		_buy_button.tooltip_text = "Not enough gold"
	else:
		_buy_button.tooltip_text = "Buy for %d gold" % price
	_buy_button.disabled = not _hero.can_buy(price)


## A new Common item to match what is picked, or null for nothing. The picked
## item itself is only a listing, so it is never handed over.
func _new_purchase() -> EquipmentItem:
	if _selected is WeaponItem:
		return WeaponItem.create((_selected as WeaponItem).weapon_id)
	if _selected is BootsItem:
		return BootsItem.create((_selected as BootsItem).boots_id)
	if _selected is ArmourItem:
		var picked: ArmourItem = _selected
		var armour: ArmourItem = ArmourItem.new()
		armour.pool = picked.pool
		for piece: ArmourItem.Piece in StoreCatalog.ARMOUR_PIECES:
			armour.set_piece_id(piece, picked.piece_id(piece))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		armour.roll_stats(rng)
		return armour
	return null


func _on_buy_pressed() -> void:
	if _selected == null or _tab == Tab.SELL:
		return
	var price: int = StoreCatalog.price_of(_selected)
	var purchase: EquipmentItem = _new_purchase()
	if purchase == null or not _hero.buy_item(purchase, price):
		return
	_burst.fly(_centre_of(_gold_chip), _centre_of(_buy_button), BUY_COINS)
	_set_gold(_hero.gold, true)
	_refresh_inventory_count()
	_refresh_affordability()
	hero_changed.emit()
	_refresh_info()
	if _tags.has(_selected):
		_tags[_selected].flash(SOLD_TAG)
	_buy_button.text = BOUGHT_TEXT
	await get_tree().create_timer(BOUGHT_SECONDS).timeout
	if is_instance_valid(self) and _buy_button.text == BOUGHT_TEXT:
		_buy_button.text = BUY_TEXT


# --- Selling -------------------------------------------------------------


func _build_sell_list() -> void:
	var header: Label = Label.new()
	header.text = "YOUR ITEMS"
	header.theme_type_variation = &"MutedLabel"
	_sections.add_child(header)
	if _hero.inventory.is_empty():
		var empty: Label = Label.new()
		empty.text = EMPTY_SELL
		_sections.add_child(empty)
		return
	var grid: ShelfGrid = _new_shelf()
	_sections.add_child(grid)
	for item: EquipmentItem in _hero.inventory:
		var tag: PriceTag = PriceTag.new()
		tag.price = StoreCatalog.sell_price_of(item)
		tag.pays = true
		var entry: Control = _new_entry(item, tag)
		if entry == null:
			continue
		var cell: ItemCell = entry.get_child(0)
		cell.selectable = true
		cell.selection_toggled.connect(_on_sell_toggled)
		cell.focus_entered.connect(_select_for_sale.bind(item))
		grid.add_child(entry)
		_sell_cells.append(cell)


## Show what a carried item gives and fetches, without dressing the doll in it.
func _select_for_sale(item: EquipmentItem) -> void:
	_selected = item
	_refresh_info()


func _picked_for_sale() -> Array[EquipmentItem]:
	var picked: Array[EquipmentItem] = []
	for cell: ItemCell in _sell_cells:
		if cell.selected:
			picked.append(cell.item)
	return picked


func _on_sell_toggled(_cell: ItemCell) -> void:
	_refresh_sell_bar()


func _on_select_common_pressed() -> void:
	for cell: ItemCell in _sell_cells:
		cell.selected = cell.item.rarity == RarityData.COMMON
	_refresh_sell_bar()


func _on_clear_pressed() -> void:
	for cell: ItemCell in _sell_cells:
		cell.selected = false
	_refresh_sell_bar()


func _refresh_sell_bar() -> void:
	var picked: Array[EquipmentItem] = _picked_for_sale()
	var total: int = 0
	for item: EquipmentItem in picked:
		total += StoreCatalog.sell_price_of(item)
	_sell_button.text = "SELL %d   +%d" % [picked.size(), total]
	_sell_button.disabled = picked.is_empty()
	_clear_button.disabled = picked.is_empty()
	_select_common_button.disabled = _sell_cells.is_empty()


func _on_sell_pressed() -> void:
	var picked: Array[EquipmentItem] = _picked_for_sale()
	if picked.is_empty():
		return
	var total: int = 0
	var asks: bool = false
	for item: EquipmentItem in picked:
		total += StoreCatalog.sell_price_of(item)
		var rarity: RarityData = item.get_rarity()
		if rarity != null and rarity.order >= CONFIRM_SELL_FROM_ORDER:
			asks = true
	if not asks:
		_sell(picked)
		return
	_pending_sale = picked
	_confirm_dialog.open(
		"Sell %d items, some of them rare, for %d gold?" % [picked.size(), total], "SELL", "KEEP"
	)


func _on_sale_confirmed() -> void:
	if _pending_bag:
		_pending_bag = false
		_upgrade_bag()
		return
	var picked: Array[EquipmentItem] = _pending_sale
	_pending_sale = []
	_sell(picked)


func _on_sale_cancelled() -> void:
	if _pending_bag:
		_pending_bag = false
		_bag_button.grab_focus()
		return
	_pending_sale = []
	_sell_button.grab_focus()


func _sell(items: Array[EquipmentItem]) -> void:
	var earned: int = 0
	for item: EquipmentItem in items:
		earned += _hero.sell_item(item)
	if earned <= 0:
		return
	_burst.fly(_centre_of(_sell_button), _centre_of(_gold_chip), mini(items.size() * 2, MAX_COINS))
	_set_gold(_hero.gold, true)
	_refresh_inventory_count()
	hero_changed.emit()
	_selected = null
	_build_catalog()
	_refresh_info()
	_sell_tab.grab_focus()


# --- Shared --------------------------------------------------------------


func _centre_of(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _on_tab_toggled(pressed: bool, tab: Tab) -> void:
	if pressed:
		_show_tab(tab)


func _on_pool_toggled(pressed: bool, pool: StringName) -> void:
	if not pressed:
		return
	_pool = pool
	_armour = _starting_armour(pool)
	_selected = _armour
	_doll.wear_armour(_armour)
	_build_catalog()
	_refresh_info()


func _on_cell_activated(cell: ItemCell) -> void:
	_select(cell.item)


func _on_walk_toggled(walking: bool) -> void:
	_doll.play(PaperDoll.WALK_CLIP if walking else PaperDoll.IDLE_CLIP)


func _on_attack_pressed() -> void:
	_doll.attack()
