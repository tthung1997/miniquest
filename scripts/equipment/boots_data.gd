class_name BootsData
extends Resource
## One pair of boots. Instances live in resources/boots/, one file per pair,
## named after its id.
##
## Speed is the main thing boots give, but each pair also adds a few stat
## points of its own, so they differ by more than looks (DESIGN.md section
## 5.6). The numbers are placeholders, like every number until the arena run
## can be played.

const DIRECTORY: String = "res://resources/boots"
const FILE_SUFFIX: String = ".tres"

@export var id: StringName = &""
@export var display_name: String = ""
## 16x16 inventory icon.
@export var icon: Texture2D
## The layer drawn over the hero's feet, built from the pair's sheets by
## tools/build_sprite_frames.gd.
@export var frames: SpriteFrames

@export_group("Store")
## Gold the store asks for it. A placeholder until the economy is tuned.
@export_range(0, 100000, 10, "suffix:gold") var price: int = 0

@export_group("Stats")
## Fraction of the hero's base move speed added: 0.1 is 10% faster.
@export_range(0.0, 1.0, 0.01) var move_speed: float = 0.0
## Points added to each stat, keyed by HeroData stat property name, such as
## &"dexterity".
@export var stat_bonuses: Dictionary[StringName, int] = {}


## The boots with `boots_id`, or null with an error if there are none.
static func find(boots_id: StringName) -> BootsData:
	var path: String = DIRECTORY.path_join("%s%s" % [boots_id, FILE_SUFFIX])
	if not ResourceLoader.exists(path):
		push_error("BootsData: no boots '%s' at %s." % [boots_id, path])
		return null
	var data: BootsData = load(path) as BootsData
	if data == null:
		push_error("BootsData: %s is not a BootsData." % path)
	return data


## Every pair's id, in alphabetical order.
static func all_ids() -> Array[StringName]:
	# Sorted as Strings: StringName comparison is not alphabetical.
	var names: PackedStringArray = []
	# ResourceLoader rather than DirAccess, so the listing still matches the
	# resources after export, where files are remapped.
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.ends_with(FILE_SUFFIX):
			names.append(file.trim_suffix(FILE_SUFFIX))
	names.sort()
	var ids: Array[StringName] = []
	for boots_name: String in names:
		ids.append(StringName(boots_name))
	return ids
