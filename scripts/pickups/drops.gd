class_name Drops
extends RefCounted
## Rolls what an enemy leaves behind and what a win bonus adds.
##
## Only rolls: nothing here touches the world. The caller supplies the random
## number generator, so a test can seed it.

## Share of rolled items that are boots rather than armour. A placeholder.
const BOOTS_SHARE: float = 0.3


## Gold left by a kill of `data`, or zero when this one drops none.
static func gold_for(data: EnemyData, rng: RandomNumberGenerator) -> int:
	if rng.randf() >= data.gold_chance:
		return 0
	return rng.randi_range(mini(data.gold_min, data.gold_max), maxi(data.gold_min, data.gold_max))


## Whether a kill of `data` leaves an item.
static func item_dropped(data: EnemyData, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < data.item_chance


## A new item: boots BOOTS_SHARE of the time, otherwise armour rolled from the
## art of `pool`. Null, with an error, when nothing could be rolled.
static func roll_item(pool: StringName, rng: RandomNumberGenerator) -> EquipmentItem:
	if rng.randf() < BOOTS_SHARE:
		var boots: BootsItem = BootsItem.roll(rng)
		if boots != null:
			return boots
	return ArmourItem.roll(pool, rng)


## The items a win adds: the first roll always lands, each later one with the
## quest's chance. `ramp_start` is where the run began, which sets how many
## rolls there are.
static func win_bonus_items(
	quest: QuestData, ramp_start: float, pool: StringName, rng: RandomNumberGenerator
) -> Array[EquipmentItem]:
	var items: Array[EquipmentItem] = []
	for roll: int in quest.win_bonus_rolls(ramp_start):
		if roll > 0 and rng.randf() >= quest.win_bonus_drop_chance:
			continue
		var item: EquipmentItem = roll_item(pool, rng)
		if item != null:
			items.append(item)
	return items
