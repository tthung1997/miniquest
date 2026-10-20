class_name BagUpgrades
extends Resource
## How the store enlarges a hero's inventory: how many slots each upgrade adds
## and what each one costs, cheapest first. The price list's length is how
## many upgrades there are. Placeholders until the economy is tuned.

const PATH: String = "res://resources/store/bag_upgrades.tres"

@export_range(1, 25) var slots_per_upgrade: int = 5
## Gold for the first upgrade, the second, and so on.
@export var prices: PackedInt32Array = []

static var _default: BagUpgrades = null


## The shared upgrades, or null with an error if the file is missing.
static func load_default() -> BagUpgrades:
	if _default != null:
		return _default
	if not ResourceLoader.exists(PATH):
		push_error("BagUpgrades: missing %s." % PATH)
		return null
	_default = load(PATH) as BagUpgrades
	if _default == null:
		push_error("BagUpgrades: %s is not a BagUpgrades." % PATH)
	return _default


## How many upgrades can be bought in all.
func max_upgrades() -> int:
	return prices.size()


## Gold for the upgrade after `bought` of them, or -1 when there are no more.
func price_after(bought: int) -> int:
	if bought < 0 or bought >= prices.size():
		return -1
	return prices[bought]


## Slots added by `bought` upgrades.
func slots_for(bought: int) -> int:
	return clampi(bought, 0, prices.size()) * slots_per_upgrade
