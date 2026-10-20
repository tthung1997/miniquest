class_name ItemRoller
extends RefCounted
## Rolls a new piece of equipment at a chosen rarity, for gacha pulls and merges.
##
## Only rolls: nothing here touches a hero. The caller supplies the random
## number generator, so a test can seed it.

## Relative chance that a rolled item is a weapon, armour or boots. A placeholder.
const SLOT_WEIGHTS: Dictionary[EquipmentItem.Slot, float] = {
	EquipmentItem.Slot.WEAPON: 1.0,
	EquipmentItem.Slot.ARMOUR: 1.0,
	EquipmentItem.Slot.BOOTS: 1.0,
}
## The art pools rolled armour comes from, each equally likely. Any hero can
## wear any of it (a class never restricts anything); its stats lean towards
## its own class, so armour for another class is worth selling or forging.
## Novice is left out: its plain clothes are the starting set and the store's.
const ARMOUR_POOLS: Array[StringName] = [&"mage", &"ranger", &"warrior"]


## A new item of `rarity`: a random weapon, random armour (see roll_armour) or a
## random pair of boots. Null, with an error, when nothing could be rolled.
static func roll(rarity: RarityData, rng: RandomNumberGenerator) -> EquipmentItem:
	if rarity == null:
		push_error("ItemRoller: cannot roll an item without a rarity.")
		return null
	var item: EquipmentItem = null
	match _roll_slot(rng):
		EquipmentItem.Slot.WEAPON:
			item = _roll_weapon(rng)
		EquipmentItem.Slot.ARMOUR:
			item = roll_armour(rng)
		EquipmentItem.Slot.BOOTS:
			item = BootsItem.roll(rng)
	if item != null:
		item.rarity = rarity.id
	return item


## New Common armour from a random pool in ARMOUR_POOLS.
static func roll_armour(rng: RandomNumberGenerator) -> ArmourItem:
	return ArmourItem.roll(ARMOUR_POOLS[rng.randi_range(0, ARMOUR_POOLS.size() - 1)], rng)


static func _roll_slot(rng: RandomNumberGenerator) -> EquipmentItem.Slot:
	var total: float = 0.0
	for weight: float in SLOT_WEIGHTS.values():
		total += weight
	var pick: float = rng.randf() * total
	var last: EquipmentItem.Slot = EquipmentItem.Slot.WEAPON
	for slot: EquipmentItem.Slot in SLOT_WEIGHTS:
		last = slot
		pick -= SLOT_WEIGHTS[slot]
		if pick < 0.0:
			return slot
	return last


static func _roll_weapon(rng: RandomNumberGenerator) -> WeaponItem:
	var ids: Array[StringName] = WeaponData.all_ids()
	if ids.is_empty():
		push_error("ItemRoller: there are no weapons to roll from.")
		return null
	return WeaponItem.create(ids[rng.randi_range(0, ids.size() - 1)])
