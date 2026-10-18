class_name Store
extends Control
## The shop: every weapon, pair of boots and armour piece, with its price, and
## the hero's doll to try any of it on.
##
## Picking something in the catalog puts it on the doll in place of what the
## hero wears, without touching the hero. RESET dresses the doll as the hero
## again. Weapons play their attack when picked, and WALK and ATTACK show how
## a choice moves. Buying is not open yet: the price and the BUY button are
## here so it can be wired to gold later. Armour is sold by the piece, picked
## from one class's art at a time, and an Armour item is the pieces together.
##
## Never saves or changes the hero. Runs standalone with a throwaway hero.

signal back_requested

enum Tab { WEAPONS, BOOTS, ARMOUR }

const COLUMNS: int = 7
## Gold of the throwaway hero this screen makes when run on its own.
const TESTER_GOLD: int = 5000
const BUY_HINT: String = "Buying is not open yet"
const NOTHING_PICKED: String = "Try it on"
const NOTHING_PICKED_HINT: String = "Pick anything in the list to see it on your hero."
const WEAPON_TITLES: Dictionary[StringName, String] = {
	&"sword": "SWORDS", &"crossbow": "CROSSBOWS", &"wand": "WANDS"
}
## Section titles for armour, indexed by ArmourItem.Piece.
const PIECE_TITLES: PackedStringArray = ["HATS", "SHIRTS", "PANTS"]
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

@onready var _stage: Control = %Stage
@onready var _doll_anchor: Node2D = %DollAnchor
@onready var _doll: PaperDoll = %PaperDoll
@onready var _back_button: Button = %BackButton
@onready var _gold_label: Label = %GoldLabel
@onready var _name_label: Label = %NameLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _price_group: Control = %PriceGroup
@onready var _price_label: Label = %PriceLabel
@onready var _reset_button: Button = %ResetButton
@onready var _walk_button: Button = %WalkButton
@onready var _attack_button: Button = %AttackButton
@onready var _buy_button: Button = %BuyButton
@onready var _weapons_tab: Button = %WeaponsTab
@onready var _boots_tab: Button = %BootsTab
@onready var _armour_tab: Button = %ArmourTab
@onready var _class_row: HBoxContainer = %ClassRow
@onready var _scroll: ScrollContainer = %Scroll
@onready var _sections: VBoxContainer = %Sections


func _ready() -> void:
	_doll_anchor.scale = Vector2.ONE * doll_scale
	_stage.custom_minimum_size.y = STAGE_HEIGHT * doll_scale
	_stage.resized.connect(_place_doll)
	_back_button.pressed.connect(back_requested.emit)
	_reset_button.pressed.connect(_reset)
	_walk_button.toggled.connect(_on_walk_toggled)
	_attack_button.pressed.connect(_on_attack_pressed)
	_buy_button.tooltip_text = BUY_HINT
	_weapons_tab.toggled.connect(_on_tab_toggled.bind(Tab.WEAPONS))
	_boots_tab.toggled.connect(_on_tab_toggled.bind(Tab.BOOTS))
	_armour_tab.toggled.connect(_on_tab_toggled.bind(Tab.ARMOUR))

	if _hero == null:
		_hero = HeroData.create("Tester")
		if _hero == null:
			return
		_hero.gold = TESTER_GOLD
	_pool = _armour_pool_of(_hero)
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
		_pool = _armour_pool_of(hero)
		_refresh_hero()


func _armour_pool_of(hero: HeroData) -> StringName:
	return hero.armour_pool()


func _refresh_hero() -> void:
	_gold_label.text = str(_hero.gold)
	_reset()


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
	_class_row.visible = tab == Tab.ARMOUR
	_build_catalog()


