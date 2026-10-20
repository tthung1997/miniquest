class_name Gacha
extends Control
## The gacha: a slot machine that pays out gear, and a forge that merges spare
## items into better ones. Reached from the store.
##
## Packs tab: pick a pack from the shelf, then pull once or ten at a time.
## Each pull is a reel that spins and stops, left to right, on its item; SKIP
## stops them all at once. The pack's odds and how close its guaranteed
## Legendary is are drawn as bars. Forge tab: tick five items of one rarity
## from the stash and merge them; the new item stops on a reel of its own.
##
## The result is decided, paid for and put in the hero's inventory the moment a
## pull or merge is made, through GachaMachine and ItemMerge. The reels only
## reveal it, so leaving mid-spin loses nothing. Changes are reported with
## hero_changed for the screen owner to save. Runs standalone with a throwaway
## hero.

signal back_requested
## The hero pulled or merged and should be saved.
signal hero_changed

enum Tab { PACKS, FORGE }

const RESULT_COLUMNS: int = 5
const STASH_COLUMNS: int = 5
const SINGLE_REEL: int = 112
const MULTI_REEL: int = 72
## Seconds until the first reel stops, and between one stopping and the next.
const FIRST_STOP: float = 1.0
const STOP_STAGGER: float = 0.2
## Seconds the forge's reel spins before it stops.
const FORGE_SPIN: float = 1.2
## Rarities from this order up (3 is Epic) make the marquee blink in their
## colour once a pull has paid out, for CELEBRATE_SECONDS.
const CELEBRATE_FROM_ORDER: int = 3
const CELEBRATE_SECONDS: float = 2.5
## Icons the reels cycle through while spinning.
const FILLER_COUNT: int = 16
## Gold of the throwaway hero this screen makes when run on its own.
const TESTER_GOLD: int = 20000
const NO_PACKS: String = "No packs"
const GUARANTEE_TEXT: String = "GUARANTEED %s!"
const EMPTY_GEM: Color = Color(0.3, 0.25, 0.2, 1.0)

## One item cell, instanced for every item shown.
@export var item_cell_scene: PackedScene

var _hero: HeroData = null
var _tab: Tab = Tab.PACKS
var _packs: Array[PackData] = []
var _pack: PackData = null
var _cards: Array[PackCard] = []
var _fillers: Array[EquipmentItem] = []
## Pulling: the reels are revealing `_result`, and `_landed` of them have stopped.
var _spinning: bool = false
var _result: GachaResult = null
var _reels: Array[Reel] = []
var _landed: int = 0
var _celebration: Tween = null
## Forging: the new item is hidden from the stash until its reel has stopped.
var _forging: bool = false
var _forged: EquipmentItem = null
var _stash_cells: Array[ItemCell] = []
var _socket_cells: Array[ItemCell] = []

@onready var _back_button: Button = %BackButton
@onready var _gold_label: Label = %GoldLabel
@onready var _inventory_label: Label = %InventoryLabel
@onready var _packs_tab: Button = %PacksTab
@onready var _forge_tab: Button = %ForgeTab
@onready var _packs_view: Control = %PacksView
@onready var _forge_view: Control = %ForgeView
@onready var _shelf: VBoxContainer = %Shelf
@onready var _marquee: MarqueeFrame = %Marquee
@onready var _chest_left: TextureRect = %ChestLeft
@onready var _chest_right: TextureRect = %ChestRight
@onready var _pack_title: Label = %PackTitle
@onready var _odds_bar: OddsBar = %OddsBar
@onready var _reel_grid: GridContainer = %ReelGrid
@onready var _result_chips: HBoxContainer = %ResultChips
@onready var _guarantee_label: Label = %GuaranteeLabel
@onready var _message_label: Label = %MessageLabel
@onready var _pity_meter: PityMeter = %PityMeter
@onready var _skip_button: Button = %SkipButton
@onready var _pull_one_button: Button = %PullOneButton
@onready var _pull_ten_button: Button = %PullTenButton
@onready var _stash_grid: GridContainer = %StashGrid
@onready var _socket_row: HBoxContainer = %SocketRow
@onready var _from_gem: ColorRect = %FromGem
@onready var _to_gem: ColorRect = %ToGem
@onready var _forge_hint: Label = %ForgeHint
@onready var _forge_reel: Reel = %ForgeReel
@onready var _merge_count_label: Label = %MergeCountLabel
@onready var _merge_button: Button = %MergeButton


