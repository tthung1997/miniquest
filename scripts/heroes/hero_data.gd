class_name HeroData
extends Resource
## Everything that makes up one hero, and the contents of one save slot.
##
## The hero is the save (DESIGN.md section 2): runs are disposable, this is
## not. Saved and loaded by HeroSaves.

## Bumped whenever a saved field changes meaning, so a loader can migrate.
## 2: heroes carry weapons; older heroes are given the starting set by upgrade().
## 3: the Bow became the Crossbow; upgrade() renames carried bows.
## 4: heroes earn skill points; upgrade() gives older heroes the ones their levels earned.
## 5: armour rolls stat points; upgrade() rolls them for armour that has none.
const FORMAT_VERSION: int = 5
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
## Gold charged for each skill point taken back by a skill reset. A placeholder
## until the economy is tuned: a run is worth roughly 50 to 100 gold.
const SKILL_RESET_COST_PER_POINT: int = 5
## Inventory cells every hero starts with. The store sells more (BagUpgrades);
## see inventory_capacity().
const BASE_INVENTORY_SIZE: int = 25

## Zero (the default) means the file predates versioning. Left at a non-default
## on purpose: Godot omits default-valued fields when saving, which would drop
## the version line from every file.
@export var format_version: int = 0
@export var hero_name: String = ""
@export_range(1, 999) var level: int = 1
@export var experience: int = 0
@export var gold: int = 0
@export var class_id: StringName = STARTING_CLASS
## Every class the hero was before `class_id`, oldest first. Empty for a hero
## still in their starting class, so older saves need no upgrade.
@export var past_classes: Array[StringName] = []

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

@export_group("Skills")
## Points earned by levelling and not yet put into a skill.
@export var unspent_skill_points: int = 0
## Points put into each skill, keyed by skill id. A skill a class grants starts
## at level 1, so its level is 1 plus what is here.
@export var skill_points_spent: Dictionary[StringName, int] = {}
## The skill a run begins with. Empty, or one the hero has not unlocked, means
## the first skill they have.
@export var starting_skill: StringName = &""

@export_group("Equipment")
@export var weapon: WeaponItem
@export var armour: ArmourItem
@export var boots: BootsItem
## Items carried but not worn, at most inventory_capacity(). Kept packed: an item
## leaving the inventory closes its gap, and a new one goes on the end.
@export var inventory: Array[EquipmentItem] = []
## How many inventory upgrades the hero has bought from the store.
@export var bag_upgrades: int = 0

@export_group("Gacha")
## Pulls made from each pack since it last gave a Legendary, keyed by pack id.
## Drives the pack's guarantee (PackData.pity_limit).
@export var pity: Dictionary[StringName, int] = {}


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


## Every class the hero has been, oldest first, ending with the current one.
func lineage() -> Array[StringName]:
	var path: Array[StringName] = past_classes.duplicate()
	path.append(class_id)
	return path


## The armour art pool the hero's gear and drops come from: the most recent
## class in the lineage that sets one.
func armour_pool() -> StringName:
	var path: Array[StringName] = lineage()
	for i: int in range(path.size() - 1, -1, -1):
		var step: ClassData = ClassData.find(path[i])
		if step != null and step.armour_pool != &"":
			return step.armour_pool
	return STARTING_CLASS


## Every class the hero could advance into from the one they are now, whether
## or not they meet its requirements yet.
func advancement_options() -> Array[ClassData]:
	return ClassData.advancements_from(class_id)


## What the hero still lacks to advance into `target`, as short readable
## phrases such as "Lv 15" or "STR 45 (have 37)". Empty when they can.
func unmet_requirements(target: ClassData) -> PackedStringArray:
	var missing: PackedStringArray = []
	if target == null or not target.prerequisites.has(class_id):
		missing.append("Not reachable from here")
		return missing
	if level < target.required_level:
		missing.append("Lv %d" % target.required_level)
	var earned: Dictionary[StringName, int] = stats()
	for stat_name: StringName in target.stat_requirements:
		if not STATS.has(stat_name):
			push_error("HeroData: class '%s' needs unknown stat '%s'." % [target.id, stat_name])
			missing.append("%s ?" % stat_name)
			continue
		var needed: int = target.stat_requirements[stat_name]
		if earned[stat_name] < needed:
			var label: String = String(stat_name).left(3).to_upper()
			missing.append("%s %d (have %d)" % [label, needed, earned[stat_name]])
	return missing


func can_advance_to(target: ClassData) -> bool:
	return unmet_requirements(target).is_empty()


## Become `class_id`, keeping everything the hero has. From now on each level
## grows their stats by this class's growth as well as every earlier one's.
## Permanent: there is no going back. Fails with an error unless the hero meets
## the class's requirements.
func advance_to(target_id: StringName) -> bool:
	var target: ClassData = ClassData.find(target_id)
	if target == null:
		return false
	var missing: PackedStringArray = unmet_requirements(target)
	if not missing.is_empty():
		push_error(
			"HeroData: %s cannot become %s yet: %s."
			% [hero_name, target.display_name, ", ".join(missing)]
		)
		return false
	past_classes.append(class_id)
	class_id = target_id
	emit_changed()
	return true