## Rebuild the listing for the current tab from the top.
func _build_catalog() -> void:
	for child: Node in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.WEAPONS:
			for family: StringName in StoreCatalog.WEAPON_FAMILIES:
				var grid: GridContainer = _add_section(WEAPON_TITLES[family])
				for weapon: WeaponItem in StoreCatalog.weapons(family):
					_add_entry(grid, weapon, str(StoreCatalog.price_of(weapon)))
		Tab.BOOTS:
			var grid: GridContainer = _add_section("BOOTS")
			for pair: BootsItem in StoreCatalog.boots():
				_add_entry(grid, pair, str(StoreCatalog.price_of(pair)))
		Tab.ARMOUR:
			for piece: ArmourItem.Piece in StoreCatalog.ARMOUR_PIECES:
				var ids: PackedInt32Array = ArmourItem.available_ids(_pool, piece)
				if ids.is_empty():
					continue
				var grid: GridContainer = _add_section(PIECE_TITLES[piece])
				for id: int in ids:
					var single: ArmourItem = StoreCatalog.armour_piece(_pool, piece, id)
					_add_entry(grid, single, "#%02d" % id)
	_scroll.scroll_vertical = 0


func _add_section(title: String) -> GridContainer:
	var header: Label = Label.new()
	header.text = title
	header.theme_type_variation = &"MutedLabel"
	_sections.add_child(header)
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 2)
	_sections.add_child(grid)
	return grid


func _add_entry(grid: GridContainer, item: EquipmentItem, caption: String) -> void:
	if item_cell_scene == null:
		push_error("Store: item_cell_scene must be wired to list items.")
		return
	var node: Node = item_cell_scene.instantiate()
	if node is not ItemCell:
		push_error("Store: item_cell_scene must have an ItemCell root.")
		node.free()
		return
	var cell: ItemCell = node
	cell.item = item
	cell.draggable = false
	cell.center_icon = item is ArmourItem
	# Picking is focusing, so arrow keys browse and a click picks.
	cell.focus_entered.connect(_select.bind(item))
	cell.activated.connect(_on_cell_activated)

	var label: Label = Label.new()
	label.text = caption
	label.theme_type_variation = &"MutedLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var entry: VBoxContainer = VBoxContainer.new()
	entry.add_theme_constant_override(&"separation", 0)
	entry.add_child(cell)
	entry.add_child(label)
	grid.add_child(entry)
	# After entering the tree: the cell sets its own tooltip when it readies.
	cell.tooltip_text = "%s\n%d gold" % [item.get_tooltip_text(), StoreCatalog.price_of(item)]


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
		return worn
	var armour: ArmourItem = ArmourItem.new()
	armour.pool = pool
	for piece: ArmourItem.Piece in StoreCatalog.ARMOUR_PIECES:
		var ids: PackedInt32Array = ArmourItem.available_ids(pool, piece)
		if not ids.is_empty():
			armour.set_piece_id(piece, ids[0])
	return armour


func _refresh_info() -> void:
	if _selected == null:
		_name_label.text = NOTHING_PICKED
		_detail_label.text = NOTHING_PICKED_HINT
		_price_group.visible = false
		_buy_button.modulate.a = 0.0
		return
	_price_group.visible = true
	_buy_button.modulate.a = 1.0
	_price_label.text = str(StoreCatalog.price_of(_selected))
	if _selected is ArmourItem:
		_describe_armour(_selected)
		return
	var lines: PackedStringArray = _selected.get_tooltip_text().split("\n")
	_name_label.text = lines[0]
	_detail_label.text = "\n".join(lines.slice(1))


func _describe_armour(armour: ArmourItem) -> void:
	_name_label.text = armour.get_display_name()
	var lines: PackedStringArray = []
	for piece: ArmourItem.Piece in StoreCatalog.ARMOUR_PIECES:
		var id: int = armour.piece_id(piece)
		var piece_name: String = ArmourItem.PIECE_FOLDERS[piece].capitalize()
		lines.append("%s %s" % [piece_name, "none" if id == ArmourItem.NO_PIECE else "#%02d" % id])
	_detail_label.text = "\n".join(lines)


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
