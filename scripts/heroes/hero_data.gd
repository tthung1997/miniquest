class_name HeroData
extends Resource
## Everything that makes up one hero, and the contents of one save slot.
##
## The hero is the save (DESIGN.md section 2): runs are disposable, this is
## not. Saved and loaded by HeroSaves.

## Bumped whenever a saved field changes meaning, so a loader can migrate.
## 2: heroes carry weapons; older heroes are given the starting set by upgrade().
## 3: the Bow became the Crossbow; upgrade() renames carried bows.
const FORMAT_VERSION: int = 3
const STARTING_CLASS: StringName = &"novice"
## Every hero starts with every base weapon so they can find the one that suits
## their stats: this one held, the rest carried.
const STARTING_WEAPON: StringName = &"sword"
const STARTING_SPARE_WEAPONS: Array[StringName] = [&"crossbow", &"wand"]
## Weapon ids that were renamed, old to new, applied to saves by upgrade().
const RENAMED_WEAPONS: Dictionary[StringName, StringName] = {&"bow": &"crossbow"}
## Every stat's value at level 1 (design/classes.json, starting_stats).
const STARTING_STAT: int = 5
## The stats a weapon can scale off, named by their HeroData property.
const STATS: Array[StringName] = [&"strength", &"dexterity", &"intelligence", &"vitality"]
## Maximum health per point of vitality at a class's health_per_vitality of 1.0.
## A placeholder, like every combat number until enemies exist.
const HEALTH_PER_VITALITY_POINT: float = 10.0
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
## Growth too small to add a whole stat point yet, carried between level-ups so
## a class that grows a stat by half a point a level still adds one every
## second level.
@export var growth_remainder: Dictionary[StringName, float] = {}

@export_group("Equipment")
@export var weapon: WeaponItem
@export var armour: ArmourItem
@export var boots: BootsItem
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
	return (
		slot == EquipmentItem.Slot.WEAPON
		or slot == EquipmentItem.Slot.ARMOUR
		or slot == EquipmentItem.Slot.BOOTS
	)


static func _describe(item: EquipmentItem) -> String:
	return "an empty item" if item == null else item.get_display_name()


func class_data() -> ClassData:
	return ClassData.find(class_id)


## The value of `stat_name`, one of STATS. An unknown name is an error and
## counts as zero, so a typo in a weapon template cannot pass for a real stat.
func stat_value(stat_name: StringName) -> int:
	if not STATS.has(stat_name):
		push_error("HeroData: '%s' is not a stat." % stat_name)
		return 0
	return get(stat_name)


## Every stat's current value, keyed by its name in STATS. Only what the hero
## has earned and spent: see total_stats() for what they fight with.
func stats() -> Dictionary[StringName, int]:
	var values: Dictionary[StringName, int] = {}
	for stat_name: StringName in STATS:
		values[stat_name] = get(stat_name)
	return values


## stats() plus whatever the worn equipment adds, which is what damage and
## health are worked out from.
func total_stats() -> Dictionary[StringName, int]:
	var values: Dictionary[StringName, int] = stats()
	for item: EquipmentItem in _worn():
		var bonuses: Dictionary[StringName, int] = item.get_stat_bonuses()
		for stat_name: StringName in bonuses:
			if not values.has(stat_name):
				push_error(
					"HeroData: %s adds to '%s', which is not a stat."
					% [item.get_display_name(), stat_name]
				)
				continue
			values[stat_name] += bonuses[stat_name]
	return values


## How fast the hero moves compared with their base speed: 1.0 with nothing
## worn, 1.1 with equipment that adds 10%.
func move_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for item: EquipmentItem in _worn():
		multiplier += item.get_move_speed_bonus()
	return multiplier


## Most health the hero can have: vitality, equipment included, weighted by
## the class's durability.
func max_health() -> float:
	return max_health_with(total_stats()[&"vitality"])


## Most health the hero would have with `vitality_points` of vitality.
func max_health_with(vitality_points: int) -> float:
	var durability: float = 1.0
	var current_class: ClassData = class_data()
	if current_class != null:
		durability = current_class.health_per_vitality
	return maxf(vitality_points * durability * HEALTH_PER_VITALITY_POINT, 1.0)