## Every skill the hero has learned: those granted by a class in their lineage,
## oldest class first, once the class's skill points requirement is met. A class
## whose requirement is not met yet has its skills in lineage_skills() but not
## here, so they cannot be trained, started with or offered in a run.
func unlocked_skills() -> Array[SkillData]:
	var open: Array[StringName] = []
	for granting_id: StringName in lineage():
		if skills_open(granting_id):
			open.append(granting_id)
	return SkillData.granted_by(open)


## Every skill granted by a class in the hero's lineage, learned or not.
func lineage_skills() -> Array[SkillData]:
	return SkillData.granted_by(lineage())


## Skill points the hero has spent on the skills of class `granting_id`.
func skill_points_in(granting_id: StringName) -> int:
	var total: int = 0
	for skill: SkillData in SkillData.granted_by([granting_id]):
		total += skill_points_spent.get(skill.id, 0)
	return total


## The class the hero advanced from to reach `granting_id`, or empty for the
## first class in their lineage.
func class_before(granting_id: StringName) -> StringName:
	var path: Array[StringName] = lineage()
	var index: int = path.find(granting_id)
	return path[index - 1] if index > 0 else &""


## Skill points spent on the previous class's skills, and how many the class
## needs: x is what the hero has, y what is required.
func skill_gate(granting_id: StringName) -> Vector2i:
	var granting: ClassData = ClassData.find(granting_id)
	var before: StringName = class_before(granting_id)
	if granting == null or before == &"":
		return Vector2i.ZERO
	return Vector2i(skill_points_in(before), granting.skill_points_required)


## Whether the skills of class `granting_id` are open to the hero.
func skills_open(granting_id: StringName) -> bool:
	var gate: Vector2i = skill_gate(granting_id)
	return gate.x >= gate.y


## The skill's level as the hero has trained it: 1 for one just unlocked, up to
## its maximum.
func skill_level(skill: SkillData) -> int:
	return mini(1 + skill_points_spent.get(skill.id, 0), skill.max_level)


## The trained levels of every unlocked skill, keyed by id.
func skill_levels() -> Dictionary[StringName, int]:
	var levels: Dictionary[StringName, int] = {}
	for skill: SkillData in unlocked_skills():
		levels[skill.id] = skill_level(skill)
	return levels


func can_raise_skill(skill: SkillData) -> bool:
	return (
		unspent_skill_points > 0
		and skill_level(skill) < skill.max_level
		and unlocked_skills().has(skill)
	)


## Spend a skill point to raise `skill` one level for good.
func raise_skill(skill: SkillData) -> bool:
	if not can_raise_skill(skill):
		push_error("HeroData: %s cannot raise %s." % [hero_name, skill.display_name])
		return false
	skill_points_spent[skill.id] = skill_points_spent.get(skill.id, 0) + 1
	unspent_skill_points -= 1
	emit_changed()
	return true


## Take back every skill point spent, to be spent again, for a price in gold
## (skill_reset_cost()). Skills return to level 1, and any class whose skills
## needed points in the one before closes again until they are re-spent. Fails
## with an error when the hero cannot pay or has nothing to take back.
func reset_skill_points() -> bool:
	if not can_reset_skills():
		push_error("HeroData: %s cannot reset skill points." % hero_name)
		return false
	gold -= skill_reset_cost()
	for spent: int in skill_points_spent.values():
		unspent_skill_points += spent
	skill_points_spent.clear()
	emit_changed()
	return true


## Skill points spent on skills in total.
func skill_points_total_spent() -> int:
	var total: int = 0
	for spent: int in skill_points_spent.values():
		total += spent
	return total


## Gold a reset costs: a fixed price for each point spent, so a hero who has
## invested more pays more to change their mind.
func skill_reset_cost() -> int:
	return skill_points_total_spent() * SKILL_RESET_COST_PER_POINT


func can_reset_skills() -> bool:
	return skill_points_total_spent() > 0 and gold >= skill_reset_cost()


## The skill a run begins with: the chosen one if the hero still has it, else
## their first attack. Null only for a hero with no skills at all.
func start_skill() -> SkillData:
	var skills: Array[SkillData] = unlocked_skills()
	for skill: SkillData in skills:
		if skill.id == starting_skill:
			return skill
	return SkillData.default_start(skills)


func set_start_skill(skill: SkillData) -> bool:
	if not unlocked_skills().has(skill):
		push_error("HeroData: %s has not unlocked %s." % [hero_name, skill.display_name])
		return false
	starting_skill = skill.id
	emit_changed()
	return true


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


