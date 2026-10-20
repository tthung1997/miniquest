class_name PackData
extends Resource
## One gacha pack: what it costs, how likely each rarity is, and how long a
## hero can go without a Legendary. Instances live in resources/packs/, one
## file per pack, named after its id.
##
## Every pack can give every rarity; packs differ in the odds and in the
## guarantee. Every number is a placeholder until the economy is tuned.

const DIRECTORY: String = "res://resources/packs"
const FILE_SUFFIX: String = ".tres"
## How many pulls the multi-pull makes at once.
const MULTI_PULL: int = 10

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Lowest first. Sorts packs from the cheapest.
@export_range(0, 9) var order: int = 0
## The pack's colour: its chest, its glow and its card are tinted with it.
@export var color: Color = Color.WHITE
@export_range(1, 100000, 1, "suffix:gold") var price: int = 100
## Fraction taken off when pulling MULTI_PULL at once: 0.1 makes ten pulls cost
## nine pulls' worth.
@export_range(0.0, 0.5, 0.01) var multi_discount: float = 0.1
## The pull on which a Legendary is guaranteed if none has come since the last:
## 100 means a hero never goes more than 100 pulls without one. Zero turns the
## guarantee off.
@export_range(0, 1000) var pity_limit: int = 100
## Each rarity's share of this pack's pulls, keyed by rarity id. Only the ratio
## between them counts; a rarity left out is never rolled.
@export var rarity_weights: Dictionary[StringName, float] = {}


## Every pack, cheapest first.
static func all() -> Array[PackData]:
	var found: Array[PackData] = []
	# ResourceLoader rather than DirAccess, so the listing still matches the
	# resources after export, where files are remapped.
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if not file.ends_with(FILE_SUFFIX):
			continue
		var pack: PackData = find(StringName(file.trim_suffix(FILE_SUFFIX)))
		if pack != null:
			found.append(pack)
	found.sort_custom(PackData._by_order)
	return found


## The pack with `pack_id`, or null with an error if there is none.
static func find(pack_id: StringName) -> PackData:
	var path: String = DIRECTORY.path_join("%s%s" % [pack_id, FILE_SUFFIX])
	if not ResourceLoader.exists(path):
		push_error("PackData: no pack '%s' at %s." % [pack_id, path])
		return null
	var data: PackData = load(path) as PackData
	if data == null:
		push_error("PackData: %s is not a PackData." % path)
	return data


## Gold for `count` pulls: the multi-pull is discounted, any other count is
## full price each.
func cost_for(count: int) -> int:
	var full: int = price * count
	if count == MULTI_PULL:
		return roundi(full * (1.0 - multi_discount))
	return full


## The rarity of one pull. Null, with an error, when no rarity has any weight.
func roll_rarity(rng: RandomNumberGenerator) -> RarityData:
	var rarities: Array[RarityData] = RarityData.all()
	var total: float = 0.0
	for rarity: RarityData in rarities:
		total += weight_of(rarity)
	if total <= 0.0:
		push_error("PackData: pack '%s' has no rarity weights." % id)
		return null

	var pick: float = rng.randf() * total
	for rarity: RarityData in rarities:
		var weight: float = weight_of(rarity)
		pick -= weight
		if pick < 0.0 and weight > 0.0:
			return rarity
	# Rounding can leave the pick just past the end; the last that can drop wins.
	for i: int in range(rarities.size() - 1, -1, -1):
		if weight_of(rarities[i]) > 0.0:
			return rarities[i]
	return null


func weight_of(rarity: RarityData) -> float:
	return maxf(rarity_weights.get(rarity.id, 0.0), 0.0)


## `rarity`'s chance on a single pull, from 0.0 to 1.0, before the guarantee.
func chance_of(rarity: RarityData) -> float:
	var total: float = 0.0
	for other: RarityData in RarityData.all():
		total += weight_of(other)
	return weight_of(rarity) / total if total > 0.0 else 0.0


static func _by_order(a: PackData, b: PackData) -> bool:
	return a.order < b.order
