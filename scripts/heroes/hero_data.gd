class_name HeroData
extends Resource
## Everything that makes up one hero, and the contents of one save slot.
##
## The hero is the save (DESIGN.md section 2): runs are disposable, this is
## not. Saved and loaded by HeroSaves.

## Bumped whenever a saved field changes meaning, so a loader can migrate.
## 2: heroes carry weapons; older heroes are given the starting set by upgrade().
const FORMAT_VERSION: int = 2
const STARTING_CLASS: StringName = &"novice"
## Every hero starts with every base weapon so they can find the one that suits
## their stats: this one held, the rest carried.
const STARTING_WEAPON: StringName = &"sword"
const STARTING_SPARE_WEAPONS: Array[StringName] = [&"bow", &"wand"]
## Every stat's value at level 1 (design/classes.json, starting_stats).
const STARTING_STAT: int = 5
const NAME_MAX_LENGTH: int = 12
## Inventory cells per hero, shown all at once in the hub.
const INVENTORY_SIZE: int = 25

## Zero (the default) means the file predates versioning. Left at a non-default
## on purpose: Godot omits default-valued fields when saving, which would drop
## the version line from every file.
@export var format_version: int = 0
@export var hero_name: String = ""
@export_range(1, 999) var level: int = 1
@export var experience: int = 0
@export var gold: int = 0
@export var class_id: StringName = STARTING_CLASS

@export_group("Stats")
@export var strength: int = STARTING_STAT
@export var dexterity: int = STARTING_STAT
@export var intelligence: int = STARTING_STAT
@export var vitality: int = STARTING_STAT
@export var unspent_points: int = 0

@export_group("Equipment")
@export var weapon: WeaponItem
@export var armour: ArmourItem
## Items carried but not worn, at most INVENTORY_SIZE. Kept packed: an item
## leaving the inventory closes its gap, and a new one goes on the end.
@export var inventory: Array[EquipmentItem] = []


## A new level 1 Novice called `raw_name`, wearing freshly rolled Novice
## armour and holding the starting weapon, with the spare weapons carried.
## Returns null with an error if the name is empty once cleaned.
static func create(raw_name: String) -> HeroData:
	var cleaned: String = clean_name(raw_name)
	if cleaned.is_empty():
		push_error("HeroData: a hero needs a name.")
		return null

	var starting_class: ClassData = ClassData.find(STARTING_CLASS)
	if starting_class == null:
		return null

	var hero: HeroData = HeroData.new()
	hero.format_version = FORMAT_VERSION
	hero.hero_name = cleaned
	hero.class_id = STARTING_CLASS
	hero.armour = ArmourItem.roll(starting_class.armour_pool)
	if hero.armour == null:
		return null
	if not hero._give_starting_weapons():
		return null
	return hero


## Trim surrounding whitespace, collapse inner runs of it, and cap the length.
static func clean_name(raw_name: String) -> String:
	var words: PackedStringArray = raw_name.strip_edges().split(" ", false)
	return " ".join(words).left(NAME_MAX_LENGTH).strip_edges()


## Whether a hero can wear anything in `slot` yet. The other slots open as
## their items are designed.
static func supports_slot(slot: EquipmentItem.Slot) -> bool:
	return slot == EquipmentItem.Slot.WEAPON or slot == EquipmentItem.Slot.ARMOUR


static func _describe(item: EquipmentItem) -> String:
	return "an empty item" if item == null else item.get_display_name()


func class_data() -> ClassData:
	return ClassData.find(class_id)


## Bring a hero saved by an older version up to FORMAT_VERSION. Returns whether
## anything changed, so the caller knows to save the upgraded hero.
func upgrade() -> bool:
	if format_version >= FORMAT_VERSION:
		return false
	if format_version < 2:
		_give_starting_weapons()
	format_version = FORMAT_VERSION
	emit_changed()
	return true


## The item worn in `slot`, or null when it is empty.
func equipped(slot: EquipmentItem.Slot) -> EquipmentItem:
	match slot:
		EquipmentItem.Slot.WEAPON:
			return weapon
		EquipmentItem.Slot.ARMOUR:
			return armour
	return null


func is_inventory_full() -> bool:
	return inventory.size() >= INVENTORY_SIZE


## Put `item` on the end of the inventory. Fails with an error when the
## inventory is full or already holds it.
func add_to_inventory(item: EquipmentItem) -> bool:
	if item == null:
		push_error("HeroData: cannot carry an empty item.")
		return false
	if inventory.has(item):
		push_error("HeroData: %s is already carried." % item.get_display_name())
		return false
	if is_inventory_full():
		push_error("HeroData: no room to carry %s." % item.get_display_name())
		return false
	inventory.append(item)
	emit_changed()
	return true


func can_equip(item: EquipmentItem) -> bool:
	return item != null and inventory.has(item) and supports_slot(item.get_slot())


## Wear `item` from the inventory. Whatever was in its slot takes the item's
## place in the inventory, so a swap never needs a free cell.
func equip(item: EquipmentItem) -> bool:
	if not can_equip(item):
		push_error("HeroData: cannot equip %s." % _describe(item))
		return false
	var index: int = inventory.find(item)
	var previous: EquipmentItem = equipped(item.get_slot())
	if not _set_equipped(item.get_slot(), item):
		return false
	if previous == null:
		inventory.remove_at(index)
	else:
		inventory[index] = previous
	emit_changed()
	return true


## Unequipping needs a free inventory cell; nothing is ever dropped.
func can_unequip(slot: EquipmentItem.Slot) -> bool:
	return equipped(slot) != null and not is_inventory_full()


func unequip(slot: EquipmentItem.Slot) -> bool:
	if not can_unequip(slot):
		push_error("HeroData: cannot unequip the %s slot." % EquipmentItem.slot_name(slot))
		return false
	var item: EquipmentItem = equipped(slot)
	if not _set_equipped(slot, null):
		return false
	inventory.append(item)
	emit_changed()
	return true


func _set_equipped(slot: EquipmentItem.Slot, item: EquipmentItem) -> bool:
	match slot:
		EquipmentItem.Slot.WEAPON:
			if item != null and item is not WeaponItem:
				push_error("HeroData: %s does not fit the Weapon slot." % _describe(item))
				return false
			weapon = item
			return true
		EquipmentItem.Slot.ARMOUR:
			if item != null and item is not ArmourItem:
				push_error("HeroData: %s does not fit the Armour slot." % _describe(item))
				return false
			armour = item
			return true
	push_error("HeroData: the %s slot is not supported yet." % EquipmentItem.slot_name(slot))
	return false


## Hold the starting weapon if the hand is empty, and carry each spare weapon
## the hero does not already have. A spare with no room is skipped with a
## warning rather than lost silently. Fails if a weapon template is missing.
func _give_starting_weapons() -> bool:
	var owned: Array[StringName] = []
	if weapon != null:
		owned.append(weapon.weapon_id)
	for item: EquipmentItem in inventory:
		if item is WeaponItem:
			var carried: WeaponItem = item
			owned.append(carried.weapon_id)

	if weapon == null and not owned.has(STARTING_WEAPON):
		weapon = WeaponItem.create(STARTING_WEAPON)
		if weapon == null:
			return false
		owned.append(STARTING_WEAPON)

	for weapon_id: StringName in STARTING_SPARE_WEAPONS:
		if owned.has(weapon_id):
			continue
		if is_inventory_full():
			push_warning("HeroData: no room to carry a starting %s." % weapon_id)
			continue
		var spare: WeaponItem = WeaponItem.create(weapon_id)
		if spare == null:
			return false
		inventory.append(spare)
		owned.append(weapon_id)
	return true
