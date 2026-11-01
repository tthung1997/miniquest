class_name AccessoryData
extends Resource
## One accessory. Instances live in resources/accessories/, one file per
## accessory, named after its id.
##
## An accessory gives one of cooldown reduction, critical hit chance or pickup
## radius as its main effect, plus a few stat points, so they differ by more
## than looks (DESIGN.md section 5.6). It is shown by its icon only and is not
## drawn on the hero. The numbers are placeholders until the arena is tuned.

const DIRECTORY: String = "res://resources/accessories"
const FILE_SUFFIX: String = ".tres"

@export var id: StringName = &""
@export var display_name: String = ""
## 16x16 inventory icon.
@export var icon: Texture2D

@export_group("Store")
## Gold the store asks for it. A placeholder until the economy is tuned.
@export_range(0, 100000, 10, "suffix:gold") var price: int = 0

@export_group("Effects")
## Fraction taken off every skill's cooldown: 0.1 is 10% shorter.
@export_range(0.0, 0.5, 0.01) var cooldown_reduction: float = 0.0
## Chance a hit is critical: 0.1 is one in ten.
@export_range(0.0, 0.5, 0.01) var crit_chance: float = 0.0
## Pixels added to how close a drop must be to be collected.
@export_range(0.0, 100.0, 1.0, "suffix:px") var pickup_radius: float = 0.0
## Points added to each stat, keyed by HeroData stat property name, such as
## &"intelligence".
@export var stat_bonuses: Dictionary[StringName, int] = {}


## The accessory with `accessory_id`, or null with an error if there is none.
static func find(accessory_id: StringName) -> AccessoryData:
	var path: String = DIRECTORY.path_join("%s%s" % [accessory_id, FILE_SUFFIX])
	if not ResourceLoader.exists(path):
		push_error("AccessoryData: no accessory '%s' at %s." % [accessory_id, path])
		return null
	var data: AccessoryData = load(path) as AccessoryData
	if data == null:
		push_error("AccessoryData: %s is not an AccessoryData." % path)
	return data


## Every accessory's id, in alphabetical order.
static func all_ids() -> Array[StringName]:
	# Sorted as Strings: StringName comparison is not alphabetical.
	var names: PackedStringArray = []
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.ends_with(FILE_SUFFIX):
			names.append(file.trim_suffix(FILE_SUFFIX))
	names.sort()
	var ids: Array[StringName] = []
	for accessory_name: String in names:
		ids.append(StringName(accessory_name))
	return ids
