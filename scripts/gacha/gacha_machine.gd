class_name GachaMachine
extends RefCounted
## Spends a hero's gold on pulls from a pack and puts what they give in the
## hero's inventory.
##
## Each pack keeps its own count of pulls since the hero's last Legendary from
## it (HeroData.pity). When that count reaches the pack's `pity_limit` the next
## pull is a Legendary whatever the dice say, and any Legendary resets it.
## The caller supplies the random number generator, so a test can seed it.

## Pulls allowed in one go: a single pull, or the pack's multi-pull.
const ALLOWED_COUNTS: Array[int] = [1, PackData.MULTI_PULL]


## Why `hero` cannot make `count` pulls from `pack`, in words for the player, or
## an empty string when they can. A pull puts every item in the inventory, so
## it needs a free cell for each.
static func refusal(hero: HeroData, pack: PackData, count: int) -> String:
	if hero == null or pack == null or not ALLOWED_COUNTS.has(count):
		return "Not available"
	if hero.gold < pack.cost_for(count):
		return "Not enough gold"
	if hero.free_inventory_cells() < count:
		return "Needs %d free inventory cells" % count
	return ""


## Pulls left before `pack`'s guarantee gives `hero` a Legendary, counting the
## one that does. Zero when the pack has no guarantee.
static func pulls_until_guarantee(hero: HeroData, pack: PackData) -> int:
	if pack.pity_limit <= 0:
		return 0
	return maxi(pack.pity_limit - hero.pulls_since_legendary(pack.id), 1)


## Pay for and make `count` pulls from `pack`. Returns what they gave, or null
## with an error, having changed nothing, when `refusal()` says no or nothing
## could be rolled.
static func pull(
	hero: HeroData, pack: PackData, count: int, rng: RandomNumberGenerator = null
) -> GachaResult:
	var reason: String = refusal(hero, pack, count)
	if not reason.is_empty():
		push_error("GachaMachine: cannot pull %d: %s." % [count, reason])
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var top: RarityData = RarityData.highest()
	if top == null:
		return null

	# Rolled first and paid for after, so a failed roll costs nothing.
	var result: GachaResult = GachaResult.new()
	var streak: int = hero.pulls_since_legendary(pack.id)
	for _pull: int in count:
		streak += 1
		var rarity: RarityData = pack.roll_rarity(rng)
		if rarity == null:
			return null
		if pack.pity_limit > 0 and streak >= pack.pity_limit and rarity != top:
			rarity = top
			result.guarantee_triggered = true
		var item: EquipmentItem = ItemRoller.roll(rarity, rng)
		if item == null:
			return null
		result.items.append(item)
		if rarity == top:
			streak = 0

	result.cost = pack.cost_for(count)
	hero.spend_gold(result.cost)
	for item: EquipmentItem in result.items:
		hero.add_to_inventory(item)
	hero.pity[pack.id] = streak
	hero.emit_changed()
	return result
