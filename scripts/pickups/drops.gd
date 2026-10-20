class_name Drops
extends RefCounted
## Rolls what an enemy leaves behind and what a win bonus adds.
##
## Only rolls: nothing here touches the world. The caller supplies the random
## number generator, so a test can seed it.

## Share of rolled items that are boots rather than armour. A placeholder.
const BOOTS_SHARE: float = 0.3

## Test overrides, honoured in debug builds only. Pass them after `--` on the
## command line, as in `godot --path . -- --rarity=epic --item-chance=1`, or
## set them from a preview scene. `forced_rarity` makes every roll that
## rarity; `item_chance_override` replaces each enemy's chance of leaving an
## item, though the quest's cap on items per run still applies. The command line
## is read on the first roll.
static var forced_rarity: StringName = &""
static var item_chance_override: float = -1.0
static var _args_read: bool = false


## Gold left by a kill of `data`, or zero when this one drops none.
static func gold_for(data: EnemyData, rng: RandomNumberGenerator) -> int:
	if rng.randf() >= data.gold_chance:
		return 0
	return rng.randi_range(mini(data.gold_min, data.gold_max), maxi(data.gold_min, data.gold_max))


## Whether a kill of `data` leaves an item.
static func item_dropped(data: EnemyData, rng: RandomNumberGenerator) -> bool:
	_read_args()
	var chance: float = data.item_chance
	if OS.is_debug_build() and item_chance_override >= 0.0:
		chance = item_chance_override
	return rng.randf() < chance


## A new item: boots BOOTS_SHARE of the time, otherwise armour rolled from the
## art of a random class (see ItemRoller.roll_armour), at a rarity weighted by
## each rarity's drop weight at `difficulty` (see QuestData.start_difficulty).
## Null, with an error, when nothing could be rolled.
static func roll_item(rng: RandomNumberGenerator, difficulty: float = 0.0) -> EquipmentItem:
	var item: EquipmentItem = null
	if rng.randf() < BOOTS_SHARE:
		item = BootsItem.roll(rng)
	if item == null:
		item = ItemRoller.roll_armour(rng)
	if item == null:
		return null
	var rarity: RarityData = _roll_rarity(rng, difficulty)
	if rarity != null:
		item.rarity = rarity.id
	return item


## The items a win adds: the quest's fixed count, the same for every hero.
## `ramp_start` is where the run began, which sets how good they are.
static func win_bonus_items(
	quest: QuestData, ramp_start: float, rng: RandomNumberGenerator
) -> Array[EquipmentItem]:
	var items: Array[EquipmentItem] = []
	var difficulty: float = quest.start_difficulty(ramp_start)
	for i: int in quest.win_bonus_item_count:
		var item: EquipmentItem = roll_item(rng, difficulty)
		if item != null:
			items.append(item)
	return items


## The rarity of a new item: the forced one when a debug build has it set,
## otherwise a weighted roll.
static func _roll_rarity(rng: RandomNumberGenerator, difficulty: float) -> RarityData:
	_read_args()
	if OS.is_debug_build() and forced_rarity != &"":
		var forced: RarityData = RarityData.find(forced_rarity)
		if forced != null:
			return forced
	return RarityData.roll(rng, difficulty)


static func _read_args() -> void:
	if _args_read:
		return
	_args_read = true
	if not OS.is_debug_build():
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rarity="):
			forced_rarity = StringName(arg.trim_prefix("--rarity="))
		elif arg.begins_with("--item-chance="):
			item_chance_override = clampf(arg.trim_prefix("--item-chance=").to_float(), 0.0, 1.0)