func _ready() -> void:
	_back_button.pressed.connect(back_requested.emit)
	_packs_tab.toggled.connect(_on_tab_toggled.bind(Tab.PACKS))
	_forge_tab.toggled.connect(_on_tab_toggled.bind(Tab.FORGE))
	_pull_one_button.pressed.connect(_on_pull_pressed.bind(1))
	_pull_ten_button.pressed.connect(_on_pull_pressed.bind(PackData.MULTI_PULL))
	_skip_button.pressed.connect(_on_skip_pressed)
	_merge_button.pressed.connect(_on_merge_pressed)
	_forge_reel.landed.connect(_on_forge_landed)
	_stash_grid.columns = STASH_COLUMNS

	if _hero == null:
		_hero = HeroData.create("Tester")
		if _hero == null:
			return
		_hero.gold = TESTER_GOLD
	_build_fillers()
	_forge_reel.fillers = _fillers
	_packs = PackData.all()
	_build_shelf()
	_build_sockets()
	_show_tab(Tab.PACKS)
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
		_build_fillers()
		_refresh_hero()


func _refresh_hero() -> void:
	_gold_label.text = str(_hero.gold)
	_inventory_label.text = "%d/%d" % [_hero.inventory.size(), _hero.inventory_capacity()]
	_inventory_label.theme_type_variation = (
		&"AccentLabel" if _hero.is_inventory_full() else &""
	)
	_refresh_pack()
	if not _forging:
		_build_stash()


func _show_tab(tab: Tab) -> void:
	_tab = tab
	_packs_view.visible = tab == Tab.PACKS
	_forge_view.visible = tab == Tab.FORGE
	_message_label.text = ""


## Random plain items whose icons the reels flick through while spinning.
func _build_fillers() -> void:
	_fillers.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var common: RarityData = RarityData.find(RarityData.COMMON)
	for _i: int in FILLER_COUNT:
		var item: EquipmentItem = ItemRoller.roll(common, rng)
		if item != null:
			_fillers.append(item)


# --- Packs ---------------------------------------------------------------


func _build_shelf() -> void:
	for child: Node in _shelf.get_children():
		_shelf.remove_child(child)
		child.queue_free()
	_cards.clear()
	var group: ButtonGroup = ButtonGroup.new()
	for pack: PackData in _packs:
		var card: PackCard = PackCard.new()
		card.pack = pack
		card.button_group = group
		card.button_pressed = pack == _packs[0]
		card.toggled.connect(_on_pack_toggled.bind(pack))
		_shelf.add_child(card)
		_cards.append(card)
	_pack = _packs[0] if not _packs.is_empty() else null
	if _pack == null:
		push_error("Gacha: there are no packs in %s." % PackData.DIRECTORY)


func _refresh_pack() -> void:
	_pity_meter.visible = _pack != null
	if _pack == null:
		_pack_title.text = NO_PACKS
		_pull_one_button.disabled = true
		_pull_ten_button.disabled = true
		_odds_bar.show_pack(null)
		return

	_pack_title.text = "%s PACK" % _pack.display_name.to_upper()
	_chest_left.texture = ChestArt.texture(_pack.color, false)
	_chest_right.texture = ChestArt.texture(_pack.color, false)
	_odds_bar.show_pack(_pack)
	_refresh_pull_button(_pull_one_button, 1)
	_refresh_pull_button(_pull_ten_button, PackData.MULTI_PULL)
	for card: PackCard in _cards:
		card.disabled = _spinning
	if not _spinning:
		_pity_meter.show_progress(_hero.pulls_since_legendary(_pack.id), _pack.pity_limit)
		if _reels.is_empty():
			_build_reels(PackData.MULTI_PULL)


func _refresh_pull_button(button: Button, count: int) -> void:
	var cost: int = _pack.cost_for(count)
	button.text = "%d PULL%s   %d" % [count, "" if count == 1 else "S", cost]
	var reason: String = "Spinning" if _spinning else GachaMachine.refusal(_hero, _pack, count)
	button.disabled = not reason.is_empty()
	if not reason.is_empty():
		button.tooltip_text = reason
	elif count > 1:
		button.tooltip_text = "Saves %d gold" % (_pack.price * count - cost)
	else:
		button.tooltip_text = ""