## Spend free points: `allocation` maps a stat name from STATS to how many
## points go into it. Applied all together or not at all; fails with an error
## on an unknown stat, a negative amount, or more points than are unspent.
func spend_points(allocation: Dictionary[StringName, int]) -> bool:
	var total: int = 0
	for stat_name: StringName in allocation:
		if not STATS.has(stat_name):
			push_error("HeroData: '%s' is not a stat." % stat_name)
			return false
		var amount: int = allocation[stat_name]
		if amount < 0:
			push_error("HeroData: cannot spend %d points on %s." % [amount, stat_name])
			return false
		total += amount
	if total > unspent_points:
		push_error("HeroData: cannot spend %d points with %d unspent." % [total, unspent_points])
		return false
	if total == 0:
		return true

	for stat_name: StringName in allocation:
		set(stat_name, get(stat_name) + allocation[stat_name])
	unspent_points -= total
	emit_changed()
	return true


## Bring a hero saved by an older version up to FORMAT_VERSION. Returns whether
## anything changed, so the caller knows to save the upgraded hero.
func upgrade() -> bool:
	if format_version >= FORMAT_VERSION:
		return false
	if format_version < 2:
		_give_starting_weapons()
	if format_version < 3:
		_rename_weapons()
	format_version = FORMAT_VERSION
	emit_changed()
	return true


## Add what a finished run earned: experience always, and gold and items when
## the run was won. Items that no longer fit in the inventory are dropped with a
## warning (the results panel warned about them). Returns how many were dropped.
func bank_run(result: RunResult) -> int:
	gain_experience(result.experience)
	gold += result.gold
	var dropped: int = 0
	for item: EquipmentItem in result.items:
		if is_inventory_full():
			dropped += 1
			continue
		add_to_inventory(item)
	if dropped > 0:
		push_warning("HeroData: %d item(s) had no room in the inventory." % dropped)
	emit_changed()
	return dropped


func free_inventory_cells() -> int:
	return INVENTORY_SIZE - inventory.size()


## Add `amount` experience, up to the level cap, and level up as far as it
## reaches. Each level gained grows the stats by the class's growth and adds
## free points. Returns how many levels were gained.
func gain_experience(amount: int) -> int:
	if amount < 0:
		push_error("HeroData: experience gained must not be negative, got %d." % amount)
		return 0
	experience = mini(experience + amount, Levelling.max_exp())
	var gained: int = 0
	for _step: int in maxi(Levelling.level_for(experience) - level, 0):
		_level_up()
		gained += 1
	emit_changed()
	return gained


## The level this hero would be after gaining `amount` experience, changing
## nothing.
func level_after(amount: int) -> int:
	var total: int = mini(experience + maxi(amount, 0), Levelling.max_exp())
	return maxi(Levelling.level_for(total), level)


func _level_up() -> void:
	level += 1
	unspent_points += Levelling.FREE_POINTS_PER_LEVEL
	var growing_class: ClassData = class_data()
	if growing_class == null:
		return
	for stat_name: StringName in growing_class.stat_growth:
		if not STATS.has(stat_name):
			push_error("HeroData: class '%s' grows unknown stat '%s'." % [class_id, stat_name])
			continue
		var growth: float = growing_class.stat_growth[stat_name]
		var owed: float = growth_remainder.get(stat_name, 0.0) + growth
		# A hair of slack so 0.1 added ten times still makes a whole point.
		var whole: int = floori(owed + 0.0001)
		set(stat_name, get(stat_name) + whole)
		growth_remainder[stat_name] = maxf(owed - whole, 0.0)


## The item worn in `slot`, or null when it is empty.
func equipped(slot: EquipmentItem.Slot) -> EquipmentItem:
	match slot:
		EquipmentItem.Slot.WEAPON:
			return weapon
		EquipmentItem.Slot.ARMOUR:
			return armour
		EquipmentItem.Slot.BOOTS:
			return boots
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
		EquipmentItem.Slot.BOOTS:
			if item != null and item is not BootsItem:
				push_error("HeroData: %s does not fit the Boots slot." % _describe(item))
				return false
			boots = item
			return true
	push_error("HeroData: the %s slot is not supported yet." % EquipmentItem.slot_name(slot))
	return false


## Every item currently worn.
func _worn() -> Array[EquipmentItem]:
	var items: Array[EquipmentItem] = []
	for item: EquipmentItem in [weapon, armour, boots]:
		if item != null:
			items.append(item)
	return items


## Point every held or carried weapon with a renamed id at its new id.
func _rename_weapons() -> void:
	var items: Array[EquipmentItem] = inventory.duplicate()
	items.append(weapon)
	for item: EquipmentItem in items:
		if item is not WeaponItem:
			continue
		var held: WeaponItem = item
		if RENAMED_WEAPONS.has(held.weapon_id):
			held.weapon_id = RENAMED_WEAPONS[held.weapon_id]


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