## Most health the hero would have with `vitality_points` of vitality. The
## durability multiplier comes from the most recent class in the lineage that
## sets one.
func max_health_with(vitality_points: int) -> float:
	var durability: float = 1.0
	var path: Array[StringName] = lineage()
	for i: int in range(path.size() - 1, -1, -1):
		var step: ClassData = ClassData.find(path[i])
		if step != null and step.health_per_vitality > 0.0:
			durability = step.health_per_vitality
			break
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
	if format_version < 4:
		unspent_skill_points += (level - 1) * Levelling.SKILL_POINTS_PER_LEVEL
	if format_version < 5:
		_roll_armour_stats()
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
	return inventory_capacity() - inventory.size()


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
	unspent_skill_points += Levelling.SKILL_POINTS_PER_LEVEL
	var growth: Dictionary[StringName, float] = {}
	for step_id: StringName in lineage():
		var step: ClassData = ClassData.find(step_id)
		if step == null:
			continue
		for stat_name: StringName in step.stat_growth:
			if not STATS.has(stat_name):
				push_error("HeroData: class '%s' grows unknown stat '%s'." % [step_id, stat_name])
				continue
			growth[stat_name] = growth.get(stat_name, 0.0) + step.stat_growth[stat_name]
	for stat_name: StringName in growth:
		var owed: float = growth_remainder.get(stat_name, 0.0) + growth[stat_name]
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


## How many items the hero can carry: the starting cells plus those bought.
func inventory_capacity() -> int:
	var upgrades: BagUpgrades = BagUpgrades.load_default()
	return BASE_INVENTORY_SIZE + (upgrades.slots_for(bag_upgrades) if upgrades != null else 0)


func is_inventory_full() -> bool:
	return inventory.size() >= inventory_capacity()


## Gold for the hero's next inventory upgrade, or -1 when they have every one.
func next_bag_upgrade_price() -> int:
	var upgrades: BagUpgrades = BagUpgrades.load_default()
	return upgrades.price_after(bag_upgrades) if upgrades != null else -1


## Slots the next inventory upgrade adds, or zero when there is none.
func next_bag_upgrade_slots() -> int:
	var upgrades: BagUpgrades = BagUpgrades.load_default()
	if upgrades == null or next_bag_upgrade_price() < 0:
		return 0
	return upgrades.slots_per_upgrade


func can_upgrade_bag() -> bool:
	var price: int = next_bag_upgrade_price()
	return price >= 0 and gold >= price


## Pay for the next inventory upgrade, which adds cells. Fails with an error,
## changing nothing, when there is none left or the hero cannot pay.
func upgrade_bag() -> bool:
	if not can_upgrade_bag():
		push_error("HeroData: %s cannot upgrade their inventory." % hero_name)
		return false
	gold -= next_bag_upgrade_price()
	bag_upgrades += 1
	emit_changed()
	return true


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


## Take `item` out of the inventory, closing its gap. Fails with an error when
## it is not carried; a worn item has to be unequipped first.
func remove_from_inventory(item: EquipmentItem) -> bool:
	var index: int = inventory.find(item)
	if index < 0:
		push_error("HeroData: %s is not carried." % _describe(item))
		return false
	inventory.remove_at(index)
	emit_changed()
	return true


## Pay `amount` gold. Fails with an error, taking nothing, when the hero has less.
func spend_gold(amount: int) -> bool:
	if amount < 0 or amount > gold:
		push_error("HeroData: %s cannot pay %d gold." % [hero_name, amount])
		return false
	gold -= amount
	emit_changed()
	return true


## Whether `item` can be sold: it must be carried, not worn.
func can_sell(item: EquipmentItem) -> bool:
	return item != null and inventory.has(item)


## Sell a carried `item` to the store for gold (StoreCatalog.sell_price_of).
## Returns the gold received, or zero with an error when it cannot be sold.
func sell_item(item: EquipmentItem) -> int:
	if not can_sell(item):
		push_error("HeroData: cannot sell %s." % _describe(item))
		return 0
	var price: int = StoreCatalog.sell_price_of(item)
	inventory.erase(item)
	gold += price
	emit_changed()
	return price


## Whether the hero can pay `price` and has a cell to carry what they buy.
func can_buy(price: int) -> bool:
	return gold >= price and not is_inventory_full()


## Pay `price` gold for `item` and carry it. Fails with an error, changing
## nothing, when the hero cannot pay or has no room.
func buy_item(item: EquipmentItem, price: int) -> bool:
	if item == null or not can_buy(price):
		push_error("HeroData: %s cannot buy %s." % [hero_name, _describe(item)])
		return false
	gold -= price
	inventory.append(item)
	emit_changed()
	return true


## Pulls made from the pack `pack_id` since its last Legendary.
func pulls_since_legendary(pack_id: StringName) -> int:
	return pity.get(pack_id, 0)


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


## Roll stat points for every worn or carried armour that predates armour
## having them.
func _roll_armour_stats() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var items: Array[EquipmentItem] = inventory.duplicate()
	items.append(armour)
	for item: EquipmentItem in items:
		if item is ArmourItem and (item as ArmourItem).stat_points.is_empty():
			(item as ArmourItem).roll_stats(rng)


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