## Lay out `count` reels, all idle: one big reel for a single pull, or a grid
## of small ones.
func _build_reels(count: int) -> void:
	for child: Node in _reel_grid.get_children():
		_reel_grid.remove_child(child)
		child.queue_free()
	_reels.clear()
	_reel_grid.columns = 1 if count == 1 else RESULT_COLUMNS
	var side: int = SINGLE_REEL if count == 1 else MULTI_REEL
	for _i: int in count:
		var reel: Reel = Reel.new()
		reel.custom_minimum_size = Vector2.ONE * side
		reel.fillers = _fillers
		reel.landed.connect(_on_reel_landed)
		_reel_grid.add_child(reel)
		_reels.append(reel)


func _on_pack_toggled(pressed: bool, pack: PackData) -> void:
	if not pressed or _spinning:
		return
	_pack = pack
	_message_label.text = ""
	_clear_result()
	_build_reels(PackData.MULTI_PULL)
	_refresh_pack()


func _on_pull_pressed(count: int) -> void:
	if _spinning:
		return
	var result: GachaResult = GachaMachine.pull(_hero, _pack, count)
	if result == null:
		_message_label.text = GachaMachine.refusal(_hero, _pack, count)
		_refresh_hero()
		return
	_message_label.text = ""
	_clear_result()
	_result = result
	_spinning = true
	_landed = 0
	_build_reels(count)
	_marquee.set_mode(MarqueeFrame.Mode.SPINNING)
	for i: int in _reels.size():
		_reels[i].spin()
		_reels[i].land_on(result.items[i], FIRST_STOP + STOP_STAGGER * i)
	_skip_button.visible = true
	_skip_button.grab_focus()
	_refresh_hero()
	hero_changed.emit()


func _on_skip_pressed() -> void:
	if not _spinning:
		return
	for i: int in _reels.size():
		_reels[i].land_now(_result.items[i])


func _on_reel_landed() -> void:
	if not _spinning:
		return
	_landed += 1
	if _landed >= _reels.size():
		_finish_pull()


func _finish_pull() -> void:
	_spinning = false
	_skip_button.visible = false
	_show_result_chips(_result.items)
	var top: RarityData = RarityData.highest()
	if _result.guarantee_triggered and top != null:
		_guarantee_label.text = GUARANTEE_TEXT % top.display_name.to_upper()
		_guarantee_label.visible = true
	_celebrate(_best_rarity(_result.items))
	_refresh_hero()
	var focus_target: Button = _pull_one_button
	if _pull_one_button.disabled:
		focus_target = _pull_ten_button if not _pull_ten_button.disabled else _back_button
	focus_target.grab_focus()


## Blink the marquee in `rarity`'s colour for a while if it is rare enough.
func _celebrate(rarity: RarityData) -> void:
	if _celebration != null:
		_celebration.kill()
	if rarity == null or rarity.order < CELEBRATE_FROM_ORDER:
		_marquee.set_mode(MarqueeFrame.Mode.IDLE)
		return
	_marquee.set_mode(MarqueeFrame.Mode.CELEBRATING, rarity.color)
	_celebration = create_tween()
	_celebration.tween_interval(CELEBRATE_SECONDS)
	_celebration.tween_callback(_marquee.set_mode.bind(MarqueeFrame.Mode.IDLE))


func _best_rarity(items: Array[EquipmentItem]) -> RarityData:
	var best: RarityData = null
	for item: EquipmentItem in items:
		var rarity: RarityData = item.get_rarity()
		if rarity != null and (best == null or rarity.order > best.order):
			best = rarity
	return best


func _clear_result() -> void:
	_result = null
	_guarantee_label.visible = false
	for child: Node in _result_chips.get_children():
		_result_chips.remove_child(child)
		child.queue_free()
	if _celebration != null:
		_celebration.kill()
	_marquee.set_mode(MarqueeFrame.Mode.IDLE)


## A coloured gem and a count for each rarity pulled, best first.
func _show_result_chips(items: Array[EquipmentItem]) -> void:
	var rarities: Array[RarityData] = RarityData.all()
	rarities.reverse()
	for rarity: RarityData in rarities:
		var count: int = 0
		for item: EquipmentItem in items:
			if item.rarity == rarity.id:
				count += 1
		if count == 0:
			continue
		var chip: HBoxContainer = HBoxContainer.new()
		chip.add_theme_constant_override(&"separation", 3)
		var gem: ColorRect = ColorRect.new()
		gem.color = rarity.color
		gem.custom_minimum_size = Vector2(8, 8)
		gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(gem)
		var number: Label = Label.new()
		number.text = "x%d" % count
		chip.add_child(number)
		chip.tooltip_text = "%d %s" % [count, rarity.display_name]
		_result_chips.add_child(chip)


