class_name ItemMerge
extends RefCounted
## Turns a handful of carried items of one rarity into one random item a rarity
## higher, for gear the hero has no use for.
##
## The items can be of any kind, and so can the result: it is rolled like a
## gacha pull, at the next rarity up. Costs no gold. Legendary, the top
## rarity, cannot be merged. The caller supplies the random number generator,
## so a test can seed it.

## How many items one merge takes. A placeholder.
const ITEMS_NEEDED: int = 5


## Why `items` cannot be merged by `hero`, in words for the player, or an empty
## string when they can. Worn items cannot be merged: only carried ones.
static func refusal(hero: HeroData, items: Array[EquipmentItem]) -> String:
	if hero == null or items.is_empty():
		return "Pick %d items of one rarity" % ITEMS_NEEDED
	var first: EquipmentItem = items[0]
	if RarityData.next_above(first.rarity) == null:
		return "%s is the highest rarity" % first.get_rarity().display_name
	for item: EquipmentItem in items:
		if not hero.inventory.has(item):
			return "Only carried items can be merged"
		if item.rarity != first.rarity:
			return "All items must be the same rarity"
	if items.size() != ITEMS_NEEDED:
		return "Pick %d items of one rarity" % ITEMS_NEEDED
	for i: int in items.size():
		if items.find(items[i]) != i:
			return "Each item can only be picked once"
	return ""


## Consume `items` and carry one new item a rarity above them. Returns it, or
## null with an error, having changed nothing, when `refusal()` says no or
## nothing could be rolled.
static func merge(
	hero: HeroData, items: Array[EquipmentItem], rng: RandomNumberGenerator = null
) -> EquipmentItem:
	var reason: String = refusal(hero, items)
	if not reason.is_empty():
		push_error("ItemMerge: cannot merge: %s." % reason)
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var result: EquipmentItem = ItemRoller.roll(
		hero.armour_pool(), RarityData.next_above(items[0].rarity), rng
	)
	if result == null:
		return null
	for item: EquipmentItem in items:
		hero.remove_from_inventory(item)
	hero.add_to_inventory(result)
	return result