# --- Forge ---------------------------------------------------------------


func _build_sockets() -> void:
	for _i: int in ItemMerge.ITEMS_NEEDED:
		var cell: ItemCell = _new_cell(null)
		if cell == null:
			return
		cell.selectable = true
		cell.selection_toggled.connect(_on_socket_toggled)
		_socket_row.add_child(cell)
		_socket_cells.append(cell)


func _build_stash() -> void:
	for child: Node in _stash_grid.get_children():
		_stash_grid.remove_child(child)
		child.queue_free()
	_stash_cells.clear()
	for item: EquipmentItem in _hero.inventory:
		if item == _forged:
			continue
		var cell: ItemCell = _new_cell(item)
		if cell == null:
			continue
		cell.selectable = true
		cell.selection_toggled.connect(_on_stash_toggled)
		_stash_grid.add_child(cell)
		_stash_cells.append(cell)
	_refresh_forge()


func _picked_items() -> Array[EquipmentItem]:
	var picked: Array[EquipmentItem] = []
	for cell: ItemCell in _stash_cells:
		if cell.selected:
			picked.append(cell.item)
	return picked


## Keep the picks to one rarity that can be merged, and no more than one
## merge takes: the cell just ticked wins over anything that conflicts.
func _on_stash_toggled(toggled: ItemCell) -> void:
	if toggled.selected:
		if RarityData.next_above(toggled.item.rarity) == null:
			toggled.selected = false
			_refresh_forge()
			_forge_hint.text = "%s cannot be merged" % toggled.item.get_rarity().display_name
			return
		for cell: ItemCell in _stash_cells:
			if cell != toggled and cell.selected and cell.item.rarity != toggled.item.rarity:
				cell.selected = false
		if _picked_items().size() > ItemMerge.ITEMS_NEEDED:
			toggled.selected = false
	_refresh_forge()


## Clicking a socket puts its item back.
func _on_socket_toggled(socket: ItemCell) -> void:
	socket.selected = false
	for cell: ItemCell in _stash_cells:
		if cell.item == socket.item:
			cell.selected = false
	_refresh_forge()


func _refresh_forge() -> void:
	var picked: Array[EquipmentItem] = _picked_items()
	for i: int in _socket_cells.size():
		_socket_cells[i].selected = false
		_socket_cells[i].item = picked[i] if i < picked.size() else null
	_merge_count_label.text = "%d/%d" % [picked.size(), ItemMerge.ITEMS_NEEDED]
	_merge_button.disabled = _forging or not ItemMerge.refusal(_hero, picked).is_empty()
	if picked.is_empty():
		_from_gem.color = EMPTY_GEM
		_to_gem.color = EMPTY_GEM
		_forge_hint.text = "Pick %d of one rarity" % ItemMerge.ITEMS_NEEDED
		return
	var from_rarity: RarityData = picked[0].get_rarity()
	var to_rarity: RarityData = RarityData.next_above(picked[0].rarity)
	_from_gem.color = from_rarity.color
	_to_gem.color = to_rarity.color if to_rarity != null else EMPTY_GEM
	_forge_hint.text = "%s to %s" % [
		from_rarity.display_name, to_rarity.display_name if to_rarity != null else "-"
	]


func _on_merge_pressed() -> void:
	var picked: Array[EquipmentItem] = _picked_items()
	var made: EquipmentItem = ItemMerge.merge(_hero, picked)
	if made == null:
		_forge_hint.text = ItemMerge.refusal(_hero, picked)
		return
	_forging = true
	_forged = made
	_build_stash()
	_forge_reel.spin()
	_forge_reel.land_on(made, FORGE_SPIN)
	_refresh_hero()
	hero_changed.emit()


func _on_forge_landed() -> void:
	if not _forging:
		return
	_forging = false
	_forged = null
	_build_stash()
	_merge_button.grab_focus()


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


func _on_tab_toggled(pressed: bool, tab: Tab) -> void:
	if pressed:
		_show_tab(tab)
